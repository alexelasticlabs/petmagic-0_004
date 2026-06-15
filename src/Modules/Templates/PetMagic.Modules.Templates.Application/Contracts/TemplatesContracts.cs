using System.IO;

using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record MediaUploadCommand(
    string FileName,
    string ContentType,
    byte[]? Content,
    Stream? ContentStream,
    long? ContentLengthBytes,
    string? PreferredStorageKey = null)
{
    public MediaUploadCommand(string fileName, string contentType, byte[] content)
        : this(fileName, contentType, content, null, content.LongLength, null)
    {
    }

    public MediaUploadCommand(string fileName, string contentType, Stream contentStream, long? contentLengthBytes = null)
        : this(fileName, contentType, null, contentStream, contentLengthBytes, null)
    {
    }
}

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

public sealed record ChangeTemplateStatusCommand(Guid TemplateId, string Status);

public sealed record CreateTemplateCategoryCommand(
    string Name);

public sealed record UpdateTemplateCategoryCommand(
    Guid CategoryId,
    string Name);

public sealed record ChangeTemplateCategoryArchiveStateCommand(
    Guid CategoryId,
    bool IsArchived);

public sealed record CreateTemplateOfTheDayCommand(
    Guid TemplateId,
    DateOnly StartDate,
    DateOnly? EndDate,
    bool IsActive,
    bool IsManual,
    int Priority,
    string? TitleOverride,
    string? SubtitleOverride,
    string? BadgeTextOverride,
    Guid? CreatedByAdminId);

public sealed record UpdateTemplateOfTheDayCommand(
    Guid Id,
    Guid TemplateId,
    DateOnly StartDate,
    DateOnly? EndDate,
    bool IsActive,
    bool IsManual,
    int Priority,
    string? TitleOverride,
    string? SubtitleOverride,
    string? BadgeTextOverride);

public sealed record AutoPickTemplateOfTheDayCommand(
    DateOnly Date,
    string? AllowedTypes,
    int? ExcludeRecentDays,
    Guid? CreatedByAdminId,
    bool Force = false);

public sealed record UpdateTemplateOfTheDaySettingsCommand(
    bool AutoModeEnabled,
    string? AllowedTypes,
    int? ExcludeRecentDays,
    Guid? UpdatedByAdminId);

public sealed record StartTemplateGenerationCommand(
    Guid UserId,
    Guid TemplateId,
    TemplateAssetCommand SourceImageAsset,
    string? IdempotencyKey = null,
    string? RequestHash = null,
    int? ActiveGenerationLimit = null,
    TemplateAssetCommand? SourceImagePreviewAsset = null)
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
            null)
    {
    }

    public StartTemplateGenerationCommand(
        Guid userId,
        Guid templateId,
        TemplateAssetCommand sourceImageAsset,
        string? _legacyPlaceholder,
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
            null)
    {
    }
}

public sealed record StartTemplateGenerationFromResultCommand(
    Guid UserId,
    Guid ParentGenerationResultId,
    Guid TemplateId,
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null);

public sealed record StartSimilarTemplateGenerationCommand(
    Guid UserId,
    Guid SourceGenerationId,
    string VariationStrength = "medium",
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null);

public sealed record CreatePetCommand(
    Guid UserId,
    string Name,
    string Type,
    string? Breed);

public sealed record UpdatePetCommand(
    Guid UserId,
    Guid PetId,
    string Name,
    string Type,
    string? Breed);

public sealed record UploadPetPhotoCommand(
    Guid UserId,
    Guid PetId,
    MediaUploadCommand Photo);

public sealed record SetPetPhotoFavoriteCommand(
    Guid UserId,
    Guid PetId,
    Guid PhotoId,
    bool IsFavorite);

public sealed record StartTemplateGenerationFromPetCommand(
    Guid UserId,
    Guid PetId,
    Guid? PetPhotoId,
    Guid TemplateId,
    string? IdempotencyKey = null,
    int? ActiveGenerationLimit = null);

public sealed record StoredMediaResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    string? LocalPath);

public sealed record PetPhotoResponse(
    Guid Id,
    Guid PetId,
    Guid MediaAssetId,
    string Url,
    string? ThumbnailUrl,
    string FileName,
    string ContentType,
    long? FileSizeBytes,
    bool IsFavorite,
    bool IsAvatar,
    int SortOrder,
    string Status,
    DateTime CreatedAtUtc,
    bool IsDeleted);

public sealed record PetResponse(
    Guid Id,
    Guid UserId,
    string Name,
    string Type,
    string? Breed,
    Guid? AvatarMediaAssetId,
    string? AvatarUrl,
    int PhotosCount,
    int GenerationsCount,
    string Status,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    bool IsDeleted);

public sealed record AdminPetResponse(
    Guid Id,
    Guid UserId,
    string Name,
    string Type,
    string? Breed,
    Guid? AvatarMediaAssetId,
    string? AvatarUrl,
    int PhotosCount,
    int GenerationsCount,
    string Status,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    bool IsDeleted);

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium");

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

public sealed record TemplateGenerationHistoryQuery(
    string? Status,
    int? Skip,
    int? Take);

public sealed record TemplateGenerationUnreadCountResponse(int Count);

public sealed record RecordTemplateGenerationFeedbackCommand(
    Guid UserId,
    Guid GenerationId,
    int Rating,
    string[] SelectedReasons,
    string? Comment,
    double? InputPhotoQualityScore = null);

public sealed record SubmitFeedbackCommand(
    Guid? UserId,
    string Type,
    string Category,
    int? Rating,
    string? Message,
    Guid? GenerationId,
    Guid? TemplateId,
    Guid? PetId,
    string? SourceScreen,
    string? AppVersion,
    string? Platform,
    string? DeviceModel,
    string? Locale);

public sealed record SubmitFeedbackResponse(Guid FeedbackId, string Status);

public sealed record AdminFeedbackQuery(
    string? Status,
    string? Priority,
    string? Type,
    string? Category,
    Guid? GenerationId,
    Guid? TemplateId,
    string? Platform,
    DateTime? FromUtc,
    DateTime? ToUtc,
    Guid? UserId,
    int? Skip,
    int? Take);

public sealed record AdminFeedbackListItemResponse(
    Guid Id,
    Guid? UserId,
    string Type,
    string Category,
    int? Rating,
    Guid? GenerationId,
    Guid? TemplateId,
    string? TemplateTitle,
    Guid? PetId,
    string SourceScreen,
    string? Platform,
    string Status,
    string Priority,
    string? Message,
    string? PreviewUrl,
    DateTime CreatedAtUtc);

public sealed record AdminFeedbackPageResponse(
    IReadOnlyList<AdminFeedbackListItemResponse> Items,
    int TotalCount,
    int Skip,
    int Take,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record AdminFeedbackDetailsResponse(
    Guid Id,
    Guid? UserId,
    string? UserEmail,
    string? UserPlan,
    int? UserCredits,
    string Type,
    string Category,
    int? Rating,
    string? Message,
    string SourceScreen,
    string? AppVersion,
    string? Platform,
    string? DeviceModel,
    string? Locale,
    string? ErrorCode,
    string? ProviderName,
    string Status,
    string Priority,
    DateTime CreatedAtUtc,
    DateTime? ReviewedAtUtc,
    Guid? ReviewedByAdminId,
    string? AdminNote,
    AdminFeedbackGenerationContextResponse? Generation,
    bool CanRefund,
    CreditRefundResponse? Refund);

public sealed record AdminFeedbackGenerationContextResponse(
    Guid GenerationId,
    Guid UserId,
    Guid TemplateId,
    string TemplateTitle,
    Guid? PetId,
    string? InputPreviewUrl,
    string? ResultPreviewUrl,
    string? ProviderName,
    string? ErrorCode,
    int CreditsCharged,
    DateTime? ChargedAtUtc,
    DateTime? RefundedAtUtc);

public sealed record UpdateFeedbackAdminCommand(
    Guid FeedbackId,
    Guid AdminUserId,
    string? Status,
    string? Priority,
    string? AdminNote);

public sealed record RefundFeedbackCreditsCommand(
    Guid FeedbackId,
    Guid AdminUserId,
    int? Amount,
    string? Reason);

public sealed record CreditRefundResponse(
    Guid Id,
    Guid UserId,
    Guid? FeedbackId,
    Guid? GenerationId,
    int Amount,
    string Reason,
    Guid AdminId,
    DateTime CreatedAtUtc);

public sealed record TemplateFeedbackSummaryResponse(
    Guid TemplateId,
    int PositiveCount,
    int NeutralCount,
    int NegativeCount,
    double PositiveRate,
    double NeutralRate,
    double NegativeRate,
    IReadOnlyList<TemplateFeedbackIssueResponse> TopIssues,
    bool HasNegativeWarning);

public sealed record TemplateFeedbackIssueResponse(string Category, int Count);

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
    DateTime GeneratedAtUtc);

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
    Guid? PetPhotoId = null);

public sealed record AdminTemplateGenerationListPageResponse(
    IReadOnlyList<AdminTemplateGenerationListItemResponse> Items,
    int TotalCount,
    int Skip,
    int Take,
    bool HasMore,
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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    string? ThumbnailUrl = null);

public sealed record PublicTemplateFeedItemResponse(
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
    string? ThumbnailUrl = null,
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    long Version = 0,
    DateTime? UpdatedAtUtc = null);

public sealed record PublicTemplateCategoryResponse(
    string Name);

public sealed record PublicTemplatesCatalogQuery(
    int? Page,
    int? PageSize,
    TemplateType? Type,
    string? Category,
    string? Locale,
    string[]? Tags = null,
    bool? PremiumOnly = null);

public sealed record PublicTemplateCatalogMetadataResponse(
    Guid Id,
    string Title,
    string Category,
    string Type,
    string? ThumbnailUrl,
    string? PreviewUrl,
    int PriceTokens,
    bool IsPremium,
    string[] Tags,
    long Version,
    DateTime UpdatedAtUtc);

public sealed record PublicTemplatesCatalogPageResponse(
    IReadOnlyList<PublicTemplateCatalogMetadataResponse> Items,
    int Page,
    int PageSize,
    bool HasMore,
    long TotalCount,
    DateTime GeneratedAtUtc);

public sealed record PublicTemplatesCatalogVersionResponse(
    long Version,
    DateTime? UpdatedAtUtc);

public sealed record PublicTemplatesCatalogChangesResponse(
    long FromVersion,
    long ToVersion,
    IReadOnlyList<PublicTemplateCatalogMetadataResponse> Upserts,
    IReadOnlyList<Guid> DeletedIds,
    bool NeedsFullResync);

public sealed record PublicTemplatesFeedQuery(
    TemplateType? Type,
    string? Category,
    string[] Tags,
    bool? PremiumOnly,
    string? Search,
    int? Take,
    string? Cursor,
    string? Locale);

public sealed record PublicTemplatesFeedResponse(
    IReadOnlyList<PublicTemplateFeedItemResponse> Items,
    string? NextCursor,
    bool HasMore,
    DateTime GeneratedAtUtc);

public sealed record PublicRandomTemplateQuery(
    TemplateType? Type,
    string? Category,
    bool IncludePremium,
    string? Locale);

public sealed record PublicRandomTemplateResponse(
    PublicTemplateListItemResponse? Template);

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
    IReadOnlyList<string>? PetPhotoRequirements = null,
    bool SupportsGenerationResultInput = false,
    string? RequiredInputMediaType = null,
    bool RecommendedAfterImageGeneration = false,
    bool SupportsGenerateSimilar = true,
    string DefaultVariationStrength = "medium",
    string? ThumbnailUrl = null);

public sealed record CompatibleGenerationTemplateResponse(
    Guid Id,
    string Title,
    string Type,
    string? ThumbnailUrl,
    bool IsPremium,
    bool IsRecommended,
    int TokenCost);

public sealed record CompatibleGenerationTemplatesResponse(
    Guid ResultId,
    string InputMediaType,
    IReadOnlyList<CompatibleGenerationTemplateResponse> Templates);

public sealed record PublicTemplateOfTheDayResponse(
    PublicTemplateOfTheDayItemResponse? Template);

public sealed record PublicTemplateOfTheDayItemResponse(
    Guid TemplateId,
    string Title,
    string Subtitle,
    string BadgeText,
    string Type,
    string? ThumbnailUrl,
    string? PreviewMediaUrl,
    bool IsPremium,
    string RequiredPlan,
    DateOnly Date,
    string Source);

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
    Guid? PetPhotoId = null)
{
    public Guid JobId => GenerationId;
    public string? MediaUrl => OutputUrl;
}

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
