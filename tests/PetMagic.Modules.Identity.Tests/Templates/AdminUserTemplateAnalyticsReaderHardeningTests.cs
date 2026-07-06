using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminUserTemplateAnalyticsReaderHardeningTests
{
    [Fact]
    public void AnalyticsReader_ShouldNormalizeLegacyNullGenerationAndEventStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "AdminUserTemplateAnalyticsReader.cs"));

        Assert.Contains("x.TemplateTitle ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.EventType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Source ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.DeviceClass ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CountryCode ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public async Task GetAdminUserTemplateAnalyticsAsync_ShouldSignRecentGenerationOutputUrl()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var template = CreateTemplate();
        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "templates-media/private/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "templates-media/private/result.png",
            AttemptCount = 1,
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            UpdatedAtUtc = DateTime.UtcNow,
            CompletedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var mediaStorage = new SigningMediaStorage();
        var reader = new AdminUserTemplateAnalyticsReader(dbContext, mediaStorage, CreateOptions());

        var result = await reader.GetAdminUserTemplateAnalyticsAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var generation = Assert.Single(result.Value.RecentGenerations);
        Assert.Equal("templates-media/private/result.png?signed=1", generation.OutputUrl);
        Assert.Equal(["templates-media/private/result.png"], mediaStorage.ReadUrls);
        Assert.Equal([TimeSpan.FromSeconds(900)], mediaStorage.ReadTtls);
    }

    [Fact]
    public async Task GetAdminUserTemplateAnalyticsAsync_ShouldHideRecentGenerationOutputUrl_WhenSigningFails()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var template = CreateTemplate();
        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 20,
            SourceImageUrl = "templates-media/private/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            ResultUrl = "templates-media/private/result.png",
            AttemptCount = 1,
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            UpdatedAtUtc = DateTime.UtcNow,
            CompletedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var reader = new AdminUserTemplateAnalyticsReader(dbContext, new FailingReadStorage(), CreateOptions());

        var result = await reader.GetAdminUserTemplateAnalyticsAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var generation = Assert.Single(result.Value.RecentGenerations);
        Assert.Null(generation.OutputUrl);
    }

    [Fact]
    public async Task GetAdminUserTemplateAnalyticsAsync_ShouldSanitizeRecentGenerationFailureMessage()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var template = CreateTemplate();
        const string rawProviderFailure =
            "Provider failed callbackUrl=https://provider.example.com/jobs/job-secret?token=raw-secret "
            + "requestId=req-secret apiKey=provider-key generationId=9f9dbb7a-910e-4d48-88bd-1b914ad46732";
        dbContext.TemplateItems.Add(template);
        dbContext.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = generationId,
            UserId = userId,
            TemplateId = template.Id,
            Status = TemplateGenerationStatus.Failed,
            TokenCost = 20,
            SourceImageUrl = "templates-media/private/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            LastErrorCode = TemplatesErrors.AiProviderFailed.Code,
            LastErrorMessage = rawProviderFailure,
            AttemptCount = 1,
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            QueuedAtUtc = DateTime.UtcNow.AddMinutes(-2),
            UpdatedAtUtc = DateTime.UtcNow,
            CompletedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var reader = new AdminUserTemplateAnalyticsReader(dbContext, new SigningMediaStorage(), CreateOptions());

        var result = await reader.GetAdminUserTemplateAnalyticsAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var generation = Assert.Single(result.Value.RecentGenerations);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, generation.FailureCode);
        Assert.NotNull(generation.FailureMessage);
        Assert.StartsWith("Provider failed callbackUrl=", generation.FailureMessage, StringComparison.Ordinal);
        Assert.Contains("***", generation.FailureMessage, StringComparison.Ordinal);
        Assert.True(generation.FailureMessage.Length <= 240);
        var serialized = System.Text.Json.JsonSerializer.Serialize(result.Value);
        Assert.DoesNotContain("job-secret", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("raw-secret", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("req-secret", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("provider-key", serialized, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("9f9dbb7a-910e-4d48-88bd-1b914ad46732", serialized, StringComparison.OrdinalIgnoreCase);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"admin-user-template-analytics-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
    }

    private static TemplatesOptions CreateOptions()
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"]
        };
    }

    private static TemplateItem CreateTemplate()
    {
        var now = DateTime.UtcNow;
        return new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = "Analytics Portrait",
            ShortDescription = "Analytics portrait",
            Category = "Portrait",
            Tags = "analytics",
            Status = TemplateStatus.Active,
            TokenCost = 20,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
    }

    private sealed class SigningMediaStorage : IMediaStorage
    {
        public List<string> ReadUrls { get; } = [];
        public List<TimeSpan> ReadTtls { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                $"templates-media/{asset.FileName}",
                $"templates-media/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                asset.ContentLengthBytes,
                null)));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            ReadUrls.Add(assetUrl);
            ReadTtls.Add(ttl);
            return Task.FromResult(Result.Success($"{assetUrl}?signed=1"));
        }
    }

    private sealed class FailingReadStorage : IMediaStorage
    {
        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoredMediaResponse(
                $"templates-media/{asset.FileName}",
                $"templates-media/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                asset.ContentLengthBytes,
                null)));
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
        }
    }
}
