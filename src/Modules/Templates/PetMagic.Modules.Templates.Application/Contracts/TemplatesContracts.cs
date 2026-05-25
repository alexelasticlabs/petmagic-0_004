using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record MediaUploadCommand(
    string FileName,
    string ContentType,
    byte[] Content);

public sealed record TemplateAssetCommand(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds);

public sealed record CreateImageTemplateCommand(
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    TemplateAssetCommand? PreviewAsset,
    string ImageModel,
    string ImagePrompt,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record UpdateImageTemplateCommand(
    Guid TemplateId,
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    TemplateAssetCommand? PreviewAsset,
    string ImageModel,
    string ImagePrompt,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record CreateVideoTemplateCommand(
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    string MusicDescription,
    TemplateAssetCommand? PreviewAsset,
    TemplateAssetCommand? ReferenceMotionAsset,
    string PreprocessingModel,
    string PreprocessingPrompt,
    string KlingModel,
    string KlingPrompt,
    bool KeepOriginalSound,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record UpdateVideoTemplateCommand(
    Guid TemplateId,
    string Title,
    string ShortDescription,
    string Category,
    IReadOnlyList<string> Tags,
    bool IsPremium,
    int TokenCost,
    string PromoBadgeMode,
    string MusicDescription,
    TemplateAssetCommand? PreviewAsset,
    TemplateAssetCommand? ReferenceMotionAsset,
    string PreprocessingModel,
    string PreprocessingPrompt,
    string KlingModel,
    string KlingPrompt,
    bool KeepOriginalSound,
    string? Status = null,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record ChangeTemplateStatusCommand(Guid TemplateId, string Status);

public sealed record CreateTemplateCategoryCommand(
    string Name);

public sealed record UpdateTemplateCategoryCommand(
    Guid CategoryId,
    string Name);

public sealed record ChangeTemplateCategoryArchiveStateCommand(
    Guid CategoryId,
    bool IsArchived);

public sealed record StartTemplateGenerationCommand(
    Guid UserId,
    Guid TemplateId,
    TemplateAssetCommand SourceImageAsset);

public sealed record StoredMediaResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    string? LocalPath);

public sealed record TemplateAssetResponse(
    string Url,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    double? DurationSeconds);

public sealed record AdminTemplateListItemResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string Status,
    string PromoBadgeMode,
    string? EffectivePromoBadge,
    bool IsPremium,
    int TokenCost,
    string[] Tags,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds,
    string? CharacterOrientation,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    decimal? EstimatedCostUsd = null,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record AdminTemplateCategoryListItemResponse(
    Guid CategoryId,
    string Name,
    bool IsArchived,
    int TotalTemplates,
    int VideoTemplates,
    int ImageTemplates,
    int ActiveTemplates,
    int DraftTemplates,
    int ArchivedTemplates,
    int PremiumTemplates,
    string[] Tags,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record AdminTemplateResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string Status,
    string PromoBadgeMode,
    string? EffectivePromoBadge,
    bool IsPremium,
    int TokenCost,
    string[] Tags,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    TemplateAssetResponse? ReferenceMotionAsset,
    double? ReferenceVideoDurationSeconds,
    string? CharacterOrientation,
    string? ImageModel,
    string? ImagePrompt,
    string? PreprocessingModel,
    string? PreprocessingPrompt,
    string? KlingModel,
    string? KlingPrompt,
    bool? KeepOriginalSound,
    decimal? EstimatedProviderCostUsd,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record AdminTemplateStatisticsResponse(
    Guid TemplateId,
    int TotalRuns,
    int QueuedRuns,
    int ProcessingRuns,
    int CompletedRuns,
    int FailedRuns,
    double SuccessRatePercent,
    int TotalTokenCost,
    double AverageTokenCost,
    decimal TotalProviderCostUsd,
    decimal AverageProviderCostUsd,
    DateTime? LastRunAtUtc,
    DateTime? LastCompletedAtUtc,
    double? AverageGenerationSeconds);

public sealed record AdminTemplateTrendPointResponse(
    DateTime DateUtc,
    int TotalRuns,
    int QueuedRuns,
    int ProcessingRuns,
    int CompletedRuns,
    int FailedRuns,
    double SuccessRatePercent,
    int TotalTokenCost,
    decimal TotalProviderCostUsd,
    double? AverageGenerationSeconds);

public sealed record AdminTemplateRecentGenerationResponse(
    Guid GenerationId,
    Guid UserId,
    string Status,
    int TokenCost,
    int AttemptCount,
    string? UsedPreprocessingModel,
    string? UsedKlingModel,
    decimal? MotionProviderCostUsd,
    string? FailureCode,
    string? FailureMessage,
    string? OutputUrl,
    DateTime CreatedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc);

public sealed record AdminTemplateFailureBreakdownItemResponse(
    string FailureCode,
    int Count,
    DateTime? LastOccurredAtUtc);

public sealed record RecordTemplateAnalyticsEventCommand(
    Guid TemplateId,
    string EventType,
    string? Source,
    string? DeviceClass,
    string? CountryCode,
    Guid? UserId,
    Guid? GenerationId,
    string? FeedbackMessage = null);

public sealed record AdminTemplateAnalyticsDimensionResponse(
    string Key,
    string Label,
    int Count,
    double SharePercent);

public sealed record AdminTemplateEventAnalyticsResponse(
    int TotalViews,
    int TotalVideoViews,
    int TotalComplaints,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Sources,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Devices,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Geography);

public sealed record AdminTemplateFeedbackItemResponse(
    Guid EventId,
    string EventType,
    string? FeedbackMessage,
    string Source,
    string DeviceClass,
    string CountryCode,
    Guid? UserId,
    Guid? GenerationId,
    DateTime CreatedAtUtc);

public sealed record AdminUserTemplateGenerationResponse(
    Guid GenerationId,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string Status,
    int TokenCost,
    string? FailureCode,
    string? FailureMessage,
    string? OutputUrl,
    DateTime CreatedAtUtc,
    DateTime? CompletedAtUtc);

public sealed record AdminUserTemplateEventResponse(
    Guid EventId,
    Guid TemplateId,
    string TemplateTitle,
    string EventType,
    string Source,
    string DeviceClass,
    string CountryCode,
    Guid? GenerationId,
    string? FeedbackMessage,
    DateTime CreatedAtUtc);

public sealed record AdminUserTemplateFailureBreakdownItemResponse(
    string FailureCode,
    int Count,
    DateTime? LastOccurredAtUtc);

public sealed record AdminUserTemplateActivityResponse(
    string Kind,
    string Title,
    string? Details,
    DateTime OccurredAtUtc);

public sealed record AdminUserTemplateAnalyticsResponse(
    int TotalGenerations,
    int CompletedGenerations,
    int FailedGenerations,
    DateTime? LastGenerationAtUtc,
    int TotalViews,
    int TotalVideoViews,
    int TemplateAnalyticsEvents,
    DateTime? LastTemplateEventAtUtc,
    IReadOnlyList<AdminUserTemplateGenerationResponse> RecentGenerations,
    IReadOnlyList<AdminUserTemplateEventResponse> RecentTemplateEvents,
    IReadOnlyList<AdminUserTemplateFailureBreakdownItemResponse> FailureBreakdown,
    IReadOnlyList<AdminUserTemplateActivityResponse> RecentActivity);

public sealed record AdminTemplateFeedbackQuery(
    string? Type,
    string? Search,
    int? Take);

public sealed record AdminTemplatesAnalyticsFeedbackItemResponse(
    Guid EventId,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string EventType,
    string? FeedbackMessage,
    string Source,
    string DeviceClass,
    string CountryCode,
    Guid? UserId,
    Guid? GenerationId,
    DateTime CreatedAtUtc);

public sealed record AdminTemplatesAnalyticsQuery(
    int? PeriodDays,
    string? TemplateType,
    string? Category,
    string? Status,
    string? Access,
    string? Sort,
    int? Take);

public sealed record AdminTemplatesAnalyticsSummaryResponse(
    int TotalTemplates,
    int VideoTemplates,
    int ImageTemplates,
    int ActiveTemplates,
    int PremiumTemplates,
    int TotalViews,
    int TotalGenerationStarts,
    int CompletedGenerations,
    int FailedGenerations,
    double ConversionPercent,
    int TotalTokenCost,
    double AverageTokenCost,
    decimal TotalProviderCostUsd,
    int TotalComplaints);

public sealed record AdminTemplatesAnalyticsTrendPointResponse(
    DateTime DateUtc,
    int TotalViews,
    int TotalGenerationStarts,
    int CompletedGenerations,
    int FailedGenerations,
    int TotalTokenCost,
    decimal TotalProviderCostUsd);

public sealed record AdminTemplatesAnalyticsTemplateRowResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string Category,
    string Status,
    bool IsPremium,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset,
    int Views,
    int GenerationStarts,
    int CompletedGenerations,
    int FailedGenerations,
    double ConversionPercent,
    int TotalTokenCost,
    decimal TotalProviderCostUsd,
    DateTime UpdatedAtUtc);

public sealed record AdminTemplatesAnalyticsBreakdownResponse(
    string Key,
    string Label,
    int TemplateCount,
    int Views,
    int GenerationStarts,
    int CompletedGenerations,
    double ConversionPercent,
    int TotalTokenCost,
    decimal TotalProviderCostUsd);

public sealed record AdminTemplatesAnalyticsFunnelResponse(
    int Views,
    int GenerationStarts,
    int CompletedGenerations,
    int FailedGenerations,
    int Complaints);

public sealed record AdminTemplatesAnalyticsOverviewResponse(
    AdminTemplatesAnalyticsSummaryResponse Summary,
    IReadOnlyList<AdminTemplatesAnalyticsTrendPointResponse> TrendPoints,
    IReadOnlyList<AdminTemplatesAnalyticsTemplateRowResponse> TopTemplates,
    IReadOnlyList<AdminTemplatesAnalyticsBreakdownResponse> Categories,
    IReadOnlyList<AdminTemplatesAnalyticsBreakdownResponse> TemplateTypes,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Sources,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Devices,
    IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> Geography,
    IReadOnlyList<AdminTemplatesAnalyticsFeedbackItemResponse> FeedbackItems,
    AdminTemplatesAnalyticsFunnelResponse ConversionFunnel,
    IReadOnlyList<AdminTemplatesAnalyticsTemplateRowResponse> Templates,
    string[] AvailableCategories,
    DateTime GeneratedAtUtc);

public sealed record PublicTemplateListItemResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string? EffectivePromoBadge,
    string[] Tags,
    bool IsPremium,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds,
    IReadOnlyList<string>? PetPhotoRequirements = null);

public sealed record PublicTemplateCategoryResponse(
    string Name);

public sealed record PublicTemplatesFeedQuery(
    TemplateType? Type,
    string? Category,
    string[] Tags,
    bool? PremiumOnly,
    string? Search,
    int? Take,
    string? Cursor);

public sealed record PublicTemplatesFeedResponse(
    IReadOnlyList<PublicTemplateListItemResponse> Items,
    string? NextCursor,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record PublicTemplateResponse(
    Guid TemplateId,
    string TemplateType,
    string Title,
    string ShortDescription,
    string Category,
    string? EffectivePromoBadge,
    string[] Tags,
    bool IsPremium,
    int TokenCost,
    TemplateAssetResponse? PreviewAsset,
    string? MusicDescription,
    double? ReferenceVideoDurationSeconds,
    IReadOnlyList<string>? PetPhotoRequirements = null);

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
    bool UserMediaExpired);
