using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationJob
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid TemplateId { get; set; }

    public Guid? ParentGenerationId { get; set; }

    public Guid? ParentGenerationResultId { get; set; }

    public Guid? SimilarToGenerationId { get; set; }

    public TemplateGenerationMode GenerationMode { get; set; } = TemplateGenerationMode.Normal;

    public string? VariationStrength { get; set; }

    public int? GenerationSeed { get; set; }

    public string? PromptBeforeVariation { get; set; }

    public string? PromptAfterVariation { get; set; }

    public Guid? PetId { get; set; }

    public Guid? PetPhotoId { get; set; }

    public string InputSourceType { get; set; } = "user_upload";

    public Guid? InputMediaAssetId { get; set; }

    public Guid? ResultMediaAssetId { get; set; }

    public TemplateGenerationStatus Status { get; set; }

    public int TokenCost { get; set; }

    public string QueueMediaType { get; set; } = TemplateGenerationQueue.MediaTypeImage;

    public string QueueTier { get; set; } = TemplateGenerationQueue.TierFree;

    public string SourceImageUrl { get; set; } = string.Empty;

    public string SourceImageFileName { get; set; } = string.Empty;

    public string SourceImageContentType { get; set; } = string.Empty;

    public long? SourceImageFileSizeBytes { get; set; }

    public string? NormalizedImageUrl { get; set; }

    public string? ReferenceMotionUrl { get; set; }

    public string? ResultUrl { get; set; }

    public string? WatermarkedResultUrl { get; set; }

    public bool IsWatermarkRequired { get; set; }

    public bool IsWatermarkRemoved { get; set; }

    public string? WatermarkFailureCode { get; set; }

    public DateTime? LockedAtUtc { get; set; }

    public string? LockedBy { get; set; }

    public string? IdempotencyKey { get; set; }

    public string? RequestHash { get; set; }

    public string? CorrelationId { get; set; }

    public string? UsedPreprocessingModel { get; set; }

    public string? UsedKlingModel { get; set; }

    public string? PreprocessingProviderRequestId { get; set; }

    public double? PreprocessingInferenceTimeSeconds { get; set; }

    public string? MotionProviderRequestId { get; set; }

    public double? MotionInferenceTimeSeconds { get; set; }

    public string? CurrentProviderStage { get; set; }

    public string? ProviderStatus { get; set; }

    public string? PreprocessingProviderStatusUrl { get; set; }

    public string? PreprocessingProviderResponseUrl { get; set; }

    public string? MotionProviderStatusUrl { get; set; }

    public string? MotionProviderResponseUrl { get; set; }

    public string? ProviderResultUrl { get; set; }

    public double? OutputVideoDurationSeconds { get; set; }

    public decimal? MotionProviderCostUsd { get; set; }

    public DateTime? PreprocessingCompletedAtUtc { get; set; }

    public DateTime? MotionGenerationCompletedAtUtc { get; set; }

    public DateTime? MediaImportCompletedAtUtc { get; set; }

    public DateTime? ProviderSubmittedAtUtc { get; set; }

    public DateTime? ProviderStatusCheckedAtUtc { get; set; }

    public DateTime? ProviderCompletedAtUtc { get; set; }

    public DateTime? WebhookReceivedAtUtc { get; set; }

    public DateTime? ImportStartedAtUtc { get; set; }

    public int AttemptCount { get; set; }

    public string? LastErrorCode { get; set; }

    public string? LastErrorMessage { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime QueuedAtUtc { get; set; }

    public int? EstimatedWaitSecondsAtQueue { get; set; }

    public DateTime? EstimatedCompletionAtQueueUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? LastAttemptAtUtc { get; set; }

    public DateTime? ChargedAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public int RefundAttemptCount { get; set; }

    public string? RefundLastErrorCode { get; set; }

    public DateTime? RefundLastAttemptedAtUtc { get; set; }

    public DateTime? StartedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public DateTime? CancelledAtUtc { get; set; }

    public DateTime? ResultViewedAtUtc { get; set; }

    public DateTime? HiddenByUserAtUtc { get; set; }

    public DateTime? UserMediaDeletedAtUtc { get; set; }

    public DateTime? LastUserMediaCleanupAttemptAtUtc { get; set; }

    public string? UserMediaCleanupFailureCode { get; set; }

    public TemplateItem Template { get; set; } = null!;

    public List<TemplateMediaRecord> MediaRecords { get; set; } = [];

    public List<TemplateGenerationWatermarkUnlock> WatermarkUnlocks { get; set; } = [];
}
