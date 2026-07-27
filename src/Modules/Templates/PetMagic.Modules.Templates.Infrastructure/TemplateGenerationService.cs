using System.Text.Json;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService(
    TemplatesDbContext dbContext,
    ITemplateGenerationBilling billing,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    TemplateWatermarkSettingsStore? watermarkSettings = null,
    IGamificationService? gamificationService = null,
    ILogger<TemplateGenerationService>? logger = null,
    ITemplateFeedRealtimeService? realtimeService = null,
    ITemplateAiProviderHealthService? aiProviderHealthService = null,
    ITemplateVisibilityPolicy? visibilityPolicy = null,
    IDataProtectionProvider? dataProtectionProvider = null,
    IAdminAuditLog? adminAuditLog = null,
    FalQueueClient? falQueueClient = null,
    IHttpContextAccessor? httpContextAccessor = null) : ITemplateGenerationService, ITemplateGenerationGamificationReconciliationService
{
    private readonly ITemplateVisibilityPolicy _visibilityPolicy =
        visibilityPolicy ?? new TemplateVisibilityPolicy();
    private readonly IDataProtector _generationShareProtector =
        (dataProtectionProvider ?? new EphemeralDataProtectionProvider())
            .CreateProtector("PetMagic.Templates.GenerationShare.v1");

    internal static readonly Guid AdminTestUserId = Guid.Empty;

    internal static Error? ValidateTemplateReadiness(TemplateItem template)
    {
        if (template.TemplateType == TemplateType.Image)
        {
            return string.IsNullOrWhiteSpace(template.ImageModel)
                ? TemplatesErrors.MissingImageModel
                : null;
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return TemplatesErrors.TypeMismatch;
        }

        if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
        {
            return TemplatesErrors.MissingReferenceMotion;
        }

        if (template.CharacterOrientation is null)
        {
            return TemplatesErrors.MissingCharacterOrientation;
        }

        if (string.IsNullOrWhiteSpace(template.PreprocessingModel))
        {
            return TemplatesErrors.InvalidPreprocessingModel;
        }

        if (string.IsNullOrWhiteSpace(template.KlingModel))
        {
            return TemplatesErrors.InvalidKlingModel;
        }

        return null;
    }

    internal static TemplateAsset? GetAsset(TemplateItem template, TemplateAssetKind kind)
    {
        return template.Assets.FirstOrDefault(x => x.AssetKind == kind);
    }

    internal static string ResolvePrompt(string? prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    internal static TemplateGenerationResponse MapResponse(
        TemplateGenerationJob job,
        int? queuePosition = null,
        int? estimatedWaitSeconds = null,
        QueueEstimate? queueEstimate = null)
    {
        queuePosition ??= queueEstimate?.QueuePosition;
        estimatedWaitSeconds ??= queueEstimate?.EstimatedWaitSeconds;
        var mediaType = queueEstimate?.MediaType ?? TemplateGenerationQueue.ResolveMediaType(job);
        var priorityClass = queueEstimate?.PriorityClass ?? TemplateGenerationQueue.NormalizeTier(job.QueueTier);
        return new TemplateGenerationResponse(
            GenerationId: job.Id,
            UserId: job.UserId,
            TemplateId: job.TemplateId,
            Status: ResolveApiStatus(job.Status),
            TokenCost: job.TokenCost,
            SourceImageAsset: MapSourceImageAsset(job),
            NormalizedImageUrl: job.NormalizedImageUrl,
            ReferenceMotionUrl: job.ReferenceMotionUrl,
            OutputUrl: ResolveDefaultOutputUrl(job),
            AttemptCount: job.AttemptCount,
            UsedPreprocessingModel: job.UsedPreprocessingModel,
            UsedKlingModel: job.UsedKlingModel,
            PreprocessingProviderRequestId: job.PreprocessingProviderRequestId,
            PreprocessingInferenceTimeSeconds: job.PreprocessingInferenceTimeSeconds,
            MotionProviderRequestId: job.MotionProviderRequestId,
            MotionInferenceTimeSeconds: job.MotionInferenceTimeSeconds,
            OutputVideoDurationSeconds: job.OutputVideoDurationSeconds,
            MotionProviderCostUsd: job.MotionProviderCostUsd,
            FailureCode: job.LastErrorCode,
            FailureMessage: ResolvePublicFailureMessage(job.LastErrorCode),
            CreatedAtUtc: job.CreatedAtUtc,
            UpdatedAtUtc: job.UpdatedAtUtc,
            StartedAtUtc: job.StartedAtUtc,
            PreprocessingCompletedAtUtc: job.PreprocessingCompletedAtUtc,
            MotionGenerationCompletedAtUtc: job.MotionGenerationCompletedAtUtc,
            MediaImportCompletedAtUtc: job.MediaImportCompletedAtUtc,
            CompletedAtUtc: job.CompletedAtUtc,
            UserMediaExpired: job.UserMediaDeletedAtUtc != null,
            TemplateTitle: job.Template?.Title,
            TemplateType: job.Template?.TemplateType.ToString(),
            Stage: ResolveStage(job),
            ProgressPercent: ResolveProgressPercent(job),
            EstimatedDurationLabel: ResolveEstimatedDurationLabel(job.Template?.TemplateType),
            ChargedAtUtc: job.ChargedAtUtc,
            RefundedAtUtc: job.RefundedAtUtc,
            IsUnread: job.Status == TemplateGenerationStatus.Completed && job.ResultViewedAtUtc == null,
            QueuePosition: queuePosition,
            EstimatedWaitSeconds: estimatedWaitSeconds,
            HasWatermark: HasWatermark(job, hasCleanAccess: false),
            CanRemoveWatermark: CanRemoveWatermark(job, hasCleanAccess: false),
            IsWatermarkRemoved: job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits: 1,
            UserPlan: "free",
            WatermarkMessage: ResolveWatermarkMessage(job, hasCleanAccess: false),
            SupportsGenerateSimilar: job.Template?.SupportsGenerateSimilar == true,
            ParentGenerationId: job.ParentGenerationId,
            ParentGenerationResultId: job.ParentGenerationResultId,
            SimilarToGenerationId: job.SimilarToGenerationId,
            GenerationMode: job.GenerationMode.ToString().ToLowerInvariant(),
            VariationStrength: job.VariationStrength,
            GenerationSeed: job.GenerationSeed,
            PromptBeforeVariation: job.PromptBeforeVariation,
            PromptAfterVariation: job.PromptAfterVariation,
            InputSourceType: string.IsNullOrWhiteSpace(job.InputSourceType) ? "user_upload" : job.InputSourceType,
            InputMediaAssetId: job.InputMediaAssetId,
            ResultMediaAssetId: job.ResultMediaAssetId,
            InputPreviewUrl: null,
            ResultPreviewUrl: null,
            CanCompareBeforeAfter: false,
            PetId: job.PetId,
            PetPhotoId: job.PetPhotoId,
            MediaType: mediaType,
            PriorityClass: priorityClass,
            EstimatedTotalSeconds: queueEstimate?.EstimatedTotalSeconds,
            EstimatedCompletionAtUtc: queueEstimate?.EstimatedCompletionAtUtc,
            QueueReason: queueEstimate?.Reason,
            RetryAfterSeconds: queueEstimate?.RetryAfterSeconds,
            CanCancel: job.Status == TemplateGenerationStatus.Queued
                || (job.Status is TemplateGenerationStatus.ProviderQueued or TemplateGenerationStatus.ProviderProcessing
                    && (!string.IsNullOrWhiteSpace(job.PreprocessingProviderCancelUrl)
                        || !string.IsNullOrWhiteSpace(job.MotionProviderCancelUrl))));
    }

    private static string? ResolvePublicFailureMessage(string? failureCode)
    {
        var code = failureCode?.Trim();
        if (string.IsNullOrEmpty(code))
        {
            return null;
        }

        if (string.Equals(code, TemplatesErrors.PetPhotoRequired.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.PetPhotoNotFound.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.SourceMediaUnavailable.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.InvalidMediaUpload.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.MediaMetadataFailed.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.SourceMediaUnavailable.Message;
        }

        if (string.Equals(code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.AiProviderTransientFailure.Message;
        }

        if (string.Equals(code, TemplatesErrors.AiProviderTimedOut.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.AiProviderTimedOut.Message;
        }

        if (string.Equals(code, TemplatesErrors.GenerationAttemptsExceeded.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.GenerationAttemptsExceeded.Message;
        }

        if (string.Equals(code, TemplatesErrors.GenerationQueueOrphaned.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.GenerationQueueOrphaned.Message;
        }

        if (string.Equals(code, TemplatesErrors.GenerationQueueOverloaded.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.GenerationWaitTooLong.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.ProviderCapacityUnavailable.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.ProviderCapacityUnavailable.Message;
        }

        if (string.Equals(code, TemplatesErrors.GeneratedMediaImportFailed.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.GeneratedMediaTooLarge.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.MediaStorageFailed.Code, StringComparison.Ordinal)
            || string.Equals(code, TemplatesErrors.WatermarkRenderFailed.Code, StringComparison.Ordinal))
        {
            return TemplatesErrors.GeneratedMediaImportFailed.Message;
        }

        return TemplatesErrors.AiProviderFailed.Message;
    }
}
