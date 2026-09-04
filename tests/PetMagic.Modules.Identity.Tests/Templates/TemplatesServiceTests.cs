using System.Net;
using System.Text;
using System.Threading.Channels;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Application.Abstractions;
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
        TemplatesOptions? templatesOptions = null,
        ILogger<TemplatesService>? logger = null,
        IIdentityUserLookupService? identityUserLookupService = null)
    {
        var options = templatesOptions ?? CreateTemplatesServiceOptions();

        IMediaMetadataReader metadataReader = new TestMediaMetadataReader();
        ITemplateMediaLifecycleService lifecycleService = new TemplateMediaLifecycleService(dbContext, options);
        return new TemplatesService(
            dbContext,
            options,
            new MemoryCache(new MemoryCacheOptions()),
            metadataReader,
            mediaStorage ?? new RecordingMediaStorage(),
            lifecycleService,
            realtimeService ?? new RecordingTemplateFeedRealtimeService(),
            adminAuditLog,
            logger: logger,
            identityUserLookupService: identityUserLookupService);
    }

    private static TemplatesOptions CreateTemplatesServiceOptions(
        string templateOfTheDayBusinessTimeZone = "UTC",
        string[]? supportedLocalizationLocales = null)
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
            SupportedLocalizationLocales = supportedLocalizationLocales ?? ["ru", "de", "es", "fr", "it", "pl"],
            SeedSampleTemplates = false,
            TemplateOfTheDayBusinessTimeZone = templateOfTheDayBusinessTimeZone
        };
    }

    private static async Task<Guid> CreateActiveImageTemplateAsync(ITemplatesService service, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var media = CreateCompletePublicMediaSet(slug, $"{slug}.jpg", "image/jpeg");
        var created = await service.CreateImageAsync(
            new CreateImageTemplateCommand(
                title,
                $"{title} description",
                category,
                tags,
                false,
                20,
                TemplatePromoBadgeMode.New.ToString(),
                media.Preview,
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                TemplateStatus.Active.ToString(),
                PetPhotoRequirements: ["One pet"],
                ThumbnailAsset: media.Thumbnail,
                AnimatedPreviewAsset: media.AnimatedPreview,
                FeedLoopLowAsset: media.FeedLoopLow,
                FeedLoopMediumAsset: media.FeedLoopMedium,
                DetailPreviewAsset: media.DetailPreview),
            CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error.Code);
        return created.Value.TemplateId;
    }

    private static async Task<Guid> CreateActiveVideoTemplateAsync(ITemplatesService service, string title, string category, string[] tags)
    {
        var slug = title.ToLowerInvariant().Replace(' ', '-');
        var media = CreateCompletePublicMediaSet(slug, $"{slug}.mp4", "video/mp4");
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
                media.Preview,
                CreateReferenceAsset(8.0),
                "openai/gpt-image-2/edit",
                "Keep the same pet.",
                "fal-ai/kling-video/v3/pro/motion-control",
                "Smooth cinematic motion.",
                true,
                TemplateStatus.Active.ToString(),
                PetPhotoRequirements: ["One pet"],
                ThumbnailAsset: media.Thumbnail,
                AnimatedPreviewAsset: media.AnimatedPreview,
                FeedLoopLowAsset: media.FeedLoopLow,
                FeedLoopMediumAsset: media.FeedLoopMedium,
                DetailPreviewAsset: media.DetailPreview),
            CancellationToken.None);

        Assert.True(created.IsSuccess, created.Error.Code);
        return created.Value.TemplateId;
    }

    private static TemplateItem CreatePublicFeedTemplate(Guid templateId, string title, DateTime publishedAtUtc, long version)
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
            CreatedAtUtc = publishedAtUtc.AddMinutes(-1),
            PublishedAtUtc = publishedAtUtc,
            UpdatedAtUtc = publishedAtUtc,
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

    private static async Task SetPublishedAtUtcAsync(TemplatesDbContext dbContext, Guid templateId, DateTime publishedAtUtc)
    {
        var template = await dbContext.TemplateItems.SingleAsync(x => x.Id == templateId);
        template.PublishedAtUtc = publishedAtUtc;
        await dbContext.SaveChangesAsync();
    }

    private static TemplateGenerationService CreateGenerationService(
        TemplatesDbContext dbContext,
        TemplatesOptions? options = null,
        ITemplateGenerationBilling? billing = null,
        ITemplateFeedRealtimeService? realtimeService = null,
        ITemplateAiProviderHealthService? aiProviderHealthService = null,
        IAdminAuditLog? adminAuditLog = null,
        FalQueueClient? falQueueClient = null,
        IMediaStorage? mediaStorage = null,
        ITemplateGenerationPushNotificationSender? pushNotificationSender = null)
    {
        return new TemplateGenerationService(
            dbContext,
            billing ?? new PassiveGenerationBilling(),
            mediaStorage ?? new RecordingMediaStorage(),
            options ?? CreateTemplatesOptions(),
            realtimeService: realtimeService,
            aiProviderHealthService: aiProviderHealthService,
            adminAuditLog: adminAuditLog,
            falQueueClient: falQueueClient,
            pushNotificationSender: pushNotificationSender);
    }

    private static TemplatesOptions CreateTemplatesOptions(
        int queueMaxSize = 1_000,
        int globalMaxConcurrentGenerations = 3,
        int imageMaxConcurrentGenerations = 2,
        int imageProtectedConcurrentGenerations = 0,
        int videoMaxConcurrentGenerations = 1,
        int videoReservedConcurrentGenerations = 0,
        int videoBorrowMaxConcurrentGenerations = 0,
        bool enableElasticLaneBorrowing = false,
        bool allowVideoBorrowWhenImageQueueEmpty = true,
        int allowVideoBorrowWhenImageEstimatedWaitBelowSeconds = 120,
        int estimatedImageGenerationSeconds = 90,
        int estimatedVideoPreprocessingSeconds = 90,
        int estimatedVideoGenerationSeconds = 420,
        int estimatedImageImportSeconds = 30,
        int estimatedVideoImportSeconds = 120,
        int videoPreprocessingMaxConcurrentGenerations = 1,
        int mediaImportConcurrency = 1,
        int freeImageMaxEstimatedWaitSeconds = 1_800,
        int premiumImageMaxEstimatedWaitSeconds = 600,
        int freeVideoMaxEstimatedWaitSeconds = 3_600,
        int premiumVideoMaxEstimatedWaitSeconds = 1_800,
        int generationShareTokenTtlDays = 30,
        FalAiOptions? fal = null)
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
            ImageMaxConcurrentGenerations = imageMaxConcurrentGenerations,
            ImageProtectedConcurrentGenerations = imageProtectedConcurrentGenerations,
            VideoMaxConcurrentGenerations = videoMaxConcurrentGenerations,
            VideoReservedConcurrentGenerations = videoReservedConcurrentGenerations,
            VideoBorrowMaxConcurrentGenerations = videoBorrowMaxConcurrentGenerations,
            EnableElasticLaneBorrowing = enableElasticLaneBorrowing,
            AllowVideoBorrowWhenImageQueueEmpty = allowVideoBorrowWhenImageQueueEmpty,
            AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds = allowVideoBorrowWhenImageEstimatedWaitBelowSeconds,
            EstimatedImageGenerationSeconds = estimatedImageGenerationSeconds,
            EstimatedVideoPreprocessingSeconds = estimatedVideoPreprocessingSeconds,
            EstimatedVideoGenerationSeconds = estimatedVideoGenerationSeconds,
            EstimatedImageImportSeconds = estimatedImageImportSeconds,
            EstimatedVideoImportSeconds = estimatedVideoImportSeconds,
            VideoPreprocessingMaxConcurrentGenerations = videoPreprocessingMaxConcurrentGenerations,
            MediaImportConcurrency = mediaImportConcurrency,
            FreeImageMaxEstimatedWaitSeconds = freeImageMaxEstimatedWaitSeconds,
            PremiumImageMaxEstimatedWaitSeconds = premiumImageMaxEstimatedWaitSeconds,
            FreeVideoMaxEstimatedWaitSeconds = freeVideoMaxEstimatedWaitSeconds,
            PremiumVideoMaxEstimatedWaitSeconds = premiumVideoMaxEstimatedWaitSeconds,
            GenerationShareTokenTtlDays = generationShareTokenTtlDays,
            Fal = fal ?? new FalAiOptions(),
            SeedSampleTemplates = false
        };
    }

    private static FalQueueClient CreateFalQueueClient(
        TemplatesDbContext dbContext,
        TemplatesOptions options,
        HttpMessageHandler handler)
    {
        return new FalQueueClient(
            new FixedHttpClientFactory(new HttpClient(handler)),
            options,
            new TemplateAiProviderRateLimiter(dbContext, options),
            NullLogger<FalQueueClient>.Instance);
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

    private static async Task<TemplatesDbContext> CreateSqliteDbContextAsync(
        SqliteConnection connection,
        params IInterceptor[] interceptors)
    {
        var builder = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseSqlite(connection);
        if (interceptors.Length > 0)
        {
            builder.AddInterceptors(interceptors);
        }

        var dbContext = new TemplatesDbContext(builder.Options);
        await dbContext.Database.EnsureCreatedAsync();
        return dbContext;
    }

    private sealed class RecordingTemplateFeedRealtimeService : ITemplateFeedRealtimeService
    {
        public int InvalidatedCount { get; private set; }
        public List<TemplateFeedInvalidationPayload?> Invalidations { get; } = [];
        public List<TemplateGenerationResponse> GenerationStatusEvents { get; } = [];

        public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
        {
            var channel = Channel.CreateUnbounded<TemplateFeedRealtimeEvent>();
            return channel.Reader;
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
        {
            InvalidatedCount++;
            Invalidations.Add(null);
            return ValueTask.CompletedTask;
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(
            TemplateFeedInvalidationPayload payload,
            CancellationToken cancellationToken = default)
        {
            InvalidatedCount++;
            Invalidations.Add(payload);
            return ValueTask.CompletedTask;
        }

        public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
        {
            GenerationStatusEvents.Add(generation);
            return ValueTask.CompletedTask;
        }
    }

    private sealed class FixedHttpClientFactory(HttpClient client) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => client;
    }

    private sealed class ProviderCancellationHttpHandler(
        HttpStatusCode statusCode,
        string providerStatus) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            RequestCount++;
            Assert.Equal(HttpMethod.Put, request.Method);
            Assert.Equal("Key", request.Headers.Authorization?.Scheme);
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(
                    $$"""{"status":"{{providerStatus}}"}""",
                    Encoding.UTF8,
                    "application/json")
            });
        }
    }

    private sealed class AcceptedCancellationReconciliationHttpHandler(
        HttpStatusCode reconciliationStatusCode,
        string reconciliationProviderStatus) : HttpMessageHandler
    {
        public int CancelRequestCount { get; private set; }

        public int StatusRequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request,
            CancellationToken cancellationToken)
        {
            Assert.Equal("Key", request.Headers.Authorization?.Scheme);
            if (request.Method == HttpMethod.Put)
            {
                CancelRequestCount++;
                return JsonAsync(HttpStatusCode.Accepted, "CANCELLATION_REQUESTED");
            }

            Assert.Equal(HttpMethod.Get, request.Method);
            Assert.EndsWith("/status", request.RequestUri?.AbsolutePath, StringComparison.Ordinal);
            StatusRequestCount++;
            return JsonAsync(reconciliationStatusCode, reconciliationProviderStatus);
        }

        private static Task<HttpResponseMessage> JsonAsync(HttpStatusCode statusCode, string providerStatus)
        {
            return Task.FromResult(new HttpResponseMessage(statusCode)
            {
                Content = new StringContent(
                    $$"""{"status":"{{providerStatus}}"}""",
                    Encoding.UTF8,
                    "application/json")
            });
        }
    }

    private sealed class TestAiProviderHealthService(PetMagic.BuildingBlocks.Results.Result result) : ITemplateAiProviderHealthService
    {
        public int CheckCount { get; private set; }

        public Task<PetMagic.BuildingBlocks.Results.Result> EnsureCanAcceptGenerationAsync(
            string mediaType,
            string tier,
            CancellationToken cancellationToken)
        {
            CheckCount++;
            return Task.FromResult(result);
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

    private sealed record ModerationLookupUser(
        Guid UserId,
        bool IsActive,
        IReadOnlyList<string> Roles);

    private sealed class ModerationIdentityUserLookupService(params ModerationLookupUser[] users)
        : IIdentityUserLookupService
    {
        public Task<IReadOnlyList<Guid>> GetActiveUserIdsInRolesAsync(
            IReadOnlyCollection<string> roles,
            CancellationToken cancellationToken)
        {
            var roleSet = roles.ToHashSet(StringComparer.Ordinal);
            IReadOnlyList<Guid> result = users
                .Where(user => user.IsActive && user.Roles.Any(roleSet.Contains))
                .Select(user => user.UserId)
                .Distinct()
                .ToArray();
            return Task.FromResult(result);
        }

        public Task<IReadOnlyDictionary<Guid, IdentityUserLookup>> GetUsersByIdsAsync(
            IReadOnlyCollection<Guid> userIds,
            CancellationToken cancellationToken)
        {
            var requestedIds = userIds.ToHashSet();
            IReadOnlyDictionary<Guid, IdentityUserLookup> result = users
                .Where(user => requestedIds.Contains(user.UserId))
                .ToDictionary(
                    user => user.UserId,
                    user => new IdentityUserLookup(user.UserId, string.Empty, null, user.Roles));
            return Task.FromResult(result);
        }

        public Task<IdentityUserLookup?> GetUserByIdAsync(Guid userId, CancellationToken cancellationToken)
        {
            var user = users.FirstOrDefault(candidate => candidate.UserId == userId);
            IdentityUserLookup? result = user is null
                ? null
                : new IdentityUserLookup(user.UserId, string.Empty, null, user.Roles);
            return Task.FromResult(result);
        }
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable? BeginScope<TState>(TState state)
            where TState : notnull
        {
            return null;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state as IEnumerable<KeyValuePair<string, object?>>
                ?? [];
            Entries.Add(new CapturedLogEntry(
                logLevel,
                formatter(state, exception),
                properties.ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal)));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        IReadOnlyDictionary<string, object?> Properties);

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

    private sealed class ThrowingTemplateFeedRealtimeService : ITemplateFeedRealtimeService
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
            throw new InvalidOperationException("Simulated realtime publish failure.");
        }

        public ValueTask PublishTemplatesFeedInvalidatedAsync(
            TemplateFeedInvalidationPayload payload,
            CancellationToken cancellationToken = default)
        {
            InvalidatedCount++;
            throw new InvalidOperationException("Simulated realtime publish failure.");
        }

        public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
        {
            return ValueTask.CompletedTask;
        }
    }

    private sealed class FailOnRealtimeEventSaveInterceptor : SaveChangesInterceptor
    {
        public bool Enabled { get; set; } = true;

        public override InterceptionResult<int> SavingChanges(
            DbContextEventData eventData,
            InterceptionResult<int> result)
        {
            ThrowIfRealtimeEventIsBeingSaved(eventData);
            return base.SavingChanges(eventData, result);
        }

        public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
            DbContextEventData eventData,
            InterceptionResult<int> result,
            CancellationToken cancellationToken = default)
        {
            ThrowIfRealtimeEventIsBeingSaved(eventData);
            return base.SavingChangesAsync(eventData, result, cancellationToken);
        }

        private void ThrowIfRealtimeEventIsBeingSaved(DbContextEventData eventData)
        {
            if (!Enabled
                || eventData.Context is null
                || !eventData.Context.ChangeTracker.Entries<TemplateRealtimeEventRecord>()
                    .Any(entry => entry.State == EntityState.Added))
            {
                return;
            }

            throw new DbUpdateException("Simulated outbox write failure.");
        }
    }

    private static TemplateAssetCommand CreatePreviewAsset(
        string url = "https://cdn.example.com/preview.mp4",
        string fileName = "preview.mp4",
        string contentType = "video/mp4")
    {
        return new TemplateAssetCommand(url, fileName, contentType, 2048, 5.0);
    }

    private static (
        TemplateAssetCommand Preview,
        TemplateAssetCommand Thumbnail,
        TemplateAssetCommand AnimatedPreview,
        TemplateAssetCommand FeedLoopLow,
        TemplateAssetCommand FeedLoopMedium,
        TemplateAssetCommand DetailPreview) CreateCompletePublicMediaSet(
            string slug,
            string previewFileName,
            string previewContentType)
    {
        return (
            CreatePreviewAsset($"https://cdn.example.com/{previewFileName}", previewFileName, previewContentType),
            CreatePreviewAsset($"https://cdn.example.com/{slug}-thumbnail.jpg", $"{slug}-thumbnail.jpg", "image/jpeg"),
            CreatePreviewAsset($"https://cdn.example.com/{slug}-animated.mp4", $"{slug}-animated.mp4", "video/mp4"),
            CreatePreviewAsset($"https://cdn.example.com/{slug}-feed-low.mp4", $"{slug}-feed-low.mp4", "video/mp4"),
            CreatePreviewAsset($"https://cdn.example.com/{slug}-feed-medium.mp4", $"{slug}-feed-medium.mp4", "video/mp4"),
            CreatePreviewAsset($"https://cdn.example.com/{slug}-detail.jpg", $"{slug}-detail.jpg", "image/jpeg"));
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
        public List<MediaUploadCommand> StoredAssets { get; } = [];

        public Task<PetMagic.BuildingBlocks.Results.Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            StoredAssets.Add(asset);
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

    private sealed class FailingReadMediaStorage : IMediaStorage
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
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success());
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
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

        public Task<PetMagic.BuildingBlocks.Results.Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(assetUrl));
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

    private sealed class RecordingGenerationBilling : ITemplateGenerationBilling
    {
        public List<Guid> ChargedGenerationIds { get; } = [];
        public List<Guid> RefundedGenerationIds { get; } = [];
        public PetMagic.BuildingBlocks.Results.Error? ChargeError { get; init; }
        public PetMagic.BuildingBlocks.Results.Error? RefundError { get; init; }

        public Task<PetMagic.BuildingBlocks.Results.Result> ChargeAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            ChargedGenerationIds.Add(generationId);
            return Task.FromResult(ChargeError is null
                ? PetMagic.BuildingBlocks.Results.Result.Success()
                : PetMagic.BuildingBlocks.Results.Result.Failure(ChargeError));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result> RefundAsync(Guid userId, Guid generationId, int tokenCost, CancellationToken cancellationToken)
        {
            RefundedGenerationIds.Add(generationId);
            return Task.FromResult(RefundError is null
                ? PetMagic.BuildingBlocks.Results.Result.Success()
                : PetMagic.BuildingBlocks.Results.Result.Failure(RefundError));
        }

        public Task<PetMagic.BuildingBlocks.Results.Result<int>> SpendWatermarkUnlockAsync(Guid userId, Guid generationId, int creditCost, CancellationToken cancellationToken)
        {
            return Task.FromResult(PetMagic.BuildingBlocks.Results.Result.Success(0));
        }
    }
}
