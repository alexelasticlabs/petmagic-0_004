using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{

    private static TemplatesService CreateService(
        TemplatesDbContext dbContext,
        IMediaStorage? mediaStorage = null,
        ITemplateFeedRealtimeService? realtimeService = null)
    {
        var options = new TemplatesOptions
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
            SeedSampleTemplates = false
        };

        IMediaMetadataReader metadataReader = new TestMediaMetadataReader();
        ITemplateMediaLifecycleService lifecycleService = new TemplateMediaLifecycleService(dbContext, options);
        return new TemplatesService(
            dbContext,
            options,
            metadataReader,
            mediaStorage ?? new RecordingMediaStorage(),
            lifecycleService,
            realtimeService ?? new RecordingTemplateFeedRealtimeService(),
            new TestHttpClientFactory(new HttpClient(new UnavailableTranslationHandler())));
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

    private sealed class TestHttpClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            Assert.Equal(TemplateLocalizationTranslator.HttpClientName, name);
            return httpClient;
        }
    }

    private sealed class UnavailableTranslationHandler : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.ServiceUnavailable));
        }
    }

    private static async Task SetUpdatedAtUtcAsync(TemplatesDbContext dbContext, Guid templateId, DateTime updatedAtUtc)
    {
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        template.UpdatedAtUtc = updatedAtUtc;
        await dbContext.SaveChangesAsync();
    }

    private static TemplateGenerationService CreateGenerationService(TemplatesDbContext dbContext, TemplatesOptions? options = null)
    {
        return new TemplateGenerationService(dbContext, new PassiveGenerationBilling(), options ?? CreateTemplatesOptions());
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

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"templates-tests-{Guid.NewGuid():N}")
            .Options;

        return new TemplatesDbContext(options);
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

    private sealed class RecordingMediaStorage : IMediaStorage
    {
        public List<string> DeletedUrls { get; } = [];

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
    }
}
