namespace PetMagic.Modules.Templates.Infrastructure.Options;

public sealed class TemplatesOptions
{
    public const string SectionName = "Templates";

    public string StorageProvider { get; init; } = TemplateStorageProviders.Local;

    public string AiProvider { get; init; } = TemplateAiProviders.Fake;

    public required string PublicBaseUrl { get; init; }

    public required string LocalMediaRootPath { get; init; }

    public required string DefaultPreprocessingPrompt { get; init; }

    public required string DefaultKlingPrompt { get; init; }

    public required string DefaultImagePrompt { get; init; }

    public required string[] AllowedImageModels { get; init; }

    public required string[] AllowedPreprocessingModels { get; init; }

    public required string[] AllowedKlingModels { get; init; }

    public string SourceLocalizationLocale { get; init; } = "en";

    public required string[] SupportedLocalizationLocales { get; init; }

    public long PreviewMaxFileSizeBytes { get; init; } = 25 * 1024 * 1024;

    public long ReferenceMotionMaxFileSizeBytes { get; init; } = 100 * 1024 * 1024;

    public bool SeedSampleTemplates { get; init; }

    public bool QaFixturesEnabled { get; init; }

    public bool GenerationWorkerEnabled { get; init; } = true;

    public int GenerationWorkerPollIntervalMilliseconds { get; init; } = 1_000;

    public int RealtimePollingIntervalMilliseconds { get; init; } = 1_000;

    public int RealtimeSubscriberBufferSize { get; init; } = 256;

    public int RealtimeEventRetentionMinutes { get; init; } = 60;

    public int RealtimeEventCleanupIntervalMinutes { get; init; } = 10;

    public int RealtimeEventCleanupBatchSize { get; init; } = 1_000;

    public int MaxConcurrentJobsPerWorker { get; init; } = 1;

    public int GlobalMaxConcurrentGenerations { get; init; } = 3;

    public int ImageReservedConcurrentGenerations { get; init; }

    public int ImageMaxConcurrentGenerations { get; init; } = 2;

    public int ImageProtectedConcurrentGenerations { get; init; }

    public int VideoReservedConcurrentGenerations { get; init; }

    public int VideoMaxConcurrentGenerations { get; init; } = 1;

    public int VideoBorrowMaxConcurrentGenerations { get; init; }

    public bool EnableElasticLaneBorrowing { get; init; }

    public bool AllowVideoBorrowWhenImageQueueEmpty { get; init; } = true;

    public int AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds { get; init; } = 120;

    public string VideoBorrowReleaseMode { get; init; } = "natural_completion";

    public int BorrowedVideoMaxAgeSeconds { get; init; }

    public string BorrowingPriorityTiers { get; init; } = "premium,privileged,admin,free";

    public int VideoPreprocessingMaxConcurrentGenerations { get; init; } = 1;

    public int FalProviderConcurrencyLimit { get; init; }

    public int FalProviderReservedConcurrency { get; init; } = 1;

    public decimal FalProviderBalanceLowThresholdUsd { get; init; } = 100m;

    public decimal FalProviderBalanceCriticalThresholdUsd { get; init; } = 25m;

    public decimal FalProviderSpendDailyLimitUsd { get; init; }

    public int MaxAiProviderRequestsPerMinute { get; init; } = 60;

    public int QueueMaxSize { get; init; } = 1_000;

    public int EstimatedVideoGenerationSeconds { get; init; } = 420;

    public int EstimatedImageGenerationSeconds { get; init; } = 90;

    public int EstimatedVideoPreprocessingSeconds { get; init; } = 90;

    public int FreeQueuePriorityScore { get; init; } = 1_000;

    public int PremiumQueuePriorityScore { get; init; } = 4_000;

    public int PrivilegedQueuePriorityScore { get; init; } = 8_000;

    public int AdminQueuePriorityScore { get; init; } = 10_000;

    public int QueuePriorityAgingIntervalSeconds { get; init; } = 60;

    public int QueuePriorityAgingBoost { get; init; } = 500;

    public bool CancelQueuedGenerationEnabled { get; init; } = true;

    public int FreeImageMaxEstimatedWaitSeconds { get; init; } = 1_800;

    public int PremiumImageMaxEstimatedWaitSeconds { get; init; } = 600;

    public int PrivilegedImageMaxEstimatedWaitSeconds { get; init; } = 600;

    public int FreeVideoMaxEstimatedWaitSeconds { get; init; } = 3_600;

    public int PremiumVideoMaxEstimatedWaitSeconds { get; init; } = 1_800;

    public int PrivilegedVideoMaxEstimatedWaitSeconds { get; init; } = 1_800;

    public int FreeUserMaxActiveGenerations { get; init; } = 1;

    public int PremiumUserMaxActiveGenerations { get; init; } = 3;

    public int PrivilegedUserMaxActiveGenerations { get; init; } = 10;

    public int JobLockTimeoutMilliseconds { get; init; } = 900_000;

    public int StaleProcessingRecoveryDelayMilliseconds { get; init; } = 900_000;

    public int OrphanQueuedJobTimeoutMilliseconds { get; init; } = 120_000;

    public int MaxGenerationAttempts { get; init; } = 3;

    public int ProviderTransientRetryBaseDelaySeconds { get; init; } = 30;

    public int MaxRefundAttempts { get; init; } = 5;

    public int RefundRetryDelayMilliseconds { get; init; } = 30_000;

    public int GenerationRetentionDaysAfterCompletion { get; init; } = 7;

    public int TemporaryUploadRetentionMinutes { get; init; } = 60;

    public bool MediaCleanupWorkerEnabled { get; init; } = true;

    public int MediaCleanupPollIntervalMilliseconds { get; init; } = 1_000;

    public int MediaCleanupRetryDelayMilliseconds { get; init; } = 30_000;

    public bool TemplateOfTheDayAutoPickWorkerEnabled { get; init; } = true;

    public int TemplateOfTheDayAutoPickIntervalMinutes { get; init; } = 60;

    public string TemplateOfTheDayBusinessTimeZone { get; init; } = "UTC";

    public string TemplateOfTheDayAutoPickAllowedTypes { get; init; } = "both";

    public int TemplateOfTheDayAutoPickExcludeRecentDays { get; init; } = 7;

    public int MetadataTempRetentionHours { get; init; } = 24;

    public bool CleanupExpiredGenerationMediaWhileRefundPending { get; init; } = true;

    public int UserMediaReadUrlTtlSeconds { get; init; } = 900;

    public int GenerationShareTokenTtlDays { get; init; } = 30;

    public long GeneratedVideoMaxFileSizeBytes { get; init; } = 250 * 1024 * 1024;

    public long GeneratedImageMaxFileSizeBytes { get; init; } = 30 * 1024 * 1024;

    public R2StorageOptions R2 { get; init; } = new();

    public FalAiOptions Fal { get; init; } = new();

    public FirebasePushOptions FirebasePush { get; init; } = new();

    public TemplateWatermarkOptions Watermark { get; init; } = new();
}

public static class TemplateStorageProviders
{
    public const string Local = "Local";
    public const string R2 = "R2";
}

public static class TemplateAiProviders
{
    public const string Fake = "Fake";
    public const string Fal = "Fal";
}

public sealed class R2StorageOptions
{
    public string AccountId { get; init; } = string.Empty;

    public string AccessKey { get; init; } = string.Empty;

    public string SecretKey { get; init; } = string.Empty;

    public string BucketName { get; init; } = string.Empty;

    public string PublicBaseUrl { get; init; } = string.Empty;

    public string ObjectKeyPrefix { get; init; } = "templates-media";

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(AccountId)
        && !string.IsNullOrWhiteSpace(AccessKey)
        && !string.IsNullOrWhiteSpace(SecretKey)
        && !string.IsNullOrWhiteSpace(BucketName)
        && !string.IsNullOrWhiteSpace(PublicBaseUrl);
}

public sealed class FalAiOptions
{
    public string ApiKey { get; init; } = string.Empty;

    public string QueueBaseUrl { get; init; } = "https://queue.fal.run";

    public string WebhookUrl { get; init; } = string.Empty;

    public string WebhookJwksUrl { get; init; } = "https://rest.fal.ai/.well-known/jwks.json";

    public int StartTimeoutSeconds { get; init; } = 120;

    public int PollIntervalMilliseconds { get; init; } = 2_000;

    public int MaxPollingAttempts { get; init; } = 180;

    public int ImageMaxPollingAttempts { get; init; } = 180;

    public int ImagePreprocessingMaxPollingAttempts { get; init; } = 180;

    public int VideoMaxPollingAttempts { get; init; } = 300;

    public bool IsConfigured => !string.IsNullOrWhiteSpace(ApiKey);
}

public sealed class FirebasePushOptions
{
    public bool Enabled { get; init; }

    public string ProjectId { get; init; } = string.Empty;

    public string ServiceAccountJson { get; init; } = string.Empty;

    public string ServiceAccountJsonPath { get; init; } = string.Empty;

    public bool IsConfigured =>
        Enabled
        && !string.IsNullOrWhiteSpace(ProjectId)
        && (!string.IsNullOrWhiteSpace(ServiceAccountJson) || !string.IsNullOrWhiteSpace(ServiceAccountJsonPath));
}

public sealed class TemplateWatermarkOptions
{
    public bool Enabled { get; init; } = true;

    public string Text { get; init; } = "Made with PetMagic";

    public string LogoUrl { get; init; } = string.Empty;

    public double Opacity { get; init; } = 0.55;

    public string Position { get; init; } = "bottom-right";

    public string Size { get; init; } = "small";

    public int CostCredits { get; init; } = 1;

    public bool ApplyToImages { get; init; } = true;

    public bool ApplyToVideos { get; init; } = true;

    public string PreviewImageUrl { get; init; } = string.Empty;

    public string PreviewVideoFrameUrl { get; init; } = string.Empty;

    public string FfmpegPath { get; init; } = "ffmpeg";
}
