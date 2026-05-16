using Amazon.Runtime;
using Amazon.S3;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class TemplatesInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddTemplatesInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var section = configuration.GetSection(TemplatesOptions.SectionName);
        var r2Section = section.GetSection("R2");
        var falSection = section.GetSection("Fal");
        var options = new TemplatesOptions
        {
            StorageProvider = ReadValue(section, "StorageProvider", "TEMPLATES_STORAGE_PROVIDER")
                ?? (HasR2Environment() ? TemplateStorageProviders.R2 : TemplateStorageProviders.Local),
            AiProvider = ReadValue(section, "AiProvider", "TEMPLATES_AI_PROVIDER")
                ?? (HasFalEnvironment() ? TemplateAiProviders.Fal : TemplateAiProviders.Fake),
            PublicBaseUrl = section["PublicBaseUrl"] ?? "http://localhost:5000",
            LocalMediaRootPath = section["LocalMediaRootPath"] ?? Path.Combine("wwwroot", "templates-media"),
            DefaultPreprocessingPrompt = section["DefaultPreprocessingPrompt"]
                ?? "Keep the same pet, same face, same fur, same colors, same background, same lighting and camera angle. Adjust the pet into an upright pose standing on its two hind legs like a human, with the front paws naturally positioned like arms. Make the full body clearly visible and suitable for motion transfer. Do not change the pet’s identity, breed, facial features, background, or image style.",
            DefaultKlingPrompt = section["DefaultKlingPrompt"]
                ?? "A cute pet performing a funny viral dance, smooth animation, high quality.",
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
            PreviewMaxFileSizeBytes = ParseLong(section["PreviewMaxFileSizeBytes"], 25 * 1024 * 1024),
            ReferenceMotionMaxFileSizeBytes = ParseLong(section["ReferenceMotionMaxFileSizeBytes"], 100 * 1024 * 1024),
            SeedSampleTemplates = ParseBool(section["SeedSampleTemplates"], true),
            GenerationWorkerEnabled = ParseBool(section["GenerationWorkerEnabled"], true),
            GenerationWorkerPollIntervalMilliseconds = ParseInt(section["GenerationWorkerPollIntervalMilliseconds"], 1_000),
            GeneratedVideoMaxFileSizeBytes = ParseLong(section["GeneratedVideoMaxFileSizeBytes"], 250 * 1024 * 1024),
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
            }
        };

        services.AddSingleton(options);
        services.AddDbContext<TemplatesDbContext>(dbOptions =>
        {
            dbOptions.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });
        services.AddSingleton<ITemplateMediaUploadPolicy, ConfiguredTemplateMediaUploadPolicy>();
        services.AddSingleton<IMediaMetadataReader, FileMediaMetadataReader>();
        AddMediaStorage(services, options);
        AddAiProviders(services, options);
        AddGeneratedMediaImporter(services, options);
        AddGenerationBilling(services);
        services.AddScoped<ITemplatesService, TemplatesService>();
        services.AddScoped<ITemplateGenerationService, TemplateGenerationService>();
        services.AddScoped<TemplateGenerationJobProcessor>();
        services.AddHostedService<TemplateGenerationWorker>();

        return services;
    }

    public static async Task EnsureTemplatesSeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var options = scope.ServiceProvider.GetRequiredService<TemplatesOptions>();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();

        await dbContext.Database.MigrateAsync();

        if (!options.SeedSampleTemplates)
        {
            return;
        }

        if (await dbContext.TemplateItems.AnyAsync())
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.TemplateItems.AddRange(
            new TemplateItem
            {
                Id = Guid.Parse("9CA5BE83-5919-491E-95FE-8AB5C3772232"),
                TemplateType = TemplateType.Image,
                Title = "Cozy Portrait",
                ShortDescription = "Placeholder image template card for admin and public catalog flows.",
                Category = "Portrait",
                Tags = "cozy,portrait",
                IsPremium = false,
                TokenCost = 20,
                Status = TemplateStatus.Active,
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

        services.AddSingleton<IMediaStorage, LocalFileMediaStorage>();
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
            services.AddSingleton<FalQueueClient>();
            services.AddSingleton<IImagePreprocessor, FalImagePreprocessor>();
            services.AddSingleton<IVideoMotionGenerator, FalVideoMotionGenerator>();
            return;
        }

        services.AddSingleton<IImagePreprocessor, FakeImagePreprocessor>();
        services.AddSingleton<IVideoMotionGenerator, FakeVideoMotionGenerator>();
    }

    private static void AddGeneratedMediaImporter(IServiceCollection services, TemplatesOptions options)
    {
        if (IsProvider(options.AiProvider, TemplateAiProviders.Fal))
        {
            services.AddHttpClient(HttpGeneratedMediaImporter.HttpClientName);
            services.AddSingleton<IGeneratedMediaImporter, HttpGeneratedMediaImporter>();
            return;
        }

        services.AddSingleton<IGeneratedMediaImporter, FakeGeneratedMediaImporter>();
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
}
