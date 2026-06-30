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

    private static TemplateWatermarkRenderer CreateRenderer(CapturingMediaStorage storage, TemplatesOptions options)
    {
        return new TemplateWatermarkRenderer(
            storage,
            options,
            new TemplateWatermarkSettingsStore(options),
            new StaticHttpClientFactory(),
            NullLogger<TemplateWatermarkRenderer>.Instance);
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

    private sealed class StaticHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name)
        {
            return new HttpClient();
        }
    }
}
