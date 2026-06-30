using System.Text.Json;

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
    ILogger<TemplateGenerationService>? logger = null) : ITemplateGenerationService
{
    internal static readonly Guid AdminTestUserId = Guid.Empty;

    internal static Error? ValidateTemplate(TemplateItem template, bool requireActiveStatus)
    {
        if (requireActiveStatus && template.Status != TemplateStatus.Active)
        {
            return TemplatesErrors.InvalidStatus;
        }

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
        int? estimatedWaitSeconds = null)
    {
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
            FailureMessage: job.LastErrorMessage,
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
            PetPhotoId: job.PetPhotoId);
    }

}
