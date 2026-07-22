using System.Net;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateWatermarkRendererTests
{
    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldRenderImageCopyWithoutChangingOriginal()
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-source-{Guid.NewGuid():N}.png");
        try
        {
            using (var original = new Image<Rgba32>(512, 512, Color.White))
            {
                await original.SaveAsPngAsync(tempPath);
            }

            var storage = new CapturingMediaStorage();
            var renderer = CreateRenderer(storage, CreateOptions());
            var media = new StoredMediaResponse("storage/clean.png", "storage/clean.png", "clean.png", "image/png", null, tempPath);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Image, Guid.NewGuid(), CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal("image/png", result.Value.ContentType);
            Assert.StartsWith("watermarked-", result.Value.FileName, StringComparison.Ordinal);
            Assert.NotEmpty(storage.LastBytes);

            using var watermarked = Image.Load<Rgba32>(storage.LastBytes);
            Assert.Equal(512, watermarked.Width);
            Assert.Equal(512, watermarked.Height);
            Assert.Equal(Color.White.ToPixel<Rgba32>(), watermarked[8, 8]);
            Assert.True(CountNonWhitePixels(watermarked, xMin: 320, yMin: 410) > 200);

            using var sourceAfterRender = await Image.LoadAsync<Rgba32>(tempPath);
            Assert.Equal(0, CountNonWhitePixels(sourceAfterRender, xMin: 0, yMin: 0));
        }
        finally
        {
            TryDelete(tempPath);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldRespectConfiguredImagePositionAndSize()
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-source-{Guid.NewGuid():N}.png");
        try
        {
            using (var original = new Image<Rgba32>(512, 512, Color.White))
            {
                await original.SaveAsPngAsync(tempPath);
            }

            var storage = new CapturingMediaStorage();
            var renderer = CreateRenderer(storage, CreateOptions(position: "top-left", size: "large"));
            var media = new StoredMediaResponse("storage/clean.png", "storage/clean.png", "clean.png", "image/png", null, tempPath);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Image, Guid.NewGuid(), CancellationToken.None);

            Assert.True(result.IsSuccess);
            using var watermarked = Image.Load<Rgba32>(storage.LastBytes);
            Assert.True(CountNonWhitePixels(watermarked, xMin: 0, yMin: 0, xMax: 220, yMax: 120) > 300);
            Assert.Equal(0, CountNonWhitePixels(watermarked, xMin: 320, yMin: 410));
        }
        finally
        {
            TryDelete(tempPath);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldUseAdaptiveBottomRightVideoWatermarkFilter()
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        var tempInput = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-source-{Guid.NewGuid():N}.mp4");
        var fakeFfmpeg = Path.Combine(Path.GetTempPath(), $"petmagic-fake-ffmpeg-{Guid.NewGuid():N}.sh");
        var filterCapture = Path.Combine(Path.GetTempPath(), $"petmagic-ffmpeg-filter-{Guid.NewGuid():N}.txt");
        try
        {
            await File.WriteAllBytesAsync(tempInput, [0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109]);
            await File.WriteAllTextAsync(
                fakeFfmpeg,
                $"""
                #!/bin/sh
                filter=""
                output=""
                previous=""
                for arg in "$@"; do
                  if [ "$previous" = "-vf" ]; then
                    filter="$arg"
                  fi
                  output="$arg"
                  previous="$arg"
                done
                printf "%s" "$filter" > "{filterCapture}"
                printf "watermarked-video" > "$output"
                """);
            File.SetUnixFileMode(
                fakeFfmpeg,
                UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);

            var storage = new CapturingMediaStorage();
            var renderer = CreateRenderer(storage, CreateOptions(ffmpegPath: fakeFfmpeg));
            var media = new StoredMediaResponse("storage/clean.mp4", "storage/clean.mp4", "clean.mp4", "video/mp4", null, tempInput);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Video, Guid.NewGuid(), CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal("video/mp4", result.Value.ContentType);
            Assert.StartsWith("watermarked-", result.Value.FileName, StringComparison.Ordinal);
            Assert.Equal("watermarked-video", System.Text.Encoding.UTF8.GetString(storage.LastBytes));

            var filter = await File.ReadAllTextAsync(filterCapture);
            Assert.Contains("drawtext=", filter, StringComparison.Ordinal);
            Assert.Contains("text='PetMagic'", filter, StringComparison.Ordinal);
            Assert.Contains("fontcolor=white@0.55", filter, StringComparison.Ordinal);
            Assert.Contains("fontsize=min(max(4\\,w*0.012)\\,w*0.014)", filter, StringComparison.Ordinal);
            Assert.Contains("box=1", filter, StringComparison.Ordinal);
            Assert.Contains("boxcolor=black@0.25", filter, StringComparison.Ordinal);
            Assert.Contains("boxborderw=2", filter, StringComparison.Ordinal);
            Assert.Contains("x=w-tw-w*0.04:y=h-th-h*0.04", filter, StringComparison.Ordinal);
        }
        finally
        {
            TryDelete(tempInput);
            TryDelete(fakeFfmpeg);
            TryDelete(filterCapture);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldRenderPlayableVideoCopy_WhenFfmpegPathProvided()
    {
        var ffmpegPath = Environment.GetEnvironmentVariable("PETMAGIC_FFMPEG_PATH");
        if (string.IsNullOrWhiteSpace(ffmpegPath) || !File.Exists(ffmpegPath))
        {
            return;
        }

        var tempInput = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-real-source-{Guid.NewGuid():N}.mp4");
        var tempOutput = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-real-output-{Guid.NewGuid():N}.mp4");
        try
        {
            var create = await RunProcessAsync(
                ffmpegPath,
                [
                    "-y",
                    "-f",
                    "lavfi",
                    "-i",
                    "color=c=white:s=320x180:d=1",
                    "-pix_fmt",
                    "yuv420p",
                    tempInput
                ],
                CancellationToken.None);
            Assert.Equal(0, create.ExitCode);
            Assert.True(File.Exists(tempInput));

            var storage = new CapturingMediaStorage();
            var renderer = CreateRenderer(storage, CreateOptions(ffmpegPath: ffmpegPath));
            var media = new StoredMediaResponse("storage/clean.mp4", "storage/clean.mp4", "clean.mp4", "video/mp4", null, tempInput);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Video, Guid.NewGuid(), CancellationToken.None);

            Assert.True(result.IsSuccess);
            Assert.Equal("video/mp4", result.Value.ContentType);
            Assert.True(storage.LastBytes.Length > 0);
            await File.WriteAllBytesAsync(tempOutput, storage.LastBytes);

            var decode = await RunProcessAsync(
                ffmpegPath,
                ["-v", "error", "-i", tempOutput, "-f", "null", "-"],
                CancellationToken.None);
            Assert.Equal(0, decode.ExitCode);
        }
        finally
        {
            TryDelete(tempInput);
            TryDelete(tempOutput);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldLogStructuredWarning_WhenImageRenderThrows()
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-bad-source-{Guid.NewGuid():N}.png");
        var generationId = Guid.NewGuid();
        try
        {
            await File.WriteAllBytesAsync(tempPath, [1, 2, 3, 4]);

            var storage = new CapturingMediaStorage();
            var logger = new CapturingLogger<TemplateWatermarkRenderer>();
            var renderer = CreateRenderer(storage, CreateOptions(), logger);
            var media = new StoredMediaResponse("storage/bad.png", "storage/bad.png", "bad.png", "image/png", null, tempPath);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Image, generationId, CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal(TemplatesErrors.WatermarkRenderFailed.Code, result.Error.Code);
            var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
            Assert.Contains("Image watermark render failed.", entry.Message, StringComparison.Ordinal);
            Assert.Equal("create_image_watermark", entry.Properties["Operation"]);
            Assert.False(entry.Properties.ContainsKey("GenerationId"));
            Assert.False(entry.Properties.ContainsKey("FileName"));
            Assert.Equal(SafeLogValues.StableHash(generationId.ToString("D")), entry.Properties["GenerationIdHash"]);
            Assert.Equal(SafeLogValues.StableHash("bad.png"), entry.Properties["FileNameHash"]);
            Assert.Equal("image/png", entry.Properties["ContentType"]);
            Assert.Equal(true, entry.Properties["HasLocalPath"]);
            Assert.Equal("UnknownImageFormatException", entry.Properties["ExceptionType"]);
            Assert.Null(entry.Exception);
        }
        finally
        {
            TryDelete(tempPath);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldLogStructuredWarning_WhenVideoRendererReturnsNonZeroExit()
    {
        if (OperatingSystem.IsWindows())
        {
            return;
        }

        var tempInput = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-bad-video-{Guid.NewGuid():N}.mp4");
        var fakeFfmpeg = Path.Combine(Path.GetTempPath(), $"petmagic-fake-ffmpeg-fail-{Guid.NewGuid():N}.sh");
        var generationId = Guid.NewGuid();
        try
        {
            await File.WriteAllBytesAsync(tempInput, [0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109]);
            await File.WriteAllTextAsync(
                fakeFfmpeg,
                """
                #!/bin/sh
                printf "ffmpeg failed for watermark" >&2
                exit 7
                """);
            File.SetUnixFileMode(
                fakeFfmpeg,
                UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute);

            var storage = new CapturingMediaStorage();
            var logger = new CapturingLogger<TemplateWatermarkRenderer>();
            var renderer = CreateRenderer(storage, CreateOptions(ffmpegPath: fakeFfmpeg), logger);
            var media = new StoredMediaResponse("storage/clean.mp4", "storage/clean.mp4", "clean.mp4", "video/mp4", null, tempInput);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Video, generationId, CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal(TemplatesErrors.WatermarkRenderFailed.Code, result.Error.Code);
            var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
            Assert.Contains("Video watermark render failed.", entry.Message, StringComparison.Ordinal);
            Assert.Equal("render_video_watermark", entry.Properties["Operation"]);
            Assert.False(entry.Properties.ContainsKey("GenerationId"));
            Assert.False(entry.Properties.ContainsKey("FileName"));
            Assert.Equal(SafeLogValues.StableHash(generationId.ToString("D")), entry.Properties["GenerationIdHash"]);
            Assert.Equal(SafeLogValues.StableHash("clean.mp4"), entry.Properties["FileNameHash"]);
            Assert.Equal("video/mp4", entry.Properties["ContentType"]);
            Assert.Equal(7, entry.Properties["ExitCode"]);
            Assert.Equal(27L, entry.Properties["ErrorLength"]);
            Assert.Equal(true, entry.Properties["HasLocalPath"]);
            Assert.False(entry.Properties.ContainsKey("ErrorPreview"));
        }
        finally
        {
            TryDelete(tempInput);
            TryDelete(fakeFfmpeg);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldLogStructuredWarning_WhenImageWatermarkStorageFails()
    {
        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-source-{Guid.NewGuid():N}.png");
        var generationId = Guid.NewGuid();
        try
        {
            using (var original = new Image<Rgba32>(128, 128, Color.White))
            {
                await original.SaveAsPngAsync(tempPath);
            }

            var storage = new FailingMediaStorage("templates.media_storage_failed token=watermark-storage-secret");
            var logger = new CapturingLogger<TemplateWatermarkRenderer>();
            var renderer = CreateRenderer(storage, CreateOptions(), logger);
            var media = new StoredMediaResponse("storage/clean.png", "storage/clean.png", "clean.png", "image/png", null, tempPath);

            var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Image, generationId, CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal(TemplatesErrors.MediaStorageFailed.Code, result.Error.Code);
            var entry = Assert.Single(logger.Entries, x => x.Level == LogLevel.Warning);
            Assert.Contains("Image watermark storage failed.", entry.Message, StringComparison.Ordinal);
            Assert.Equal("store_image_watermark", entry.Properties["Operation"]);
            Assert.False(entry.Properties.ContainsKey("GenerationId"));
            Assert.False(entry.Properties.ContainsKey("FileName"));
            Assert.Equal(SafeLogValues.StableHash(generationId.ToString("D")), entry.Properties["GenerationIdHash"]);
            Assert.Equal(SafeLogValues.StableHash("clean.png"), entry.Properties["FileNameHash"]);
            Assert.Equal("image/png", entry.Properties["ContentType"]);
            Assert.Equal(TemplatesErrors.MediaStorageFailed.Code, entry.Properties["ErrorCode"]);
            Assert.Equal(true, entry.Properties["HasLocalPath"]);
            Assert.DoesNotContain(
                "watermark-storage-secret",
                string.Join(' ', entry.Properties.Values.Select(value => value?.ToString())),
                StringComparison.OrdinalIgnoreCase);
        }
        finally
        {
            TryDelete(tempPath);
        }
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldFailWithoutDownloading_WhenRemoteImageSizeMetadataExceedsLimit()
    {
        var storage = new RemoteReadUrlMediaStorage("https://cdn.example.com/source.png");
        var handler = new RecordingHttpHandler();
        var renderer = CreateRenderer(
            storage,
            CreateOptions(),
            httpClientFactory: new StaticHttpClientFactory(new HttpClient(handler)));
        var media = new StoredMediaResponse(
            "storage/remote.png",
            "storage/remote.png",
            "remote.png",
            "image/png",
            31 * 1024 * 1024,
            null);

        var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Image, Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.WatermarkRenderFailed.Code, result.Error.Code);
        Assert.Equal(0, handler.RequestCount);
    }

    [Fact]
    public async Task CreateWatermarkedCopyAsync_ShouldFailWhenRemoteVideoBodyExceedsLimitWithoutContentLength()
    {
        var storage = new RemoteReadUrlMediaStorage("https://cdn.example.com/source.mp4");
        var handler = new RecordingHttpHandler(new StreamingContent(251 * 1024 * 1024));
        var renderer = CreateRenderer(
            storage,
            CreateOptions(),
            httpClientFactory: new StaticHttpClientFactory(new HttpClient(handler)));
        var media = new StoredMediaResponse(
            "storage/remote.mp4",
            "storage/remote.mp4",
            "remote.mp4",
            "video/mp4",
            null,
            null);

        var result = await renderer.CreateWatermarkedCopyAsync(media, TemplateType.Video, Guid.NewGuid(), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.WatermarkRenderFailed.Code, result.Error.Code);
        Assert.Equal(1, handler.RequestCount);
    }

    private static TemplateWatermarkRenderer CreateRenderer(
        IMediaStorage storage,
        TemplatesOptions options,
        ILogger<TemplateWatermarkRenderer>? logger = null,
        IHttpClientFactory? httpClientFactory = null)
    {
        return new TemplateWatermarkRenderer(
            storage,
            options,
            new TemplateWatermarkSettingsStore(options),
            httpClientFactory ?? new StaticHttpClientFactory(),
            logger ?? NullLogger<TemplateWatermarkRenderer>.Instance);
    }

    private static TemplatesOptions CreateOptions(
        string ffmpegPath = "ffmpeg",
        string position = "bottom-right",
        string size = "small")
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
            AllowedKlingModels = ["fal-ai/kling-video/v3/standard/motion-control"],
            SupportedLocalizationLocales = ["ru", "de", "es", "fr", "it", "pl"],
            Watermark = new TemplateWatermarkOptions
            {
                Enabled = true,
                Text = "Made with PetMagic",
                Opacity = 0.55,
                Position = position,
                Size = size,
                ApplyToImages = true,
                ApplyToVideos = true,
                FfmpegPath = ffmpegPath
            }
        };
    }

    private static int CountNonWhitePixels(
        Image<Rgba32> image,
        int xMin,
        int yMin,
        int? xMax = null,
        int? yMax = null)
    {
        var count = 0;
        for (var y = yMin; y < Math.Min(yMax ?? image.Height, image.Height); y++)
        {
            for (var x = xMin; x < Math.Min(xMax ?? image.Width, image.Width); x++)
            {
                if (image[x, y] != Color.White.ToPixel<Rgba32>())
                {
                    count++;
                }
            }
        }

        return count;
    }

    private static void TryDelete(string path)
    {
        if (File.Exists(path))
        {
            File.Delete(path);
        }
    }

    private static async Task<(int ExitCode, string Error)> RunProcessAsync(
        string fileName,
        IReadOnlyList<string> arguments,
        CancellationToken cancellationToken)
    {
        using var process = new System.Diagnostics.Process
        {
            StartInfo = new System.Diagnostics.ProcessStartInfo
            {
                FileName = fileName,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false
            }
        };
        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        process.Start();
        await process.WaitForExitAsync(cancellationToken);
        var error = await process.StandardError.ReadToEndAsync(cancellationToken);
        return (process.ExitCode, error);
    }

    private sealed class CapturingMediaStorage : IMediaStorage
    {
        public byte[] LastBytes { get; private set; } = [];

        public async Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            if (asset.Content is not null)
            {
                LastBytes = asset.Content;
            }
            else if (asset.ContentStream is not null)
            {
                await using var buffer = new MemoryStream();
                await asset.ContentStream.CopyToAsync(buffer, cancellationToken);
                LastBytes = buffer.ToArray();
            }

            return Result.Success(new StoredMediaResponse(
                $"storage/{asset.FileName}",
                $"storage/{asset.FileName}",
                asset.FileName,
                asset.ContentType,
                LastBytes.LongLength,
                null));
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

    private sealed class FailingMediaStorage(string? errorCode = null) : IMediaStorage
    {
        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            var error = errorCode is null
                ? TemplatesErrors.MediaStorageFailed
                : new Error(errorCode, "Media upload could not be stored.");
            return Task.FromResult(Result.Failure<StoredMediaResponse>(error));
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

    private sealed class StaticHttpClientFactory : IHttpClientFactory
    {
        private readonly HttpClient httpClient;

        public StaticHttpClientFactory()
            : this(new HttpClient())
        {
        }

        public StaticHttpClientFactory(HttpClient httpClient)
        {
            this.httpClient = httpClient;
        }

        public HttpClient CreateClient(string name)
        {
            return httpClient;
        }
    }

    private sealed class RemoteReadUrlMediaStorage(string readUrl) : IMediaStorage
    {
        public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
        {
            throw new NotSupportedException();
        }

        public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(readUrl));
        }
    }

    private sealed class RecordingHttpHandler(HttpContent? content = null) : HttpMessageHandler
    {
        public int RequestCount { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            RequestCount++;
            return Task.FromResult(new HttpResponseMessage(System.Net.HttpStatusCode.OK)
            {
                Content = content ?? new ByteArrayContent([1, 2, 3, 4])
            });
        }
    }

    private sealed class StreamingContent(long length) : HttpContent
    {
        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context)
        {
            throw new NotSupportedException();
        }

        protected override bool TryComputeLength(out long computedLength)
        {
            computedLength = 0;
            return false;
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
