using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false);

public sealed record AdminTemplateCatalogQuery(
    string? Type,
    string? Status,
    string? Search,
    string? Category,
    string? Access,
    string? Sort,
    int? Skip,
    int? Take);

public sealed record AdminTemplateCatalogPageResponse(
    IReadOnlyList<AdminTemplateListItemResponse> Items,
    int Skip,
    int Take,
    int TotalCount,
    bool HasMore);

public sealed record AdminTemplateOfTheDayResponse(
    Guid Id,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string Category,
    string Status,
    bool IsPremium,
    TemplateAssetResponse? PreviewAsset,
    DateOnly StartDate,
    DateOnly? EndDate,
    bool IsActive,
    bool IsManual,
    int Priority,
    string? TitleOverride,
    string? SubtitleOverride,
    string? BadgeTextOverride,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    Guid? CreatedByAdminId);

public sealed record AdminTemplateOfTheDayScheduleResponse(
    IReadOnlyList<AdminTemplateOfTheDayResponse> Items,
    int Skip,
    int Take,
    int TotalCount,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record AdminTemplateOfTheDaySettingsResponse(
    bool AutoModeEnabled,
    string AllowedTypes,
    int ExcludeRecentDays,
    DateTime UpdatedAtUtc,
    Guid? UpdatedByAdminId);

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

public sealed record AdminTemplateCategoryDiagnosticsResponse(
    int TotalActiveTemplates,
    int NoncanonicalTemplates,
    double NoncanonicalPercent,
    IReadOnlyList<AdminTemplateCategoryDiagnosticItemResponse> Items,
    DateTime GeneratedAtUtc);

public sealed record AdminTemplateCategoryDiagnosticItemResponse(
    Guid TemplateId,
    string Title,
    string Category,
    string NormalizedCategory,
    string TemplateType,
    string Status,
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
    TemplateAssetResponse? ThumbnailAsset,
    TemplateAssetResponse? AnimatedPreviewAsset,
    TemplateAssetResponse? FeedLoopLowAsset,
    TemplateAssetResponse? FeedLoopMediumAsset,
    TemplateAssetResponse? DetailPreviewAsset,
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
    DateTime? PublishedAtUtc,
    DateTime UpdatedAtUtc,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    bool IsQaOnly = false);

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
    string? FeedbackMessage = null,
    string? MetadataJson = null);

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

public sealed record AdminModerationQueueQuery(
    string? Status,
    string? Search,
    int? Skip,
    int? Take);

public sealed record AdminModerationQueueItemResponse(
    Guid EventId,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string EventType,
    string Status,
    string? Message,
    string Source,
    string DeviceClass,
    string CountryCode,
    Guid? UserId,
    Guid? GenerationId,
    string? ModerationComment,
    DateTime CreatedAtUtc,
    DateTime? ModeratedAtUtc);

public sealed record AdminModerationQueuePageResponse(
    IReadOnlyList<AdminModerationQueueItemResponse> Items,
    int Skip,
    int Take,
    int TotalCount,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record AdminModerationDecisionCommand(
    Guid EventId,
    string Action,
    string Reason);

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

public sealed record AdminTemplateGenerationDashboardMetricsResponse(
    int TotalJobs,
    int GenerationsToday,
    int GenerationsThisWeek,
    int GenerationsThisMonth,
    int FailedGenerationsToday,
    int FailedGenerationsThisWeek,
    int FailedGenerationsThisMonth,
    int PendingJobs,
    int RunningJobs,
    int CompletedJobs,
    int FailedJobs,
    int CancelledJobs,
    int RetryingJobs,
    DateTime GeneratedAtUtc,
    int CancellingJobs = 0);

public sealed record AdminTemplateGenerationsQuery(
    string? Status,
    string? Provider,
    string? User,
    string? Search,
    int? Skip,
    int? Take);

public sealed record AdminTemplateGenerationListItemResponse(
    Guid GenerationId,
    Guid UserId,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string Status,
    string? Provider,
    string? Model,
    int TokenCost,
    int AttemptCount,
    decimal? ProviderCostUsd,
    string? FailureCode,
    string? FailureMessage,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? StartedAtUtc,
    DateTime? CompletedAtUtc,
    DateTime? RefundedAtUtc,
    bool IsWatermarkRequired,
    bool IsWatermarkRemoved,
    string? WatermarkedMediaPath,
    string? WatermarkUnlockMethod,
    Guid? WatermarkUnlockedByUserId,
    int? WatermarkCreditsSpent,
    DateTime? WatermarkUnlockedAtUtc,
    Guid? ParentGenerationId = null,
    Guid? ParentGenerationResultId = null,
    string InputSourceType = "user_upload",
    Guid? InputMediaAssetId = null,
    Guid? ResultMediaAssetId = null,
    string? InputPreviewUrl = null,
    string? ResultPreviewUrl = null,
    bool CanCompareBeforeAfter = false,
    string? ParentTemplateTitle = null,
    string? ParentTemplateType = null,
    int ChildCount = 0,
    Guid? SimilarToGenerationId = null,
    string GenerationMode = "normal",
    string? VariationStrength = null,
    int? GenerationSeed = null,
    string? PromptBeforeVariation = null,
    string? PromptAfterVariation = null,
    Guid? PetId = null,
    Guid? PetPhotoId = null,
    bool CanCancel = false,
    bool CanRetry = false);

public sealed record AdminTemplateGenerationListPageResponse(
    IReadOnlyList<AdminTemplateGenerationListItemResponse> Items,
    int TotalCount,
    int Skip,
    int Take,
    bool HasMore,
    DateTime GeneratedAtUtc);
