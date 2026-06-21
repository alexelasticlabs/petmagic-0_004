using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{

    private static TemplatesService CreateService(
        TemplatesDbContext dbContext,
        IMediaStorage? mediaStorage = null,
        ITemplateFeedRealtimeService? realtimeService = null,
        IAdminAuditLog? adminAuditLog = null,
        TemplatesOptions? templatesOptions = null)
    {
        var options = templatesOptions ?? CreateTemplatesServiceOptions();

        IMediaMetadataReader metadataReader = new TestMediaMetadataReader();
        ITemplateMediaLifecycleService lifecycleService = new TemplateMediaLifecycleService(dbContext, options);
        return new TemplatesService(
            dbContext,
            options,
            metadataReader,
            mediaStorage ?? new RecordingMediaStorage(),
            lifecycleService,
            realtimeService ?? new RecordingTemplateFeedRealtimeService(),
            adminAuditLog);
    }

    private static TemplatesOptions CreateTemplatesServiceOptions(
        string templateOfTheDayBusinessTimeZone = "UTC")
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit"
            ],
            AllowedPreprocessingModels = [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit"
            ],
            AllowedKlingModels = [
                "fal-ai/kling-video/v3/pro/motion-control",
                "fal-ai/kling-video/v3/standard/motion-control"
            ],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            SeedSampleTemplates = false,
            TemplateOfTheDayBusinessTimeZone = templateOfTheDayBusinessTimeZone
        };
    }

    private static async Task<Guid> CreateActiveImageTemplateAsync(ITemplatesService service, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                CreatePreviewAsset($"https://cdn.example.com/{slug}.jpg", $"{slug}.jpg", "image/jpeg"),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        return created.Value.TemplateId;
    }

    private static async Task<Guid> CreateActiveVideoTemplateAsync(ITemplatesService service, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var created = await service.CreateVideoAsync(
            new CreateVideoTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                30,
                TemplatePromoBadgeMode.New.ToString(),
                string.Empty,
                CreatePreviewAsset($"https://cdn.example.com/{slug}.mp4", $"{slug}.mp4", "video/mp4"),
                CreateReferenceAsset(8.0),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Smooth cinematic motion.",
                true,
                TemplateStatus.Active.ToString()),
            CancellationToken.None);

        Assert.True(created.IsSuccess);
        return created.Value.TemplateId;
    }

    private static TemplateItem CreatePublicFeedTemplate(Guid templateId, string title, DateTime updatedAtUtc, long version)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        return new TemplateItem
        {
            Id = templateId,
            Version = version,
            TemplateType = TemplateType.Image,
            Title = title,
            ShortDescription = $"{title} description",
            Category = "Portrait",
            Tags = "cursor,stable",
            IsPremium = false,
            TokenCost = 20,
            Status = TemplateStatus.Active,
            PromoBadgeMode = TemplatePromoBadgeMode.New,
            ImageModel = "openai/gpt-image-2/edit",
            ImagePrompt = "Keep the same pet.",
            CreatedAtUtc = updatedAtUtc.AddMinutes(-1),
            UpdatedAtUtc = updatedAtUtc,
            Assets =
            [
                new TemplateAsset
                {
                    Id = Guid.CreateVersion7(),
                    TemplateId = templateId,
                    AssetKind = TemplateAssetKind.Preview,
                    Url = $"https://cdn.example.com/{slug}.jpg",
                    FileName = $"{slug}.jpg",
                    ContentType = "image/jpeg",
                    FileSizeBytes = 48_000
                }
            ]
        };
    }

    private static async Task SetUpdatedAtUtcAsync(TemplatesDbContext dbContext, Guid templateId, DateTime updatedAtUtc)
    {
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        template.UpdatedAtUtc = updatedAtUtc;
        await dbContext.SaveChangesAsync();
    }

    private static TemplateGenerationService CreateGenerationService(TemplatesDbContext dbContext, TemplatesOptions? options = null)
    {
        return new TemplateGenerationService(dbContext, new PassiveGenerationBilling(), new RecordingMediaStorage(), options ?? CreateTemplatesOptions());
    }

    private static TemplatesOptions CreateTemplatesOptions(
        int queueMaxSize = 1_000,
        int globalMaxConcurrentGenerations = 3,
        int estimatedImageGenerationSeconds = 60)
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit"
            ],
            AllowedPreprocessingModels = [
                "openai/gpt-image-2/edit",
                "fal-ai/nano-banana-pro/edit"
            ],
            AllowedKlingModels = [
                "fal-ai/kling-video/v3/pro/motion-control",
                "fal-ai/kling-video/v3/standard/motion-control"
            ],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            QueueMaxSize = queueMaxSize,
            GlobalMaxConcurrentGenerations = globalMaxConcurrentGenerations,
            EstimatedImageGenerationSeconds = estimatedImageGenerationSeconds,
            SeedSampleTemplates = false
        };
    }

    private static TemplatesDbContext CreateDbContext(params IInterceptor[] interceptors)
    {
        var builder = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"templates-tests-{Guid.NewGuid():N}");
        if (interceptors.Length > 0)
        {
            builder.AddInterceptors(interceptors);
        }

        return new TemplatesDbContext(builder.Options);
    }

    private sealed class RecordingTemplateFeedRealtimeService : ITemplateFeedRealtimeService
    {
        public int InvalidatedCount { get; private set; }

        public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
        {
            var channel = Channel.CreateUnbounded<TemplateFeedRealtimeEvent>();
            return channel.Reader;
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
        {
            InvalidatedCount++;
            return ValueTask.CompletedTask;
        }

        public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
        {
            return ValueTask.CompletedTask;
        }
    }

    private sealed class RecordingAdminAuditLog : IAdminAuditLog
    {
        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            Entries.Add(entry);
            return Task.CompletedTask;
        }
    }

    private sealed class OneShotConcurrencyInterceptor : SaveChangesInterceptor
    {
        public bool Enabled { get; set; }

        public int ThrowCount { get; private set; }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            if (!Enabled || ThrowCount > 0)
            {
                return base.SavingChangesAsync(eventData, result, cancellationToken);
            }

            ThrowCount++;
            throw new DbUpdateConcurrencyException("Simulated template update concurrency conflict.");
        }
    }

    private static TemplateAssetCommand CreatePreviewAsset(
        string url = "https://cdn.example.com/preview.mp4",
        string fileName = "preview.mp4",
        string contentType = "video/mp4")
    {
        return new TemplateAssetCommand(url, fileName, contentType, 2048, 5.0);
    }

    private static TemplateAssetCommand CreateReferenceAsset(double? durationSeconds, string url = "https://cdn.example.com/reference.mp4")
    {
        return new TemplateAssetCommand(
            url,
            "reference.mp4",
            "video/mp4",
            4096,
            durationSeconds);
    }

    private sealed class RecordingMediaStorage(bool signReadUrls = false) : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];
        public List<string> ReadUrls { get; } = [];
        public List<TimeSpan> ReadTtls { get; } = [];

        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(
                new StoredMediaResponse(
                    $"http://localhost:5000/stub/{asset.FileName}",
                    $"stub/{asset.FileName}",
                    asset.FileName,
                    asset.ContentType,
                    asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0,
                    null)));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            DeletedUrls.Add(assetUrl);
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            ReadUrls.Add(assetUrl);
            ReadTtls.Add(ttl);
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(signReadUrls ? $"{assetUrl}?signed=1" : assetUrl));
        }
    }

    private sealed class TestMediaMetadataReader : IMediaMetadataReader
    {
        public Task<PetMagic.BuildingBlocks.Results.Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success<double?>(asset.DurationSeconds));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success<double?>(null));
        }
    }

    private sealed class FailingDeleteMediaStorage : IMediaStorage
    {
        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(
                new StoredMediaResponse(
                    $"http://localhost:5000/stub/{asset.FileName}",
                    $"stub/{asset.FileName}",
                    asset.FileName,
                    asset.ContentType,
                    asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0,
                    null)));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Failure(TemplatesErrors.MediaStorageFailed));
        }
    }

    private sealed class PassiveGenerationBilling : ITemplateGenerationBilling
    {
        public Task<PetMagic.BuildingBlocks.Results.Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(0));
        }
    }
}
