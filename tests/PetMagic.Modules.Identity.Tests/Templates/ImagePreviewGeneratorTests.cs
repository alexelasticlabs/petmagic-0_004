using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class ImagePreviewGeneratorTests
{
    [Fact]
    public async Task CreatePreviewAsync_ShouldLogWarning_WhenPreviewStorageFails()
    {
        var logger = new CapturingLogger<ImagePreviewGenerator>();
        var storage = new FailingStoreMediaStorage();
        var generator = new ImagePreviewGenerator(
            storage,
            new StaticHttpClientFactory(new HttpClient(new RemoteImageHandler(CreatePngBytes()))),
            CreateOptions(),
            logger);

        var result = await generator.CreatePreviewAsync(
            new StoredMediaResponse(
                "https://cdn.example.com/source.png",
                "templates/source.png",
                "source.png",
                "image/png",
                null,
                null),
            "preview.webp",
            preferredStorageKey: "templates/preview.webp",
            CancellationToken.None);

        Assert.Null(result);
        var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
        Assert.Contains("Image preview storage failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("store_preview", entry.Properties["Operation"]);
        Assert.Equal("source.png", entry.Properties["FileName"]);
        Assert.Equal("image/png", entry.Properties["ContentType"]);
        Assert.Equal("templates.media_storage_failed", entry.Properties["ErrorCode"]);
        Assert.Equal(false, entry.Properties["HasLocalPath"]);
    }

    [Fact]
    public async Task CreatePreviewAsync_ShouldLogWarning_WhenPreviewGenerationThrows()
    {
        var logger = new CapturingLogger<ImagePreviewGenerator>();
        var generator = new ImagePreviewGenerator(
            new FailingStoreMediaStorage(),
            new StaticHttpClientFactory(new HttpClient(new RemoteImageHandler([1, 2, 3, 4]))),
            CreateOptions(),
            logger);

        var result = await generator.CreatePreviewAsync(
            new StoredMediaResponse(
                "https://cdn.example.com/source.png",
                "templates/source.png",
                "source.png",
                "image/png",
                null,
                null),
            "preview.webp",
            preferredStorageKey: null,
            CancellationToken.None);

        Assert.Null(result);
        var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
        Assert.Contains("Image preview generation failed.", entry.Message, StringComparison.Ordinal);
        Assert.Equal("create_preview", entry.Properties["Operation"]);
        Assert.Equal("source.png", entry.Properties["FileName"]);
        Assert.Equal("image/png", entry.Properties["ContentType"]);
        Assert.Equal(false, entry.Properties["HasLocalPath"]);
    }

    [Fact]
    public async Task CreatePreviewAsync_ShouldFailWithoutDownloading_WhenInputSizeMetadataExceedsLimit()
    {
        var handler = new RecordingRemoteImageHandler(CreatePngBytes());
        var generator = new ImagePreviewGenerator(
            new FailingStoreMediaStorage(),
            new StaticHttpClientFactory(new HttpClient(handler)),
            CreateOptions(previewMaxFileSizeBytes: 32),
            new CapturingLogger<ImagePreviewGenerator>());

        var result = await generator.CreatePreviewAsync(
            new StoredMediaResponse(
                "https://cdn.example.com/source.png",
                "templates/source.png",
                "source.png",
                "image/png",
                64,
                null),
            "preview.webp",
            preferredStorageKey: null,
            CancellationToken.None);

        Assert.Null(result);
        Assert.Equal(0, handler.RequestCount);
    }

    [Fact]
    public async Task CreatePreviewAsync_ShouldFailWhenRemoteBodyExceedsLimitWithoutContentLength()
    {
        var handler = new RecordingRemoteImageHandler(new byte[0], streamLength: 2048, suppressContentLength: true);
        var generator = new ImagePreviewGenerator(
            new FailingStoreMediaStorage(),
            new StaticHttpClientFactory(new HttpClient(handler)),
            CreateOptions(previewMaxFileSizeBytes: 512),
            new CapturingLogger<ImagePreviewGenerator>());

        var result = await generator.CreatePreviewAsync(
            new StoredMediaResponse(
                "https://cdn.example.com/source.png",
                "templates/source.png",
                "source.png",
                "image/png",
                null,
                null),
            "preview.webp",
            preferredStorageKey: null,
            CancellationToken.None);

        Assert.Null(result);
        Assert.Equal(1, handler.RequestCount);
    }

    private static TemplatesOptions CreateOptions(long previewMaxFileSizeBytes = 25 * 1024 * 1024)
    {
        return new TemplatesOptions
        {
            PublicBaseUrl = "https://app.petmagic.test",
            LocalMediaRootPath = Path.GetTempPath(),
            DefaultPreprocessingPrompt = "preprocess",
            DefaultKlingPrompt = "animate",
            DefaultImagePrompt = "image",
            AllowedImageModels = ["fal-ai/test-model"],
            AllowedPreprocessingModels = ["fal-ai/test-model"],
            AllowedKlingModels = ["fal-ai/test-model"],
            SupportedLocalizationLocales = ["en"],
            PreviewMaxFileSizeBytes = previewMaxFileSizeBytes
        };
    }

    private static byte[] CreatePngBytes()
    {
        using var image = new Image<Rgba32>(16, 16, Color.White);
        using var stream = new MemoryStream();
        image.SaveAsPng(stream);
        return stream.ToArray();
    }

    private sealed class FailingStoreMediaStorage : IMediaStorage
    {
        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed));
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

    private sealed class RemoteImageHandler(byte[] content) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = new ByteArrayContent(content)
            });
        }
    }

    private sealed class RecordingRemoteImageHandler(byte[] content, long? streamLength = null, bool suppressContentLength = false) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestCount++;
            HttpContent responseContent = streamLength.HasValue
                ? new StreamingContent(streamLength.Value, suppressContentLength)
                : new ByteArrayContent(content);
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = responseContent
            });
        }
    }

    private sealed class StaticHttpClientFactory(HttpClient httpClient) : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            return httpClient;
        }
    }

    private sealed class StreamingContent(long length, bool suppressContentLength) : HttpContent
    {
        protected override Task SerializeToStreamAsync(Stream stream, System.Net.TransportContext? context)
        {
            throw new NotSupportedException();
        }

        protected override bool TryComputeLength(out long computedLength)
        {
            computedLength = length;
            return !suppressContentLength;
        }

        protected override Task<Stream> CreateContentReadStreamAsync()
        {
            return Task.FromResult<Stream>(new FixedByteStream(length));
        }
    }

    private sealed class FixedByteStream(long length) : Stream
    {
        private readonly long totalLength = length;
        private long remaining = length;

        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => totalLength;
        public override long Position
        {
            get => totalLength - remaining;
            set => throw new NotSupportedException();
        }

        public override int Read(byte[] buffer, int offset, int count)
        {
            if (remaining <= 0)
            {
                return 0;
            }

            var bytesToRead = (int)Math.Min(count, Math.Min(remaining, 81920));
            Array.Clear(buffer, offset, bytesToRead);
            remaining -= bytesToRead;
            return bytesToRead;
        }

        public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
        {
            if (remaining <= 0)
            {
                return ValueTask.FromResult(0);
            }

            var bytesToRead = (int)Math.Min(buffer.Length, Math.Min(remaining, 81920));
            buffer[..bytesToRead].Span.Clear();
            remaining -= bytesToRead;
            return ValueTask.FromResult(bytesToRead);
        }

        public override void Flush()
        {
        }

        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
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
