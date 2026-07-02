using System.IO;
using System.Text.Json;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record StartTemplateGenerationCommand(
    Guid UserId,
    Guid TemplateId,
    TemplateAssetCommand SourceImageAsset,
    string? IdempotencyKey = null,
    string? RequestHash = null,
    int? ActiveGenerationLimit = null,
    TemplateAssetCommand? SourceImagePreviewAsset = null,
    string QueueTier = "free",
    long? ExpectedTemplateVersion = null,
    bool HasPremiumAccess = false)
{
    public StartTemplateGenerationCommand(
        Guid userId,
        Guid templateId,
        TemplateAssetCommand sourceImageAsset,
        string? idempotencyKey,
        string? requestHash,
        int? activeGenerationLimit)
        : this(
            userId,
            templateId,
            sourceImageAsset,
            idempotencyKey,
            requestHash,
            activeGenerationLimit,
            null,
            "free",
            null,
            false)
    {
    }

}

public sealed record StartTemplateGenerationFromResultCommand(
    Guid UserId,
    Guid ParentGenerationResultId,
    Guid TemplateId,
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null,
    string QueueTier = "free",
    long? ExpectedTemplateVersion = null,
    bool HasPremiumAccess = false);

public sealed record StartSimilarTemplateGenerationCommand(
    Guid UserId,
    Guid SourceGenerationId,
    string VariationStrength = "medium",
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null,
    string QueueTier = "free",
    bool HasPremiumAccess = false);

public sealed record StartTemplateGenerationFromPetCommand(
    Guid UserId,
    Guid PetId,
    Guid? PetPhotoId,
    Guid TemplateId,
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null,
    string QueueTier = "free",
    long? ExpectedTemplateVersion = null,
    bool HasPremiumAccess = false);

public sealed record TemplateGenerationHistoryQuery(
    string? Status,
    int? Skip,
    int? Take);

public sealed record TemplateGenerationUnreadCountResponse(int Count);

public sealed record RegisterTemplatePushTokenCommand(
    Guid UserId,
    string Token,
    string Platform,
    string? DeviceId,
    string? AppVersion,
    string? Locale);

public sealed record UnregisterTemplatePushTokenCommand(
    Guid UserId,
    string Token);

public sealed record TemplateGenerationResponse(
    Guid GenerationId,
    Guid UserId,
    Guid TemplateId,
    string Status,
    int TokenCost,
    TemplateAssetResponse? SourceImageAsset,
    string? NormalizedImageUrl,
    string? ReferenceMotionUrl,
    string? OutputUrl,
    int AttemptCount,
    string? UsedPreprocessingModel,
    string? UsedKlingModel,
    string? PreprocessingProviderRequestId,
    double? PreprocessingInferenceTimeSeconds,
    string? MotionProviderRequestId,
    double? MotionInferenceTimeSeconds,
    double? OutputVideoDurationSeconds,
    decimal? MotionProviderCostUsd,
    string? FailureCode,
    string? FailureMessage,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? PreprocessingCompletedAtUtc,
    DateTime? MotionGenerationCompletedAtUtc,
    DateTime? MediaImportCompletedAtUtc,
    DateTime? CompletedAtUtc,
    bool UserMediaExpired,
    string? TemplateTitle = null,
    string? TemplateType = null,
    string? Stage = null,
    int? ProgressPercent = null,
    string? EstimatedDurationLabel = null,
    DateTime? ChargedAtUtc = null,
    DateTime? RefundedAtUtc = null,
    bool IsUnread = false,
    int? QueuePosition = null,
    int? EstimatedWaitSeconds = null,
    bool HasWatermark = false,
    bool CanRemoveWatermark = false,
    bool IsWatermarkRemoved = false,
    int RemoveWatermarkCostCredits = 1,
    string UserPlan = "free",
    string? WatermarkMessage = null,
    bool SupportsGenerateSimilar = false,
    Guid? ParentGenerationId = null,
    Guid? ParentGenerationResultId = null,
    Guid? SimilarToGenerationId = null,
    string GenerationMode = "normal",
    string? VariationStrength = null,
    int? GenerationSeed = null,
    string? PromptBeforeVariation = null,
    string? PromptAfterVariation = null,
    string InputSourceType = "user_upload",
    Guid? InputMediaAssetId = null,
    Guid? ResultMediaAssetId = null,
    string? InputPreviewUrl = null,
    string? ResultPreviewUrl = null,
    bool CanCompareBeforeAfter = false,
    Guid? PetId = null,
    Guid? PetPhotoId = null,
    string? MediaType = null,
    string? PriorityClass = null,
    int? EstimatedTotalSeconds = null,
    DateTime? EstimatedCompletionAtUtc = null,
    string? QueueReason = null,
    int? RetryAfterSeconds = null,
    bool CanCancel = false)
{
    public Guid JobId => GenerationId;
    public string? MediaUrl => OutputUrl;
}

public sealed record CancelQueuedGenerationResponse(
    Guid GenerationId,
    string Status,
    bool Refunded,
    DateTime CancelledAtUtc);

public sealed record CreateQaGenerationFixturesCommand(
    Guid? ImageTemplateId,
    Guid? VideoTemplateId,
    string[]? Scenarios = null);

public sealed record QaGenerationFixturesResponse(
    IReadOnlyList<TemplateGenerationResponse> Generations,
    IReadOnlyList<QaGenerationWaitTooLongFixtureResponse> WaitTooLong,
    int DeletedBeforeCreate);

public sealed record QaGenerationWaitTooLongFixtureResponse(
    string Scenario,
    string MediaType,
    Guid TemplateId,
    int BacklogJobsCreated,
    int EstimatedWaitSeconds,
    int MaxAllowedWaitSeconds,
    int RetryAfterSeconds,
    string ExpectedErrorCode);

public sealed record QaGenerationFixtureCleanupResponse(
    int DeletedGenerationJobs,
    int DeletedMediaRecords,
    int DeletedRealtimeEvents,
    int RefundedGenerationJobs);

public sealed record RemoveGenerationWatermarkCommand(
    Guid UserId,
    Guid GenerationId,
    string PaymentMethod,
    bool IsPremium);

public sealed record RemoveGenerationWatermarkResponse(
    bool WatermarkRemoved,
    int CreditsSpent,
    int? RemainingCredits,
    string? MediaUrl);

public sealed record GenerationDownloadResponse(
    string MediaUrl,
    bool HasWatermark,
    string FileName);

public sealed record GenerateSimilarRequest(
    string? VariationStrength = null);

public sealed record GenerateSimilarResponse(
    Guid GenerationId,
    string Status);

public sealed record AdminWatermarkSettingsResponse(
    bool Enabled,
    string Text,
    string? LogoUrl,
    double Opacity,
    string Position,
    string Size,
    int CostCredits,
    bool ApplyToImages,
    bool ApplyToVideos,
    string PreviewImageUrl,
    string PreviewVideoFrameUrl);

public sealed record UpdateAdminWatermarkSettingsCommand(
    bool Enabled,
    string Text,
    string? LogoUrl,
    double Opacity,
    string Position,
    string Size,
    int CostCredits,
    bool ApplyToImages,
    bool ApplyToVideos);

public sealed record FalProviderWebhookCommand(
    string RequestId,
    string Status,
    JsonElement Payload,
    string? Error,
    DateTime ReceivedAtUtc);

public sealed record FalProviderWebhookResponse(
    string RequestId,
    Guid? GenerationId,
    string Result);
