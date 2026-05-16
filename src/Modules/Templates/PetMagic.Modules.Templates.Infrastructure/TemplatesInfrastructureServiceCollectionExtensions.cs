using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
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
        var options = new TemplatesOptions
        {
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
            SeedSampleTemplates = ParseBool(section["SeedSampleTemplates"], true)
        };

        services.AddSingleton(options);
        services.AddDbContext<TemplatesDbContext>(dbOptions =>
        {
            dbOptions.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });
        services.AddSingleton<ITemplateMediaUploadPolicy, ConfiguredTemplateMediaUploadPolicy>();
        services.AddSingleton<IMediaStorage, LocalFileMediaStorage>();
        services.AddSingleton<IMediaMetadataReader, FileMediaMetadataReader>();
        services.AddSingleton<IImagePreprocessor, FakeImagePreprocessor>();
        services.AddSingleton<IVideoMotionGenerator, FakeVideoMotionGenerator>();
        services.AddScoped<ITemplatesService, TemplatesService>();

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

    private static bool ParseBool(string? raw, bool fallback)
    {
        return bool.TryParse(raw, out var parsed) ? parsed : fallback;
    }

    private static long ParseLong(string? raw, long fallback)
    {
        return long.TryParse(raw, out var parsed) ? parsed : fallback;
    }
}
