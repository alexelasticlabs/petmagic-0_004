using Amazon.Runtime;
using Amazon.S3;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class TemplatesInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddTemplatesInfrastructure(this IServiceCollection services, IConfiguration configuration, IHostEnvironment? environment = null)
    {
        var section = configuration.GetSection(TemplatesOptions.SectionName);
        var r2Section = section.GetSection("R2");
        var falSection = section.GetSection("Fal");
        var firebasePushSection = section.GetSection("FirebasePush");
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
            SeedSampleTemplates = ParseBool(section["SeedSampleTemplates"], true),
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
            }
        };

        ValidateProductionProviderConfiguration(options, services, environment, configuredStorageProvider, configuredAiProvider);

        services.AddSingleton(options);
        services.AddDbContext<TemplatesDbContext>(dbOptions =>
        {
            dbOptions.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });
        services.AddSingleton<ITemplateMediaUploadPolicy, ConfiguredTemplateMediaUploadPolicy>();
        services.AddSingleton<IMediaMetadataReader, FileMediaMetadataReader>();
        AddMediaStorage(services, options);
        AddGenerationBilling(services);
        services.AddSingleton<ITemplateFeedRealtimeService, TemplateFeedRealtimeService>();
        services.AddScoped<ITemplatePushTokenService, TemplatePushTokenService>();
        services.AddHttpClient(TemplateLocalizationTranslator.HttpClientName);
        services.AddScoped<NoopTemplateGenerationPushNotificationSender>();
        services.AddHttpClient<FcmTemplateGenerationPushNotificationSender>();
        services.AddScoped<ITemplateGenerationPushNotificationSender>(serviceProvider =>
        {
            var pushOptions = serviceProvider.GetRequiredService<TemplatesOptions>().FirebasePush;
            return pushOptions.IsConfigured
                ? serviceProvider.GetRequiredService<FcmTemplateGenerationPushNotificationSender>()
                : serviceProvider.GetRequiredService<NoopTemplateGenerationPushNotificationSender>();
        });
        services.AddScoped<ITemplateMediaLifecycleService, TemplateMediaLifecycleService>();
        services.AddScoped<ITemplatesService, TemplatesService>();
        services.AddScoped<IAdminUserTemplateAnalyticsReader, AdminUserTemplateAnalyticsReader>();
        services.AddScoped<ITemplateGenerationService, TemplateGenerationService>();
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
        // Guard against environments where migration history drift left the column missing.
        await dbContext.Database.ExecuteSqlRawAsync(
            """
            ALTER TABLE templates_items
            ADD COLUMN IF NOT EXISTS "PetPhotoRequirements" character varying(1000);
            """);

        await dbContext.Database.ExecuteSqlRawAsync(
            """
            ALTER TABLE templates_items
            ADD COLUMN IF NOT EXISTS "LocalizedTextsJson" text;
            """);

        await dbContext.Database.ExecuteSqlRawAsync(
            """
            ALTER TABLE templates_items
            ALTER COLUMN "LocalizedTextsJson" TYPE text USING "LocalizedTextsJson"::text;
            """);

        await BackfillTemplateLocalizationsAsync(dbContext, options, httpClientFactory, cancellationToken: default);

        if (!options.SeedSampleTemplates)
        {
            return;
        }

        // Idempotent patch: backfill MusicDescription on the seed video template if it was seeded before this field was populated.
        var seedVideoTemplateId = Guid.Parse("39C5F7A0-74AE-4DE6-84F4-82B842D63FA0");
        await dbContext.TemplateItems
            .Where(x => x.Id == seedVideoTemplateId && x.MusicDescription == null)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.MusicDescription, "Upbeat meme dance track"));

        if (await dbContext.TemplateItems.AnyAsync())
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.TemplateCategories.AddRange(
            new TemplateCategory
            {
                Id = Guid.Parse("667D3514-6549-4B18-8427-A0F08503BA91"),
                Name = "Portrait",
                NormalizedName = "PORTRAIT",
                IsArchived = false,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new TemplateCategory
            {
                Id = Guid.Parse("A5B2B18A-5093-4144-9489-947F1690E998"),
                Name = "Dance",
                NormalizedName = "DANCE",
                IsArchived = false,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            }
        );

        dbContext.TemplateItems.AddRange(
            new TemplateItem
            {
                Id = Guid.Parse("9CA5BE83-5919-491E-95FE-8AB5C3772232"),
                TemplateType = TemplateType.Image,
                Title = "Cozy Portrait",
                ShortDescription = "Placeholder image template card for admin and public catalog flows.",
                PetPhotoRequirements = "One pet in the photo\nClear face\nGood lighting",
                Category = "Portrait",
                Tags = "cozy,portrait",
                IsPremium = false,
                TokenCost = 20,
                Status = TemplateStatus.Active,
                ImageModel = options.AllowedImageModels[0],
                ImagePrompt = options.DefaultImagePrompt,
                Assets =
                [
                    new TemplateAsset
                    {
                        Id = Guid.Parse("5BD7DA22-FED0-4205-8230-752C81D0B415"),
                        AssetKind = TemplateAssetKind.Preview,
                        Url = "https://cdn.petmagic.dev/templates/cozy-portrait-preview.jpg",
                        FileName = "cozy-portrait-preview.jpg",
                        ContentType = "image/jpeg"
                    }
                ],
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new TemplateItem
            {
                Id = Guid.Parse("39C5F7A0-74AE-4DE6-84F4-82B842D63FA0"),
                TemplateType = TemplateType.Video,
                Title = "Viral Dance",
                ShortDescription = "Premium motion-control template stub with calculated orientation.",
                PetPhotoRequirements = "Full body visible\nPet facing camera\nNo cropped head or legs",
                Category = "Dance",
                Tags = "viral,dance",
                IsPremium = true,
                TokenCost = 60,
                Status = TemplateStatus.Active,
                MusicDescription = "Upbeat meme dance track",
                ReferenceVideoDurationSeconds = 7.5,
                CharacterOrientation = CharacterOrientation.Image,
                PreprocessingModel = options.AllowedPreprocessingModels[0],
                PreprocessingPrompt = options.DefaultPreprocessingPrompt,
                KlingModel = options.AllowedKlingModels[0],
                KlingPrompt = options.DefaultKlingPrompt,
                KeepOriginalSound = true,
                Assets =
                [
                    new TemplateAsset
                    {
                        Id = Guid.Parse("4BC4D241-31EA-434B-A557-61292B8A7BFB"),
                        AssetKind = TemplateAssetKind.Preview,
                        Url = "https://cdn.petmagic.dev/templates/viral-dance-preview.mp4",
                        FileName = "viral-dance-preview.mp4",
                        ContentType = "video/mp4",
                        DurationSeconds = 7.5
                    },
                    new TemplateAsset
                    {
                        Id = Guid.Parse("7BE8FA3A-D5B9-4C9A-A43A-C0C88FBB1FF5"),
                        AssetKind = TemplateAssetKind.ReferenceMotion,
                        Url = "https://cdn.petmagic.dev/templates/viral-dance-reference.mp4",
                        FileName = "viral-dance-reference.mp4",
                        ContentType = "video/mp4",
                        DurationSeconds = 7.5
                    }
                ],
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            }
        );

        await dbContext.SaveChangesAsync();
        await BackfillTemplateLocalizationsAsync(dbContext, options, httpClientFactory, cancellationToken: default);
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

            services.AddHttpClient(FalQueueClient.HttpClientName);
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
            services.AddHttpClient(HttpGeneratedMediaImporter.HttpClientName);
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

    private static void AddGenerationBilling(IServiceCollection services)
    {
        if (services.Any(descriptor => descriptor.ServiceType == typeof(IEconomyService)))
        {
            services.AddScoped<ITemplateGenerationBilling, EconomyTemplateGenerationBilling>();
            return;
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

    private static int ParseNonNegativeInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var parsed) && parsed >= 0 ? parsed : fallback;
    }
}
