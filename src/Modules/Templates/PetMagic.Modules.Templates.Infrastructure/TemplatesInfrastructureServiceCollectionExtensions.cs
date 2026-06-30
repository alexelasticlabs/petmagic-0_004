using Amazon.Runtime;
using Amazon.S3;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

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

    public static IServiceCollection AddTemplatesInfrastructure(this IServiceCollection services, IConfiguration configuration, IHostEnvironment? environment = null)
    {
        services.AddMemoryCache();

        var section = configuration.GetSection(TemplatesOptions.SectionName);
        var r2Section = section.GetSection("R2");
        var falSection = section.GetSection("Fal");
        var firebasePushSection = section.GetSection("FirebasePush");
        var watermarkSection = section.GetSection("Watermark");
        var configuredStorageProvider = ReadValue(section, "StorageProvider", "TEMPLATES_STORAGE_PROVIDER");
        var configuredAiProvider = ReadValue(section, "AiProvider", "TEMPLATES_AI_PROVIDER");
        var options = new TemplatesOptions
        {
            StorageProvider = configuredStorageProvider
                ?? (HasR2Environment() ? TemplateStorageProviders.R2 : TemplateStorageProviders.Local),
            AiProvider = configuredAiProvider
                ?? (HasFalEnvironment() ? TemplateAiProviders.Fal : TemplateAiProviders.Fake),
            PublicBaseUrl = section["PublicBaseUrl"] ?? "http://localhost:5000",
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
            PreviewMaxFileSizeBytes = ParseLong(section["PreviewMaxFileSizeBytes"], 25 * 1024 * 1024),
            ReferenceMotionMaxFileSizeBytes = ParseLong(section["ReferenceMotionMaxFileSizeBytes"], 100 * 1024 * 1024),
            SeedSampleTemplates = ParseBool(section["SeedSampleTemplates"], false),
            GenerationWorkerEnabled = ParseBool(section["GenerationWorkerEnabled"], true),
            GenerationWorkerPollIntervalMilliseconds = ParseInt(section["GenerationWorkerPollIntervalMilliseconds"], 1_000),
            MaxConcurrentJobsPerWorker = ParsePositiveInt(section["MaxConcurrentJobsPerWorker"], 1),
            GlobalMaxConcurrentGenerations = ParsePositiveInt(section["GlobalMaxConcurrentGenerations"], 3),
            MaxAiProviderRequestsPerMinute = ParseNonNegativeInt(section["MaxAiProviderRequestsPerMinute"], 60),
            QueueMaxSize = ParseNonNegativeInt(section["QueueMaxSize"], 1_000),
            EstimatedVideoGenerationSeconds = ParsePositiveInt(section["EstimatedVideoGenerationSeconds"], 120),
            EstimatedImageGenerationSeconds = ParsePositiveInt(section["EstimatedImageGenerationSeconds"], 60),
            FreeUserMaxActiveGenerations = ParsePositiveInt(section["FreeUserMaxActiveGenerations"], 1),
            PremiumUserMaxActiveGenerations = ParsePositiveInt(section["PremiumUserMaxActiveGenerations"], 3),
            PrivilegedUserMaxActiveGenerations = ParsePositiveInt(section["PrivilegedUserMaxActiveGenerations"], 10),
            JobLockTimeoutMilliseconds = ParsePositiveInt(
                section["JobLockTimeoutMilliseconds"] ?? section["StaleProcessingRecoveryDelayMilliseconds"],
                900_000),
            StaleProcessingRecoveryDelayMilliseconds = ParsePositiveInt(section["StaleProcessingRecoveryDelayMilliseconds"], 900_000),
            MaxGenerationAttempts = ParsePositiveInt(section["MaxGenerationAttempts"], 3),
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
                StartTimeoutSeconds = ParseInt(falSection["StartTimeoutSeconds"], 120),
                PollIntervalMilliseconds = ParseInt(falSection["PollIntervalMilliseconds"], 2_000),
                MaxPollingAttempts = ParseInt(falSection["MaxPollingAttempts"], 180)
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

        ValidateProductionProviderConfiguration(options, services, environment, configuredStorageProvider, configuredAiProvider);

        services.AddSingleton(options);
        services.AddSingleton<TemplateWatermarkSettingsStore>();
        services.AddDbContextPool<TemplatesDbContext>(dbOptions =>
        {
            dbOptions.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });
        services.AddSingleton<ITemplateMediaUploadPolicy, ConfiguredTemplateMediaUploadPolicy>();
        services.AddSingleton<IMediaMetadataReader, FileMediaMetadataReader>();
        services.AddSingleton<ITemplateWatermarkRenderer, TemplateWatermarkRenderer>();
        AddMediaStorage(services, options);
        AddGenerationBilling(services, environment);
        services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
        services.AddScoped<ITemplatePushTokenService, TemplatePushTokenService>();
        services.AddHttpClient(TemplateLocalizationTranslator.HttpClientName, ConfigureExternalHttpClient);
        services.AddScoped<NoopTemplateGenerationPushNotificationSender>();
        services.AddHttpClient<FcmTemplateGenerationPushNotificationSender>(ConfigureExternalHttpClient);
        services.AddScoped<ITemplateGenerationPushNotificationSender>(serviceProvider =>
        {
            var pushOptions = serviceProvider.GetRequiredService<TemplatesOptions>().FirebasePush;
            return pushOptions.IsConfigured
                ? serviceProvider.GetRequiredService<FcmTemplateGenerationPushNotificationSender>()
                : serviceProvider.GetRequiredService<NoopTemplateGenerationPushNotificationSender>();
        });
        services.AddScoped<ITemplateMediaLifecycleService, TemplateMediaLifecycleService>();
        services.AddScoped<ITemplatesService, TemplatesService>();
        services.AddScoped<IPetsService, PetsService>();
        services.AddScoped<IFeedbackService, FeedbackService>();
        services.AddScoped<IAdminUserTemplateAnalyticsReader, AdminUserTemplateAnalyticsReader>();
        services.AddScoped<ITemplateGenerationService, TemplateGenerationService>();
        services.AddScoped<IImagePreviewGenerator, ImagePreviewGenerator>();
        services.AddScoped<TemplateMediaCleanupProcessor>();
        if (options.GenerationWorkerEnabled)
        {
            AddGenerationWorkerServices(services, options);
            services.AddHostedService<TemplateGenerationWorker>();
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

    private static void AddGenerationWorkerServices(IServiceCollection services, TemplatesOptions options)
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
                client.Timeout = TimeSpan.FromSeconds(Math.Max(30, options.Fal.StartTimeoutSeconds + 30)));
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
            services.AddHttpClient(HttpGeneratedMediaImporter.HttpClientName, ConfigureExternalHttpClient);
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

        if (IsProvider(options.StorageProvider, TemplateStorageProviders.R2) && !options.R2.IsConfigured)
        {
            throw new InvalidOperationException("R2 media storage is selected but R2_ACCOUNT_ID, R2_ACCESS_KEY, R2_SECRET_KEY, R2_BUCKET_NAME or R2_PUBLIC_URL is missing.");
        }

        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal) && !options.Fal.IsConfigured)
        {
            throw new InvalidOperationException("FAL AI provider is selected but FAL_AI_API_KEY is missing.");
        }

        if (!services.Any(descriptor => descriptor.ServiceType == typeof(IEconomyService)))
        {
            throw new InvalidOperationException("Economy-backed template generation billing must be registered in Production.");
        }
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
}
