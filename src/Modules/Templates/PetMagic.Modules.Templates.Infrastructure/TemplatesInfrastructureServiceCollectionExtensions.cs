using Amazon.Runtime;
using Amazon.S3;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Security;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class TemplatesInfrastructureServiceCollectionExtensions
{
    private static readonly TimeSpan ExternalHttpClientTimeout = TimeSpan.FromSeconds(30);

    public static IServiceCollection AddTemplatesInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment? environment = null,
        string? schedulerComponent = null)
    {
        services.AddMemoryCache();

        var section = configuration.GetSection(TemplatesOptions.SectionName);
        var r2Section = section.GetSection("R2");
        var falSection = section.GetSection("Fal");
        var firebasePushSection = section.GetSection("FirebasePush");
        var watermarkSection = section.GetSection("Watermark");
        var configuredStorageProvider = ReadValue(section, "StorageProvider", "TEMPLATES_STORAGE_PROVIDER");
        var configuredAiProvider = ReadValue(section, "AiProvider", "TEMPLATES_AI_PROVIDER");
        var mediaReadUrlSigningOptions = new TemplateMediaReadUrlSigningOptions
        {
            SigningKey = configuration["Jwt:SigningKey"] ?? string.Empty
        };
        var options = new TemplatesOptions
        {
            StorageProvider = configuredStorageProvider
                ?? (HasR2Environment() ? TemplateStorageProviders.R2 : TemplateStorageProviders.Local),
            AiProvider = configuredAiProvider
                ?? (HasFalEnvironment() ? TemplateAiProviders.Fal : TemplateAiProviders.Fake),
            PublicBaseUrl = section["PublicBaseUrl"] ?? string.Empty,
            LocalMediaRootPath = section["LocalMediaRootPath"] ?? Path.Combine("wwwroot", "templates-media"),
            DefaultPreprocessingPrompt = section["DefaultPreprocessingPrompt"]
                ?? "Keep the same pet, same face, same fur, same colors, same background, same lighting and camera angle. Adjust the pet into an upright pose standing on its two hind legs like a human, with the front paws naturally positioned like arms. Make the full body clearly visible and suitable for motion transfer. Do not change the pet’s identity, breed, facial features, background, or image style.",
            DefaultKlingPrompt = section["DefaultKlingPrompt"]
                ?? "A cute pet performing a funny viral dance, smooth animation, high quality.",
            DefaultImagePrompt = section["DefaultImagePrompt"]
                ?? "Keep the same pet, same face, same fur, same colors, same eyes, same breed, and the same overall identity. Apply the template style and scene to the uploaded pet photo without replacing the pet with a different animal.",
            AllowedImageModels = ReadValues(section, "AllowedImageModels", [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit",
                "fal-ai/flux-2-pro/edit",
                "fal-ai/gpt-image-1.5/edit",
                "fal-ai/bytedance/seedream/v5/lite/edit",
                "fal-ai/nano-banana-2/edit"
            ]),
            AllowedPreprocessingModels = ReadValues(section, "AllowedPreprocessingModels", [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit",
                "fal-ai/flux-2-pro/edit",
                "fal-ai/gpt-image-1.5/edit",
                "fal-ai/bytedance/seedream/v5/lite/edit",
                "fal-ai/nano-banana-2/edit"
            ]),
            AllowedKlingModels = ReadValues(section, "AllowedKlingModels", [
                "fal-ai/kling-video/v3/pro/motion-control",
                "fal-ai/kling-video/v3/standard/motion-control"
            ]),
            SourceLocalizationLocale = section["SourceLocalizationLocale"] ?? "en",
            SupportedLocalizationLocales = ReadValues(section, "SupportedLocalizationLocales", [
                "ru",
                "de",
                "es",
                "fr",
                "it",
                "pl"
            ]),
            LocalizationBackfillEnabled = ParseBool(section["LocalizationBackfillEnabled"], false),
            PreviewMaxFileSizeBytes = ParseLong(section["PreviewMaxFileSizeBytes"], 25 * 1024 * 1024),
            ReferenceMotionMaxFileSizeBytes = ParseLong(section["ReferenceMotionMaxFileSizeBytes"], 100 * 1024 * 1024),
            SeedSampleTemplates = ParseBool(section["SeedSampleTemplates"], false),
            QaFixturesEnabled = ParseBool(ReadValue(section, "QaFixturesEnabled", "PETMAGIC_QA_FIXTURES_ENABLED"), false),
            GenerationWorkerEnabled = ParseBool(section["GenerationWorkerEnabled"], true),
            GenerationSchedulerV2Enabled = ParseBool(section["GenerationSchedulerV2Enabled"], false),
            GenerationWorkerPollIntervalMilliseconds = ParseInt(section["GenerationWorkerPollIntervalMilliseconds"], 1_000),
            RealtimePollingIntervalMilliseconds = ParsePositiveInt(section["RealtimePollingIntervalMilliseconds"], 1_000),
            RealtimeEventRetentionMinutes = ParsePositiveInt(section["RealtimeEventRetentionMinutes"], 60),
            RealtimeEventCleanupIntervalMinutes = ParsePositiveInt(section["RealtimeEventCleanupIntervalMinutes"], 10),
            RealtimeEventCleanupBatchSize = ParsePositiveInt(section["RealtimeEventCleanupBatchSize"], 1_000),
            GenerationDispatchConcurrency = ParsePositiveInt(section["GenerationDispatchConcurrency"], 4),
            ProviderReconciliationConcurrency = ParsePositiveInt(section["ProviderReconciliationConcurrency"], 4),
            MediaImportConcurrency = ParsePositiveInt(section["MediaImportConcurrency"], 1),
            GenerationMaintenanceConcurrency = ParsePositiveInt(section["GenerationMaintenanceConcurrency"], 1),
            ProviderWebhookInboxMaxFailureCount = ParsePositiveInt(section["ProviderWebhookInboxMaxFailureCount"], 8),
            ProviderWebhookInboxRetentionDays = ParsePositiveInt(section["ProviderWebhookInboxRetentionDays"], 7),
            ProviderWebhookInboxCleanupIntervalMinutes = ParsePositiveInt(section["ProviderWebhookInboxCleanupIntervalMinutes"], 60),
            ProviderWebhookInboxCleanupBatchSize = ParsePositiveInt(section["ProviderWebhookInboxCleanupBatchSize"], 500),
            GlobalMaxConcurrentGenerations = ParsePositiveInt(section["GlobalMaxConcurrentGenerations"], 3),
            ImageReservedConcurrentGenerations = ParseNonNegativeInt(section["ImageReservedConcurrentGenerations"], 0),
            ImageMaxConcurrentGenerations = ParsePositiveInt(section["ImageMaxConcurrentGenerations"], 2),
            ImageProtectedConcurrentGenerations = ParseNonNegativeInt(section["ImageProtectedConcurrentGenerations"], 0),
            VideoReservedConcurrentGenerations = ParseNonNegativeInt(section["VideoReservedConcurrentGenerations"], 0),
            VideoMaxConcurrentGenerations = ParsePositiveInt(section["VideoMaxConcurrentGenerations"], 1),
            VideoBorrowMaxConcurrentGenerations = ParseNonNegativeInt(section["VideoBorrowMaxConcurrentGenerations"], 0),
            EnableElasticLaneBorrowing = ParseBool(section["EnableElasticLaneBorrowing"], false),
            AllowVideoBorrowWhenImageQueueEmpty = ParseBool(section["AllowVideoBorrowWhenImageQueueEmpty"], true),
            AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds = ParsePositiveInt(section["AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds"], 120),
            VideoBorrowReleaseMode = section["VideoBorrowReleaseMode"] ?? "natural_completion",
            BorrowedVideoMaxAgeSeconds = ParseNonNegativeInt(section["BorrowedVideoMaxAgeSeconds"], 0),
            BorrowingPriorityTiers = section["BorrowingPriorityTiers"] ?? "premium,privileged,admin,free",
            VideoPreprocessingMaxConcurrentGenerations = ParsePositiveInt(section["VideoPreprocessingMaxConcurrentGenerations"], 1),
            FalProviderConcurrencyLimit = ParseNonNegativeInt(section["FalProviderConcurrencyLimit"], 0),
            FalProviderReservedConcurrency = ParseNonNegativeInt(section["FalProviderReservedConcurrency"], 1),
            FalProviderBalanceLowThresholdUsd = ParseNonNegativeDecimal(section["FalProviderBalanceLowThresholdUsd"], 10m),
            FalProviderBalanceCriticalThresholdUsd = ParseNonNegativeDecimal(section["FalProviderBalanceCriticalThresholdUsd"], 5m),
            FalProviderSpendDailyLimitUsd = ParseNonNegativeDecimal(section["FalProviderSpendDailyLimitUsd"], 0m),
            MaxAiProviderRequestsPerMinute = ParseNonNegativeInt(section["MaxAiProviderRequestsPerMinute"], 60),
            QueueMaxSize = ParseNonNegativeInt(section["QueueMaxSize"], 1_000),
            EstimatedVideoGenerationSeconds = ParsePositiveInt(section["EstimatedVideoGenerationSeconds"], 420),
            EstimatedImageGenerationSeconds = ParsePositiveInt(section["EstimatedImageGenerationSeconds"], 90),
            EstimatedVideoPreprocessingSeconds = ParsePositiveInt(section["EstimatedVideoPreprocessingSeconds"], 90),
            EstimatedImageImportSeconds = ParsePositiveInt(section["EstimatedImageImportSeconds"], 30),
            EstimatedVideoImportSeconds = ParsePositiveInt(section["EstimatedVideoImportSeconds"], 120),
            FreeQueuePriorityScore = ParsePositiveInt(section["FreeQueuePriorityScore"], 1_000),
            PremiumQueuePriorityScore = ParsePositiveInt(section["PremiumQueuePriorityScore"], 4_000),
            PrivilegedQueuePriorityScore = ParsePositiveInt(section["PrivilegedQueuePriorityScore"], 8_000),
            AdminQueuePriorityScore = ParsePositiveInt(section["AdminQueuePriorityScore"], 10_000),
            QueuePriorityAgingIntervalSeconds = ParsePositiveInt(section["QueuePriorityAgingIntervalSeconds"], 60),
            QueuePriorityAgingBoost = ParseNonNegativeInt(section["QueuePriorityAgingBoost"], 500),
            CancelQueuedGenerationEnabled = ParseBool(section["CancelQueuedGenerationEnabled"], true),
            FreeImageMaxEstimatedWaitSeconds = ParsePositiveInt(section["FreeImageMaxEstimatedWaitSeconds"], 1_800),
            PremiumImageMaxEstimatedWaitSeconds = ParsePositiveInt(section["PremiumImageMaxEstimatedWaitSeconds"], 600),
            PrivilegedImageMaxEstimatedWaitSeconds = ParsePositiveInt(section["PrivilegedImageMaxEstimatedWaitSeconds"], 600),
            FreeVideoMaxEstimatedWaitSeconds = ParsePositiveInt(section["FreeVideoMaxEstimatedWaitSeconds"], 3_600),
            PremiumVideoMaxEstimatedWaitSeconds = ParsePositiveInt(section["PremiumVideoMaxEstimatedWaitSeconds"], 1_800),
            PrivilegedVideoMaxEstimatedWaitSeconds = ParsePositiveInt(section["PrivilegedVideoMaxEstimatedWaitSeconds"], 1_800),
            FreeUserMaxActiveGenerations = ParsePositiveInt(section["FreeUserMaxActiveGenerations"], 1),
            PremiumUserMaxActiveGenerations = ParsePositiveInt(section["PremiumUserMaxActiveGenerations"], 3),
            PrivilegedUserMaxActiveGenerations = ParsePositiveInt(section["PrivilegedUserMaxActiveGenerations"], 10),
            JobLockTimeoutMilliseconds = ParsePositiveInt(
                section["JobLockTimeoutMilliseconds"] ?? section["StaleProcessingRecoveryDelayMilliseconds"],
                900_000),
            ProviderReconciliationClaimLeaseMilliseconds = ParsePositiveInt(
                section["ProviderReconciliationClaimLeaseMilliseconds"],
                90_000),
            StaleProcessingRecoveryDelayMilliseconds = ParsePositiveInt(section["StaleProcessingRecoveryDelayMilliseconds"], 900_000),
            OrphanQueuedJobTimeoutMilliseconds = ParsePositiveInt(section["OrphanQueuedJobTimeoutMilliseconds"], 120_000),
            MaxGenerationAttempts = ParsePositiveInt(section["MaxGenerationAttempts"], 3),
            ProviderTransientRetryBaseDelaySeconds = ParsePositiveInt(section["ProviderTransientRetryBaseDelaySeconds"], 30),
            MediaImportMaxAttempts = ParsePositiveInt(section["MediaImportMaxAttempts"], 5),
            MediaImportRetryBaseDelaySeconds = ParsePositiveInt(section["MediaImportRetryBaseDelaySeconds"], 30),
            MaxRefundAttempts = ParsePositiveInt(section["MaxRefundAttempts"], 5),
            RefundRetryDelayMilliseconds = ParseNonNegativeInt(section["RefundRetryDelayMilliseconds"], 30_000),
            GenerationRetentionDaysAfterCompletion = ParseInt(section["GenerationRetentionDaysAfterCompletion"], 7),
            TemporaryUploadRetentionMinutes = ParsePositiveInt(section["TemporaryUploadRetentionMinutes"], 60),
            MediaCleanupWorkerEnabled = ParseBool(section["MediaCleanupWorkerEnabled"], true),
            MediaCleanupPollIntervalMilliseconds = ParsePositiveInt(section["MediaCleanupPollIntervalMilliseconds"], 1_000),
            MediaCleanupRetryDelayMilliseconds = ParseNonNegativeInt(section["MediaCleanupRetryDelayMilliseconds"], 30_000),
            TemplateOfTheDayAutoPickWorkerEnabled = ParseBool(section["TemplateOfTheDayAutoPickWorkerEnabled"], true),
            TemplateOfTheDayAutoPickIntervalMinutes = ParsePositiveInt(section["TemplateOfTheDayAutoPickIntervalMinutes"], 60),
            TemplateOfTheDayBusinessTimeZone = section["TemplateOfTheDayBusinessTimeZone"] ?? "UTC",
            TemplateOfTheDayAutoPickAllowedTypes = section["TemplateOfTheDayAutoPickAllowedTypes"] ?? "both",
            TemplateOfTheDayAutoPickExcludeRecentDays = ParseNonNegativeInt(section["TemplateOfTheDayAutoPickExcludeRecentDays"], 7),
            MetadataTempRetentionHours = ParsePositiveInt(section["MetadataTempRetentionHours"], 24),
            CleanupExpiredGenerationMediaWhileRefundPending = ParseBool(section["CleanupExpiredGenerationMediaWhileRefundPending"], true),
            UserMediaReadUrlTtlSeconds = ParsePositiveInt(section["UserMediaReadUrlTtlSeconds"], 900),
            GenerationShareTokenTtlDays = ParsePositiveInt(section["GenerationShareTokenTtlDays"], 30),
            GeneratedVideoMaxFileSizeBytes = ParseLong(section["GeneratedVideoMaxFileSizeBytes"], 250 * 1024 * 1024),
            GeneratedImageMaxFileSizeBytes = ParseLong(section["GeneratedImageMaxFileSizeBytes"], 30 * 1024 * 1024),
            R2 = new R2StorageOptions
            {
                AccountId = ReadValue(r2Section, "AccountId", "R2_ACCOUNT_ID") ?? string.Empty,
                AccessKey = ReadValue(r2Section, "AccessKey", "R2_ACCESS_KEY") ?? string.Empty,
                SecretKey = ReadValue(r2Section, "SecretKey", "R2_SECRET_KEY") ?? string.Empty,
                BucketName = ReadValue(r2Section, "BucketName", "R2_BUCKET_NAME") ?? string.Empty,
                PublicBaseUrl = ReadValue(r2Section, "PublicBaseUrl", "R2_PUBLIC_URL") ?? string.Empty,
                ObjectKeyPrefix = r2Section["ObjectKeyPrefix"] ?? "templates-media"
            },
            Fal = new FalAiOptions
            {
                ApiKey = ReadValue(falSection, "ApiKey", "FAL_AI_API_KEY") ?? string.Empty,
                QueueBaseUrl = falSection["QueueBaseUrl"] ?? "https://queue.fal.run",
                WebhookUrl = ReadValue(falSection, "WebhookUrl", "FAL_WEBHOOK_URL") ?? string.Empty,
                WebhookJwksUrl = falSection["WebhookJwksUrl"] ?? "https://rest.fal.ai/.well-known/jwks.json",
                StartTimeoutSeconds = ParseInt(falSection["StartTimeoutSeconds"], 120),
                PollIntervalMilliseconds = ParseInt(falSection["PollIntervalMilliseconds"], 2_000),
                MaxPollingAttempts = ParseInt(falSection["MaxPollingAttempts"], 180),
                ImageMaxPollingAttempts = ParsePositiveInt(falSection["ImageMaxPollingAttempts"], 180),
                ImagePreprocessingMaxPollingAttempts = ParsePositiveInt(falSection["ImagePreprocessingMaxPollingAttempts"], 180),
                VideoMaxPollingAttempts = ParsePositiveInt(falSection["VideoMaxPollingAttempts"], 300),
                CancelMaxAttempts = ParsePositiveInt(falSection["CancelMaxAttempts"], 3)
            },
            FirebasePush = new FirebasePushOptions
            {
                Enabled = ParseBool(firebasePushSection["Enabled"], false),
                ProjectId = ReadValue(firebasePushSection, "ProjectId", "FIREBASE_PROJECT_ID") ?? string.Empty,
                ServiceAccountJson = ReadValue(firebasePushSection, "ServiceAccountJson", "FIREBASE_SERVICE_ACCOUNT_JSON") ?? string.Empty,
                ServiceAccountJsonPath = ReadValue(firebasePushSection, "ServiceAccountJsonPath", "FIREBASE_SERVICE_ACCOUNT_JSON_PATH") ?? string.Empty
            },
            Watermark = new TemplateWatermarkOptions
            {
                Enabled = ParseBool(watermarkSection["Enabled"], true),
                Text = watermarkSection["Text"] ?? "Made with PetMagic",
                LogoUrl = watermarkSection["LogoUrl"] ?? string.Empty,
                Opacity = ParseDouble(watermarkSection["Opacity"], 0.55, 0.45, 0.65),
                Position = watermarkSection["Position"] ?? "bottom-right",
                Size = watermarkSection["Size"] ?? "small",
                CostCredits = ParsePositiveInt(watermarkSection["CostCredits"], 1),
                ApplyToImages = ParseBool(watermarkSection["ApplyToImages"], true),
                ApplyToVideos = ParseBool(watermarkSection["ApplyToVideos"], true),
                PreviewImageUrl = watermarkSection["PreviewImageUrl"] ?? string.Empty,
                PreviewVideoFrameUrl = watermarkSection["PreviewVideoFrameUrl"] ?? string.Empty,
                FfmpegPath = watermarkSection["FfmpegPath"] ?? "ffmpeg"
            }
        };

        ValidateQueueConfiguration(options);
        ValidateProductionProviderConfiguration(options, services, environment, configuredStorageProvider, configuredAiProvider);
        var resolvedSchedulerComponent = ResolveSchedulerComponent(schedulerComponent, options);

        services.AddSingleton(options);
        services.AddSingleton(mediaReadUrlSigningOptions);
        services.AddSingleton<ITemplateMediaReadUrlSigner, TemplateMediaReadUrlSigner>();
        services.AddSingleton(new TemplateSchedulerConfigComponent(resolvedSchedulerComponent));
        services.AddSingleton<TemplateSchedulerConfigRuntimeState>();
        services.AddSingleton<TemplateGenerationWorkerRuntimeState>();
        services.AddHostedService<TemplateSchedulerConfigStartupService>();
        services.AddSingleton<TemplateWatermarkSettingsStore>();
        services.AddDbContextPool<TemplatesDbContext>(dbOptions =>
        {
            dbOptions.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });
        services.AddTemplateGenerationControlFoundation(
            string.Equals(
                resolvedSchedulerComponent,
                TemplateSchedulerConfigFingerprint.ApiComponent,
                StringComparison.Ordinal),
            options.GenerationSchedulerV2Enabled);
        services.AddSingleton<ITemplateMediaUploadPolicy, ConfiguredTemplateMediaUploadPolicy>();
        services.AddSingleton<IMediaMetadataReader, FileMediaMetadataReader>();
        services.AddSingleton<ITemplateWatermarkRenderer, TemplateWatermarkRenderer>();
        AddMediaStorage(services, options);
        AddGenerationBilling(services, environment);
        services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
        services.AddHttpClient(TemplateContentHealthCheck.HttpClientName, client =>
        {
            ConfigureExternalHttpClient(client);
            client.Timeout = TimeSpan.FromSeconds(5);
        })
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false
            });
        services.AddHttpClient(HttpGeneratedMediaImporter.HttpClientName, ConfigureExternalHttpClient)
            .ConfigurePrimaryHttpMessageHandler(GeneratedMediaHttpMessageHandler.Create);
        services.AddScoped<ITemplateAiProviderHealthService, FalProviderHealthService>();
        services.AddScoped<ITemplatePushTokenService, TemplatePushTokenService>();
        services.AddHttpClient(TemplateLocalizationTranslator.HttpClientName, ConfigureExternalHttpClient)
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false
            });
        services.AddHttpClient<FcmTemplateGenerationPushNotificationSender>(ConfigureExternalHttpClient)
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false
            });
        services.AddScoped<ITemplateGenerationPushDeliverySender>(serviceProvider =>
            serviceProvider.GetRequiredService<FcmTemplateGenerationPushNotificationSender>());
        services.AddScoped<ITemplateGenerationPushNotificationSender, TemplateGenerationPushNotificationOutbox>();
        services.AddScoped<TemplatePushOutboxProcessor>();
        services.AddScoped<TemplateAdminAuditOutboxProcessor>();
        services.AddScoped<ITemplateMediaLifecycleService, TemplateMediaLifecycleService>();
        services.AddScoped<ITemplateVisibilityPolicy, TemplateVisibilityPolicy>();
        services.AddScoped<ITemplatesService, TemplatesService>();
        services.AddScoped<IPetsService, PetsService>();
        services.AddScoped<IFeedbackService, FeedbackService>();
        services.AddScoped<IAdminUserTemplateAnalyticsReader, AdminUserTemplateAnalyticsReader>();
        services.AddScoped<TemplateGenerationService>();
        services.AddScoped<ITemplateGenerationService>(serviceProvider =>
            serviceProvider.GetRequiredService<TemplateGenerationService>());
        services.AddScoped<ITemplateGenerationGamificationReconciliationService>(serviceProvider =>
            serviceProvider.GetRequiredService<TemplateGenerationService>());
        services.AddScoped<ITemplateGenerationQaFixtureService, TemplateGenerationQaFixtureService>();
        services.AddScoped<IImagePreviewGenerator, ImagePreviewGenerator>();
        services.AddScoped<IVideoThumbnailGenerator, VideoThumbnailGenerator>();
        services.AddScoped<TemplateMediaCleanupProcessor>();
        AddGenerationProviderPipelineServices(services, options);
        services.AddScoped<ITemplateGenerationProviderCallbackService, TemplateGenerationProviderCallbackService>();
        if (options.GenerationWorkerEnabled)
        {
            services.AddHostedService<TemplateGenerationWorker>();
        }

        if (options.FirebasePush.IsConfigured
            && string.Equals(
                resolvedSchedulerComponent,
                TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
                StringComparison.Ordinal))
        {
            services.AddHostedService<TemplatePushOutboxWorker>();
        }

        if (string.Equals(
                resolvedSchedulerComponent,
                TemplateSchedulerConfigFingerprint.ApiComponent,
                StringComparison.Ordinal)
            && services.Any(descriptor => descriptor.ServiceType == typeof(IAdminAuditLog)))
        {
            services.AddHostedService<TemplateAdminAuditOutboxWorker>();
        }

        if (options.MediaCleanupWorkerEnabled)
        {
            services.AddHostedService<TemplateMediaCleanupWorker>();
        }

        if (options.TemplateOfTheDayAutoPickWorkerEnabled)
        {
            services.AddHostedService<TemplateOfTheDayAutoPickWorker>();
        }

        return services;
    }

    private static string ResolveSchedulerComponent(string? schedulerComponent, TemplatesOptions options)
    {
        if (!string.IsNullOrWhiteSpace(schedulerComponent))
        {
            var normalized = schedulerComponent.Trim().ToLowerInvariant();
            if (normalized is TemplateSchedulerConfigFingerprint.ApiComponent
                or TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            {
                return normalized;
            }

            throw new InvalidOperationException(
                $"Unsupported template scheduler config component '{schedulerComponent}'.");
        }

        return options.GenerationWorkerEnabled
            ? TemplateSchedulerConfigFingerprint.GenerationWorkerComponent
            : TemplateSchedulerConfigFingerprint.ApiComponent;
    }

    private static void AddGenerationProviderPipelineServices(IServiceCollection services, TemplatesOptions options)
    {
        AddAiProviders(services, options);
        AddGeneratedMediaImporter(services, options);
        services.AddScoped<TemplateAiProviderRateLimiter>();
        services.AddScoped<TemplateGenerationJobProcessor>();
    }

    public static async Task EnsureTemplatesSeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var options = scope.ServiceProvider.GetRequiredService<TemplatesOptions>();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var httpClientFactory = scope.ServiceProvider.GetRequiredService<IHttpClientFactory>();

        await dbContext.Database.MigrateAsync();
        await SyncWatermarkSettingsStoreAsync(scope.ServiceProvider, dbContext, options, cancellationToken: default);
        await BackfillTemplateLocalizationsAsync(dbContext, options, httpClientFactory, cancellationToken: default);

        if (options.SeedSampleTemplates)
        {
            throw new InvalidOperationException("Sample template seed data has been removed. Create template catalog entries through the admin API.");
        }
    }

    private static async Task SyncWatermarkSettingsStoreAsync(
        IServiceProvider serviceProvider,
        TemplatesDbContext dbContext,
        TemplatesOptions options,
        CancellationToken cancellationToken)
    {
        var store = serviceProvider.GetRequiredService<TemplateWatermarkSettingsStore>();
        var persisted = await dbContext.TemplateWatermarkSettings
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        if (persisted is not null)
        {
            store.Replace(new AdminWatermarkSettingsResponse(
                persisted.Enabled,
                persisted.Text,
                persisted.LogoUrl,
                persisted.Opacity,
                persisted.Position,
                persisted.Size,
                persisted.CostCredits,
                persisted.ApplyToImages,
                persisted.ApplyToVideos,
                persisted.PreviewImageUrl,
                persisted.PreviewVideoFrameUrl));
            return;
        }

        var current = store.Current;
        dbContext.TemplateWatermarkSettings.Add(new TemplateWatermarkSettings
        {
            Id = Guid.NewGuid(),
            Enabled = current.Enabled,
            Text = current.Text,
            LogoUrl = current.LogoUrl,
            Opacity = current.Opacity,
            Position = current.Position,
            Size = current.Size,
            CostCredits = current.CostCredits,
            ApplyToImages = current.ApplyToImages,
            ApplyToVideos = current.ApplyToVideos,
            PreviewImageUrl = current.PreviewImageUrl,
            PreviewVideoFrameUrl = current.PreviewVideoFrameUrl,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static async Task BackfillTemplateLocalizationsAsync(
        TemplatesDbContext dbContext,
        TemplatesOptions options,
        IHttpClientFactory httpClientFactory,
        CancellationToken cancellationToken)
    {
        if (!options.LocalizationBackfillEnabled)
        {
            return;
        }

        var templates = await dbContext.TemplateItems
            .Where(template => template.DeletedAtUtc == null && string.IsNullOrWhiteSpace(template.LocalizedTextsJson))
            .ToArrayAsync(cancellationToken);

        if (templates.Length == 0)
        {
            return;
        }

        foreach (var template in templates)
        {
            var petPhotoRequirements = DeserializeRequirements(template.PetPhotoRequirements);
            template.LocalizedTextsJson = await TemplateLocalizationTranslator.GenerateAsync(
                template.Title,
                template.ShortDescription,
                petPhotoRequirements,
                template.ImagePrompt,
                template.PreprocessingPrompt,
                template.KlingPrompt,
                options.SupportedLocalizationLocales,
                options.SourceLocalizationLocale,
                httpClientFactory.CreateClient(TemplateLocalizationTranslator.HttpClientName),
                cancellationToken);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static string[] ReadValues(IConfigurationSection section, string key, string[] fallback)
    {
        var values = section.GetSection(key)
            .GetChildren()
            .Select(x => x.Value)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Cast<string>()
            .ToArray();

        return values.Length == 0 ? fallback : values;
    }

    private static string[]? DeserializeRequirements(string? requirements)
    {
        if (string.IsNullOrWhiteSpace(requirements))
        {
            return null;
        }

        return requirements
            .Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(value => value.Trim())
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(6)
            .ToArray();
    }

    private static void AddMediaStorage(IServiceCollection services, TemplatesOptions options)
    {
        if (IsProvider(options.StorageProvider, TemplateStorageProviders.R2))
        {
            if (!options.R2.IsConfigured)
            {
                throw new InvalidOperationException("R2 media storage is selected but R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET_NAME or R2_PUBLIC_URL is missing.");
            }

            services.AddSingleton<IAmazonS3>(_ => CreateR2Client(options.R2));
            services.AddSingleton<IMediaStorage, R2MediaStorage>();
            return;
        }

        if (IsProvider(options.StorageProvider, TemplateStorageProviders.Local))
        {
            services.AddSingleton<IMediaStorage, LocalFileMediaStorage>();
            return;
        }

        throw new InvalidOperationException($"Unsupported templates storage provider '{options.StorageProvider}'.");
    }

    private static void AddAiProviders(IServiceCollection services, TemplatesOptions options)
    {
        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal))
        {
            if (!options.Fal.IsConfigured)
            {
                throw new InvalidOperationException("FAL AI provider is selected but FAL_AI_API_KEY is missing.");
            }

            services.AddHttpClient(FalQueueClient.HttpClientName, client =>
                client.Timeout = TimeSpan.FromSeconds(Math.Max(30, options.Fal.StartTimeoutSeconds + 30)))
                .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
                {
                    AllowAutoRedirect = false
                });
            services.AddScoped<FalQueueClient>();
            services.AddScoped<IImagePreprocessor, FalImagePreprocessor>();
            services.AddScoped<IImageGenerator, FalImageGenerator>();
            services.AddScoped<IVideoMotionGenerator, FalVideoMotionGenerator>();
            return;
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fake))
        {
            services.AddSingleton<IImagePreprocessor, FakeImagePreprocessor>();
            services.AddSingleton<IImageGenerator, FakeImageGenerator>();
            services.AddSingleton<IVideoMotionGenerator, FakeVideoMotionGenerator>();
            return;
        }

        throw new InvalidOperationException($"Unsupported templates AI provider '{options.AiProvider}'.");
    }

    private static void AddGeneratedMediaImporter(IServiceCollection services, TemplatesOptions options)
    {
        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal))
        {
            services.AddSingleton<IGeneratedMediaImporter, HttpGeneratedMediaImporter>();
            return;
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fake))
        {
            services.AddSingleton<IGeneratedMediaImporter, FakeGeneratedMediaImporter>();
            return;
        }

        throw new InvalidOperationException($"Unsupported templates AI provider '{options.AiProvider}'.");
    }

    private static void ConfigureExternalHttpClient(HttpClient client) =>
        client.Timeout = ExternalHttpClientTimeout;

    private static void AddGenerationBilling(IServiceCollection services, IHostEnvironment? environment)
    {
        if (services.Any(descriptor => descriptor.ServiceType == typeof(IEconomyService)))
        {
            services.AddScoped<ITemplateGenerationBilling, EconomyTemplateGenerationBilling>();
            services.AddScoped<IGenerationBillingReconciliationService, TemplateGenerationBillingReconciliationService>();
            return;
        }

        if (environment is not null && environment.IsProduction())
        {
            throw new InvalidOperationException("Economy-backed template generation billing must be registered in Production.");
        }

        services.AddScoped<ITemplateGenerationBilling, NoopTemplateGenerationBilling>();
    }

    private static void ValidateProductionProviderConfiguration(
        TemplatesOptions options,
        IServiceCollection services,
        IHostEnvironment? environment,
        string? configuredStorageProvider,
        string? configuredAiProvider)
    {
        if (environment is null || !environment.IsProduction())
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(configuredStorageProvider))
        {
            throw new InvalidOperationException("Templates:StorageProvider or TEMPLATES_STORAGE_PROVIDER must be explicitly set in Production.");
        }

        if (string.IsNullOrWhiteSpace(configuredAiProvider))
        {
            throw new InvalidOperationException("Templates:AiProvider or TEMPLATES_AI_PROVIDER must be explicitly set in Production.");
        }

        if (IsProvider(options.StorageProvider, TemplateStorageProviders.Local))
        {
            throw new InvalidOperationException("Local templates media storage cannot be used in Production.");
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fake))
        {
            throw new InvalidOperationException("Fake templates AI provider cannot be used in Production.");
        }

        if (options.SeedSampleTemplates)
        {
            throw new InvalidOperationException("Sample template seed data cannot be enabled in Production.");
        }

        if (options.QaFixturesEnabled)
        {
            throw new InvalidOperationException("Template QA fixtures cannot be enabled in Production.");
        }

        ValidateProductionPublicBaseUrl(options.PublicBaseUrl, "Templates:PublicBaseUrl");

        if (IsProvider(options.StorageProvider, TemplateStorageProviders.R2) && !options.R2.IsConfigured)
        {
            throw new InvalidOperationException("R2 media storage is selected but R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET_NAME or R2_PUBLIC_URL is missing.");
        }

        if (IsProvider(options.StorageProvider, TemplateStorageProviders.R2))
        {
            ValidateProductionPublicBaseUrl(options.R2.PublicBaseUrl, "Templates:R2:PublicBaseUrl");
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal) && !options.Fal.IsConfigured)
        {
            throw new InvalidOperationException("FAL AI provider is selected but FAL_AI_API_KEY is missing.");
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal))
        {
            ValidateProductionPublicBaseUrl(options.Fal.QueueBaseUrl, "Templates:Fal:QueueBaseUrl");
            if (!string.IsNullOrWhiteSpace(options.Fal.WebhookUrl))
            {
                ValidateProductionPublicBaseUrl(options.Fal.WebhookUrl, "Templates:Fal:WebhookUrl");
            }
        }

        if (options.FirebasePush.Enabled && !options.FirebasePush.IsConfigured)
        {
            throw new InvalidOperationException(
                "Templates Firebase push is enabled but Firebase project id or service account configuration is missing.");
        }

        if (options.FirebasePush.Enabled
            && !FirebaseProjectIdPolicy.IsSafeProjectId(options.FirebasePush.ProjectId))
        {
            throw new InvalidOperationException(
                "Templates:FirebasePush:ProjectId must be a Firebase project id, not a URL or path, in Production.");
        }

        if (!services.Any(descriptor => descriptor.ServiceType == typeof(IEconomyService)))
        {
            throw new InvalidOperationException("Economy-backed template generation billing must be registered in Production.");
        }
    }

    private static void ValidateProductionPublicBaseUrl(string? baseUrl, string settingName)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new InvalidOperationException($"{settingName} must be configured in Production.");
        }

        if (ContainsPlaceholder(baseUrl))
        {
            throw new InvalidOperationException($"{settingName} contains a placeholder value and must be replaced in Production.");
        }

        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"{settingName} must be an absolute URL in Production.");
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"{settingName} must use HTTPS in Production.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo)
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment))
        {
            throw new InvalidOperationException($"{settingName} must not contain credentials, query strings, or fragments in Production.");
        }

        if (SafeNetworkTargetPolicy.IsPrivateNetworkTarget(uri))
        {
            throw new InvalidOperationException($"{settingName} must not point to a local or private network host in Production.");
        }
    }

    private static void ValidateQueueConfiguration(TemplatesOptions options)
    {
        var imageReserved = ResolveImageReservedConcurrency(options);
        var imageProtected = ResolveImageProtectedConcurrency(options);
        var videoReserved = ResolveVideoReservedConcurrency(options);

        if (options.GlobalMaxConcurrentGenerations <= 0
            || options.ImageMaxConcurrentGenerations <= 0
            || options.VideoMaxConcurrentGenerations <= 0
            || imageReserved <= 0
            || imageProtected <= 0
            || videoReserved <= 0)
        {
            throw new InvalidOperationException("Template generation queue concurrency limits must be positive.");
        }

        if (options.ImageMaxConcurrentGenerations > options.GlobalMaxConcurrentGenerations
            || options.VideoMaxConcurrentGenerations > options.GlobalMaxConcurrentGenerations)
        {
            throw new InvalidOperationException("Template generation media concurrency limits cannot exceed the global generation concurrency limit.");
        }

        if (imageReserved > options.ImageMaxConcurrentGenerations
            || imageProtected > options.ImageMaxConcurrentGenerations
            || videoReserved > options.VideoMaxConcurrentGenerations)
        {
            throw new InvalidOperationException("Template generation reserved/protected media concurrency limits cannot exceed their media hard limits.");
        }

        if (options.EnableElasticLaneBorrowing
            && options.VideoBorrowMaxConcurrentGenerations <= 0)
        {
            throw new InvalidOperationException("VideoBorrowMaxConcurrentGenerations must be positive when elastic lane borrowing is enabled.");
        }

        if (options.VideoReservedConcurrentGenerations > 0
            && options.VideoBorrowMaxConcurrentGenerations > 0
            && videoReserved + options.VideoBorrowMaxConcurrentGenerations < options.VideoMaxConcurrentGenerations)
        {
            throw new InvalidOperationException("Video reserved plus borrow max must cover VideoMaxConcurrentGenerations when both are explicitly configured.");
        }

        if (!string.Equals(options.VideoBorrowReleaseMode, "natural_completion", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("VideoBorrowReleaseMode currently supports only natural_completion.");
        }

        if (options.FalProviderConcurrencyLimit > 0
            && options.FalProviderReservedConcurrency >= options.FalProviderConcurrencyLimit)
        {
            throw new InvalidOperationException("FAL provider reserved concurrency must be lower than the configured provider concurrency limit.");
        }

        if (options.FalProviderBalanceCriticalThresholdUsd > options.FalProviderBalanceLowThresholdUsd)
        {
            throw new InvalidOperationException("FAL provider critical balance threshold cannot exceed the low balance threshold.");
        }

        if (options.FreeQueuePriorityScore <= 0
            || options.PremiumQueuePriorityScore <= options.FreeQueuePriorityScore
            || options.PrivilegedQueuePriorityScore <= options.PremiumQueuePriorityScore
            || options.AdminQueuePriorityScore < options.PrivilegedQueuePriorityScore)
        {
            throw new InvalidOperationException("Template generation queue priority scores must be positive and ordered Free < Premium < Privileged <= Admin.");
        }

        if (options.QueuePriorityAgingIntervalSeconds <= 0 || options.QueuePriorityAgingBoost <= 0)
        {
            throw new InvalidOperationException("Queue priority aging interval and boost must be positive.");
        }

        if (options.RealtimeEventRetentionMinutes <= 0
            || options.RealtimeEventCleanupIntervalMinutes <= 0
            || options.RealtimeEventCleanupBatchSize <= 0)
        {
            throw new InvalidOperationException("Template realtime event retention and cleanup settings must be positive.");
        }

        if (options.MediaImportMaxAttempts <= 0 || options.MediaImportRetryBaseDelaySeconds <= 0)
        {
            throw new InvalidOperationException("Template media import retry settings must be positive.");
        }

        if (options.FreeImageMaxEstimatedWaitSeconds <= 0
            || options.PremiumImageMaxEstimatedWaitSeconds <= 0
            || options.PrivilegedImageMaxEstimatedWaitSeconds <= 0
            || options.FreeVideoMaxEstimatedWaitSeconds <= 0
            || options.PremiumVideoMaxEstimatedWaitSeconds <= 0
            || options.PrivilegedVideoMaxEstimatedWaitSeconds <= 0)
        {
            throw new InvalidOperationException("Template generation max estimated wait settings must be positive.");
        }

        if (options.FreeImageMaxEstimatedWaitSeconds < options.PremiumImageMaxEstimatedWaitSeconds
            || options.PremiumImageMaxEstimatedWaitSeconds < options.PrivilegedImageMaxEstimatedWaitSeconds
            || options.FreeVideoMaxEstimatedWaitSeconds < options.PremiumVideoMaxEstimatedWaitSeconds
            || options.PremiumVideoMaxEstimatedWaitSeconds < options.PrivilegedVideoMaxEstimatedWaitSeconds)
        {
            throw new InvalidOperationException("Template generation max estimated wait settings must be ordered Privileged <= Premium <= Free for each media type.");
        }
    }

    private static int ResolveImageReservedConcurrency(TemplatesOptions options)
    {
        return options.ImageReservedConcurrentGenerations > 0
            ? options.ImageReservedConcurrentGenerations
            : options.ImageMaxConcurrentGenerations;
    }

    private static int ResolveImageProtectedConcurrency(TemplatesOptions options)
    {
        return options.ImageProtectedConcurrentGenerations > 0
            ? options.ImageProtectedConcurrentGenerations
            : ResolveImageReservedConcurrency(options);
    }

    private static int ResolveVideoReservedConcurrency(TemplatesOptions options)
    {
        return options.VideoReservedConcurrentGenerations > 0
            ? options.VideoReservedConcurrentGenerations
            : options.VideoMaxConcurrentGenerations;
    }

    private static IAmazonS3 CreateR2Client(R2StorageOptions options)
    {
        var credentials = new BasicAWSCredentials(options.AccessKey, options.SecretKey);
        return new AmazonS3Client(credentials, new AmazonS3Config
        {
            ServiceURL = $"https://{options.AccountId}.r2.cloudflarestorage.com",
            AuthenticationRegion = "auto",
            ForcePathStyle = true
        });
    }

    private static bool IsProvider(string configuredProvider, string expectedProvider)
    {
        return string.Equals(configuredProvider, expectedProvider, StringComparison.OrdinalIgnoreCase);
    }

    private static bool ContainsPlaceholder(string value) =>
        value.Contains("CHANGE_ME", StringComparison.OrdinalIgnoreCase)
        || value.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase)
        || value.Contains("YOUR_", StringComparison.OrdinalIgnoreCase)
        || value.Contains("<", StringComparison.Ordinal)
        || value.Contains(">", StringComparison.Ordinal);

    private static bool HasR2Environment()
    {
        return !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("R2_ACCOUNT_ID"))
            || !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("R2_BUCKET_NAME"));
    }

    private static bool HasFalEnvironment()
    {
        return !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("FAL_AI_API_KEY"));
    }

    private static string? ReadValue(IConfigurationSection section, string key, string environmentVariable)
    {
        var value = section[key];
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        value = Environment.GetEnvironmentVariable(environmentVariable);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static bool ParseBool(string? raw, bool fallback)
    {
        return bool.TryParse(raw, out var parsed) ? parsed : fallback;
    }

    private static long ParseLong(string? raw, long fallback)
    {
        return long.TryParse(raw, out var parsed) ? parsed : fallback;
    }

    private static int ParseInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var parsed) ? parsed : fallback;
    }

    private static int ParsePositiveInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var parsed) && parsed > 0 ? parsed : fallback;
    }

    private static double ParseDouble(string? raw, double fallback, double min, double max)
    {
        if (!double.TryParse(raw, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out var value))
        {
            return fallback;
        }

        return Math.Clamp(value, min, max);
    }

    private static int ParseNonNegativeInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var parsed) && parsed >= 0 ? parsed : fallback;
    }

    private static decimal ParseNonNegativeDecimal(string? raw, decimal fallback)
    {
        return decimal.TryParse(raw, System.Globalization.NumberStyles.Number, System.Globalization.CultureInfo.InvariantCulture, out var parsed)
            && parsed >= 0
            ? parsed
            : fallback;
    }
}
