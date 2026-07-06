using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class VideoThumbnailGeneratorTests
{
    [Fact]
    public async Task CreateThumbnailAsync_ShouldReturnNull_WhenFfmpegIsMissing()
    {
        var tempVideo = Path.Combine(Path.GetTempPath(), $"petmagic-thumbnail-missing-ffmpeg-{Guid.NewGuid():N}.mp4");
        await File.WriteAllBytesAsync(tempVideo, [0, 0, 0, 24, 102, 116, 121, 112, 109, 112, 52, 50]);
        var storage = new TrackingMediaStorage();
        var logger = new CapturingLogger<VideoThumbnailGenerator>();
        var generationId = Guid.NewGuid();
        var generator = new VideoThumbnailGenerator(
            storage,
            new NoopHttpClientFactory(),
            CreateOptions($"petmagic-missing-ffmpeg-{Guid.NewGuid():N}"),
            logger);

        try
        {
            var result = await generator.CreateThumbnailAsync(
                new StoredMediaResponse(
                    "templates-media/generated.mp4",
                    "templates-media/generated.mp4",
                    "generated.mp4",
                    "video/mp4",
                    new FileInfo(tempVideo).Length,
                    tempVideo),
                generationId,
                "generation-result-preview.jpg",
                "users/user/generations/generation/result-preview.jpg",
                CancellationToken.None);

            Assert.Null(result);
            Assert.Empty(storage.StoredUploads);
            var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
            Assert.Contains("Video thumbnail generation failed.", entry.Message, StringComparison.Ordinal);
            Assert.False(entry.Properties.ContainsKey("GenerationId"));
            Assert.False(entry.Properties.ContainsKey("FileName"));
            Assert.Equal(SafeLogValues.StableHash(generationId.ToString("D")), entry.Properties["GenerationIdHash"]);
            Assert.Equal(SafeLogValues.StableHash("generated.mp4"), entry.Properties["FileNameHash"]);
            Assert.Equal("video/mp4", entry.Properties["ContentType"]);
        }
        finally
        {
            if (File.Exists(tempVideo))
            {
                File.Delete(tempVideo);
            }
        }
    }

    private static TemplatesOptions CreateOptions(string ffmpegPath)
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
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            Watermark = new TemplateWatermarkOptions
            {
                FfmpegPath = ffmpegPath
            }
        };
    }

    private sealed class TrackingMediaStorage : IMediaStorage
    {
        public List<MediaUploadCommand> StoredUploads { get; } = [];

        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            StoredUploads.Add(asset);
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
            return Task.FromResult(Result.Success(assetUrl));
        }
    }

    private sealed class NoopHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) => new();
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            return NullScope.Instance;
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            var properties = state is IEnumerable<KeyValuePair<string, object?>> values
                ? values
                    .Where(x => !string.Equals(x.Key, "{OriginalFormat}", StringComparison.Ordinal))
                    .ToDictionary(x => x.Key, x => x.Value)
                : [];
            Entries.Add(new CapturedLogEntry(logLevel, formatter(state, exception), exception, properties));
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        Exception? Exception,
        IReadOnlyDictionary<string, object?> Properties);

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose()
        {
        }
    }
}
