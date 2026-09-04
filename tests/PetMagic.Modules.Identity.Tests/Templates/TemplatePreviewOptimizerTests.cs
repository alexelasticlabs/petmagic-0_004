using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatePreviewOptimizerTests
{
    [Fact]
    public async Task OptimizeAsync_ShouldCreateBoundedWebpVariants_WithDistinctImmutableKeys()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-{Guid.NewGuid():N}.png");
        using (var source = new Image<Rgba32>(2000, 1000, Color.CornflowerBlue))
        {
            await source.SaveAsPngAsync(inputPath);
        }

        var storage = new RecordingMediaStorage();
        var optimizer = CreateOptimizer(storage);
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/png"),
                null,
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.True(result.Value.WasOptimized);
            Assert.Equal(2, storage.Uploads.Count);
            Assert.Equal("image/webp", result.Value.ThumbnailAsset?.ContentType);
            Assert.Equal("image/webp", result.Value.DetailPreviewAsset?.ContentType);
            Assert.Equal(result.Value.DetailPreviewAsset?.Url, result.Value.PrimaryAsset.Url);
            Assert.Equal(result.Value.ThumbnailAsset?.Url, result.Value.FeedLoopLowAsset?.Url);
            Assert.NotEqual(result.Value.ThumbnailAsset?.StorageKey, result.Value.DetailPreviewAsset?.StorageKey);
            Assert.All(
                storage.Uploads,
                upload => Assert.StartsWith("template-previews/", upload.PreferredStorageKey, StringComparison.Ordinal));

            var thumbnailUpload = storage.Uploads.Single(upload => upload.PreferredStorageKey!.EndsWith("/thumbnail.webp", StringComparison.Ordinal));
            var detailUpload = storage.Uploads.Single(upload => upload.PreferredStorageKey!.EndsWith("/detail.webp", StringComparison.Ordinal));
            using var thumbnail = Image.Load(thumbnailUpload.Content);
            using var detail = Image.Load(detailUpload.Content);
            Assert.Equal((640, 320), (thumbnail.Width, thumbnail.Height));
            Assert.Equal((1600, 800), (detail.Width, detail.Height));
            Assert.True(File.Exists(inputPath));
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizeAsync_ShouldFlattenAnimatedImages_ToBoundDecodeAndFeedCost()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-animated-{Guid.NewGuid():N}.gif");
        using (var source = new Image<Rgba32>(320, 240, Color.CornflowerBlue))
        using (var secondFrame = new Image<Rgba32>(320, 240, Color.OrangeRed))
        {
            source.Frames.AddFrame(secondFrame.Frames.RootFrame);
            await source.SaveAsGifAsync(inputPath);
        }

        var storage = new RecordingMediaStorage();
        var optimizer = CreateOptimizer(storage);
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/gif"),
                null,
                CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal(2, storage.Uploads.Count);
            foreach (var upload in storage.Uploads)
            {
                using var optimized = Image.Load(upload.Content);
                Assert.Single(optimized.Frames);
                Assert.Equal((320, 240), (optimized.Width, optimized.Height));
            }
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizationGate_ShouldSerializeWorkAtConfiguredConcurrency()
    {
        var options = CreateOptions(new TemplatePreviewOptimizationOptions
        {
            MaxConcurrentOptimizations = 1
        });
        using var gate = new TemplatePreviewOptimizationGate(options);
        using var firstLease = await gate.EnterAsync(CancellationToken.None);

        var secondLeaseTask = gate.EnterAsync(CancellationToken.None).AsTask();

        Assert.False(secondLeaseTask.IsCompleted);
        firstLease.Dispose();
        using var secondLease = await secondLeaseTask;
    }

    [Fact]
    public async Task OptimizationGate_ShouldHonorTimeoutTokenWhileQueued()
    {
        var options = CreateOptions(new TemplatePreviewOptimizationOptions
        {
            MaxConcurrentOptimizations = 1
        });
        using var gate = new TemplatePreviewOptimizationGate(options);
        using var firstLease = await gate.EnterAsync(CancellationToken.None);
        using var timeoutSource = new CancellationTokenSource(TimeSpan.FromMilliseconds(25));

        await Assert.ThrowsAnyAsync<OperationCanceledException>(async () =>
        {
            using var unexpectedLease = await gate.EnterAsync(timeoutSource.Token);
        });
    }

    [Fact]
    public async Task OptimizeAsync_ShouldRejectImageDimensionsAboveSafetyBudget()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-budget-{Guid.NewGuid():N}.png");
        using (var source = new Image<Rgba32>(100, 100, Color.CornflowerBlue))
        {
            await source.SaveAsPngAsync(inputPath);
        }

        var storage = new RecordingMediaStorage();
        var optimizer = CreateOptimizer(
            storage,
            new TemplatePreviewOptimizationOptions
            {
                MaxImageDimension = 100,
                MaxImagePixelCount = 5_000
            });
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/png"),
                null,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.preview_optimization_invalid", result.Error.Code);
            Assert.Empty(storage.Uploads);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Theory]
    [InlineData(9000, 1000, 9000, 1000, 8_192, 20_000_000L)]
    [InlineData(5000, 4001, 5000, 4001, 8_192, 20_000_000L)]
    [InlineData(3840, 2160, 10240, 2160, 8_192, 20_000_000L)]
    public async Task OptimizeAsync_ShouldRejectOversizedVideoMetadata_BeforeFfmpegDecode(
        int width,
        int height,
        double displayWidth,
        double displayHeight,
        int maxDimension,
        long maxPixelCount)
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-budget-{Guid.NewGuid():N}.mp4");
        await File.WriteAllBytesAsync(inputPath, [0, 0, 0, 0]);
        var storage = new RecordingMediaStorage();
        var dimensionsProbe = new FixedVideoDimensionsProbe(Result.Success(
            new VideoDimensionsMetadata(width, height, displayWidth, displayHeight, 0, 1)));
        var optimizer = CreateOptimizer(
            storage,
            new TemplatePreviewOptimizationOptions
            {
                MaxVideoDimension = maxDimension,
                MaxVideoPixelCount = maxPixelCount
            },
            dimensionsProbe: dimensionsProbe);

        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "video/mp4"),
                2,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.preview_optimization_invalid", result.Error.Code);
            Assert.Equal(1, dimensionsProbe.Calls);
            Assert.Empty(storage.Uploads);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizeAsync_ShouldRejectMalformedVideoMetadata_BeforeFfmpegDecode()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-malformed-{Guid.NewGuid():N}.mp4");
        await File.WriteAllBytesAsync(inputPath, [0, 0, 0, 0]);
        var storage = new RecordingMediaStorage();
        var dimensionsProbe = new FixedVideoDimensionsProbe(
            Result.Failure<VideoDimensionsMetadata>(TemplatesErrors.MediaMetadataInvalid));
        var optimizer = CreateOptimizer(storage, dimensionsProbe: dimensionsProbe);

        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "video/mp4"),
                2,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.preview_optimization_invalid", result.Error.Code);
            Assert.Equal(1, dimensionsProbe.Calls);
            Assert.Empty(storage.Uploads);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizeAsync_ShouldRollbackFirstVariant_WhenSecondVariantUploadFails()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-rollback-{Guid.NewGuid():N}.png");
        using (var source = new Image<Rgba32>(800, 600, Color.CornflowerBlue))
        {
            await source.SaveAsPngAsync(inputPath);
        }

        var storage = new RecordingMediaStorage(failStoreCall: 2, failDeleteCall: 2);
        var lifecycle = new RecordingMediaLifecycleService();
        var optimizer = CreateOptimizer(storage, lifecycle: lifecycle);
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/png"),
                null,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal("templates.preview_optimization_failed", result.Error.Code);
            var firstUpload = Assert.Single(storage.Uploads);
            Assert.Contains(firstUpload.Url, storage.DeletedUrls);
            Assert.Contains(
                storage.DeletedUrls,
                url => url.StartsWith("templates-media/template-previews/", StringComparison.Ordinal)
                    && url.EndsWith("/detail.webp", StringComparison.Ordinal));
            Assert.Equal(
                TemplateMediaLifecycleState.CleanupFailed,
                lifecycle.States[firstUpload.Url]);
            Assert.True(lifecycle.SaveCalls >= 2);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizeAsync_ShouldCleanupAmbiguousR2Store_UsingConfiguredManagedPrefix()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-r2-cleanup-{Guid.NewGuid():N}.png");
        using (var source = new Image<Rgba32>(100, 100, Color.CornflowerBlue))
        {
            await source.SaveAsPngAsync(inputPath);
        }

        var storage = new RecordingMediaStorage(failStoreCall: 1);
        var optimizer = CreateOptimizer(
            storage,
            storageProvider: TemplateStorageProviders.R2,
            objectKeyPrefix: "tenant-media");
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/png"),
                null,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            var cleanupKey = Assert.Single(storage.DeletedUrls);
            Assert.StartsWith("tenant-media/template-previews/", cleanupKey, StringComparison.Ordinal);
            Assert.EndsWith("/thumbnail.webp", cleanupKey, StringComparison.Ordinal);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public async Task OptimizeAsync_ShouldAuditAmbiguousStore_WhenDeleteFails()
    {
        var inputPath = Path.Combine(Path.GetTempPath(), $"petmagic-template-preview-ambiguous-{Guid.NewGuid():N}.png");
        using (var source = new Image<Rgba32>(100, 100, Color.CornflowerBlue))
        {
            await source.SaveAsPngAsync(inputPath);
        }

        var storage = new RecordingMediaStorage(failStoreCall: 1, failDeleteCall: 1);
        var lifecycle = new RecordingMediaLifecycleService();
        var optimizer = CreateOptimizer(storage, lifecycle: lifecycle);
        try
        {
            var result = await optimizer.OptimizeAsync(
                CreateOriginal(inputPath, "image/png"),
                null,
                CancellationToken.None);

            Assert.True(result.IsFailure);
            var ambiguousKey = Assert.Single(storage.DeletedUrls);
            Assert.Equal(TemplateMediaLifecycleState.CleanupFailed, lifecycle.States[ambiguousKey]);
            Assert.True(lifecycle.SaveCalls >= 2);
        }
        finally
        {
            File.Delete(inputPath);
        }
    }

    [Fact]
    public void FfmpegProfile_ShouldBoundDurationDimensionsFrameRateAndBitrates()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatePreviewOptimizer.cs"));

        Assert.Contains("\"-nostdin\"", source, StringComparison.Ordinal);
        Assert.Contains("\"-t\", MaxPreviewVideoDurationSeconds", source, StringComparison.Ordinal);
        Assert.Contains("force_original_aspect_ratio=decrease:force_divisible_by=2", source, StringComparison.Ordinal);
        Assert.Contains("\"-fpsmax\", \"30\"", source, StringComparison.Ordinal);
        Assert.Contains("\"-threads\", ffmpegThreads", source, StringComparison.Ordinal);
        Assert.Contains("\"-filter_threads\", ffmpegThreads", source, StringComparison.Ordinal);
        Assert.Contains("\"-threads:v\", ffmpegThreads", source, StringComparison.Ordinal);
        Assert.Contains("FeedVideoMaxBitrateKbps", source, StringComparison.Ordinal);
        Assert.Contains("DetailVideoMaxBitrateKbps", source, StringComparison.Ordinal);
        Assert.Contains("\"-an\", \"-sn\", \"-dn\"", source, StringComparison.Ordinal);
        Assert.Contains("\"0:a:0?\"", source, StringComparison.Ordinal);
        Assert.Contains("\"-movflags\", \"+faststart\"", source, StringComparison.Ordinal);
        Assert.Contains("ProcessOutputDrainer.", source, StringComparison.Ordinal);
    }

    private static TemplatePreviewOptimizer CreateOptimizer(
        IMediaStorage storage,
        TemplatePreviewOptimizationOptions? previewOptions = null,
        string storageProvider = TemplateStorageProviders.Local,
        string objectKeyPrefix = "templates-media",
        ITemplateMediaLifecycleService? lifecycle = null,
        IVideoDimensionsProbe? dimensionsProbe = null)
    {
        var options = CreateOptions(previewOptions, storageProvider, objectKeyPrefix);
        return new TemplatePreviewOptimizer(
            storage,
            lifecycle ?? new RecordingMediaLifecycleService(),
            new NoopHttpClientFactory(),
            dimensionsProbe ?? new FixedVideoDimensionsProbe(Result.Success(
                new VideoDimensionsMetadata(1920, 1080, 1920, 1080, 0, 1))),
            options,
            new TemplatePreviewOptimizationGate(options),
            NullLogger<TemplatePreviewOptimizer>.Instance);
    }

    private static StoredMediaResponse CreateOriginal(string path, string contentType)
    {
        return new StoredMediaResponse(
            "https://cdn.petmagic.test/templates-media/raw.png",
            "templates-media/raw.png",
            Path.GetFileName(path),
            contentType,
            new FileInfo(path).Length,
            path);
    }

    private static TemplatesOptions CreateOptions(
        TemplatePreviewOptimizationOptions? previewOptions,
        string storageProvider = TemplateStorageProviders.Local,
        string objectKeyPrefix = "templates-media")
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            StorageProvider = storageProvider,
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            PreviewOptimization = previewOptions ?? new TemplatePreviewOptimizationOptions(),
            R2 = new R2StorageOptions
            {
                ObjectKeyPrefix = objectKeyPrefix
            }
        };
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
        {
            directory = directory.Parent;
        }

        return directory?.FullName ?? throw new DirectoryNotFoundException("Repository root was not found.");
    }

    private sealed class RecordingMediaStorage(
        int? failStoreCall = null,
        int? failDeleteCall = null) : IMediaStorage
    {
        private int storeCalls;
        private int deleteCalls;

        public List<StoredUpload> Uploads { get; } = [];

        public List<string> DeletedUrls { get; } = [];

        public async Task<Result<StoredMediaResponse>> StoreAsync(
            MediaUploadCommand asset,
            CancellationToken cancellationToken)
        {
            storeCalls++;
            if (storeCalls == failStoreCall)
            {
                return Result.Failure<StoredMediaResponse>(new Error(
                    "templates.media_storage_failed",
                    "Test storage failure."));
            }

            await using var content = new MemoryStream();
            if (asset.Content is not null)
            {
                await content.WriteAsync(asset.Content, cancellationToken);
            }
            else
            {
                Assert.NotNull(asset.ContentStream);
                await asset.ContentStream!.CopyToAsync(content, cancellationToken);
            }

            var storageKey = asset.PreferredStorageKey ?? $"tests/{Guid.NewGuid():N}";
            var stored = new StoredMediaResponse(
                $"https://cdn.petmagic.test/templates-media/{storageKey}",
                storageKey,
                asset.FileName,
                asset.ContentType,
                content.Length,
                null);
            Uploads.Add(new StoredUpload(
                stored.Url,
                asset.PreferredStorageKey,
                asset.ContentType,
                content.ToArray()));
            return Result.Success(stored);
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            deleteCalls++;
            DeletedUrls.Add(assetUrl);
            if (deleteCalls == failDeleteCall)
            {
                return Task.FromResult(Result.Failure(new Error(
                    "templates.media_storage_failed",
                    "Test delete failure.")));
            }

            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(
            string assetUrl,
            TimeSpan ttl,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<string>(new Error(
                "templates.media_storage_failed",
                "Unexpected read URL request.")));
        }
    }

    private sealed record StoredUpload(
        string Url,
        string? PreferredStorageKey,
        string ContentType,
        byte[] Content);

    private sealed class FixedVideoDimensionsProbe(Result<VideoDimensionsMetadata> result) : IVideoDimensionsProbe
    {
        public int Calls { get; private set; }

        public Task<Result<VideoDimensionsMetadata>> ProbeDimensionsAsync(
            StoredMediaResponse storedMedia,
            CancellationToken cancellationToken)
        {
            Calls++;
            return Task.FromResult(result);
        }
    }

    private sealed class RecordingMediaLifecycleService : ITemplateMediaLifecycleService
    {
        public Dictionary<string, TemplateMediaLifecycleState> States { get; } = new(StringComparer.Ordinal);

        public int SaveCalls { get; private set; }

        public Task RegisterTemporaryUploadAsync(
            TemplateAssetCommand asset,
            TemplateMediaRole role,
            CancellationToken cancellationToken)
        {
            States[asset.Url] = TemplateMediaLifecycleState.Temporary;
            return Task.CompletedTask;
        }

        public Task ClaimTemplateAssetAsync(
            Guid templateId,
            TemplateAssetCommand? asset,
            TemplateMediaRole role,
            CancellationToken cancellationToken) => Task.CompletedTask;

        public Task MarkDeletedAsync(string url, CancellationToken cancellationToken)
        {
            if (States.ContainsKey(url))
            {
                States[url] = TemplateMediaLifecycleState.Deleted;
            }

            return Task.CompletedTask;
        }

        public Task MarkCleanupFailureAsync(
            string url,
            string errorCode,
            string errorMessage,
            CancellationToken cancellationToken)
        {
            if (States.ContainsKey(url))
            {
                States[url] = TemplateMediaLifecycleState.CleanupFailed;
            }

            return Task.CompletedTask;
        }

        public Task SaveChangesAsync(CancellationToken cancellationToken)
        {
            SaveCalls++;
            return Task.CompletedTask;
        }
    }

    private sealed class NoopHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new();
    }
}
