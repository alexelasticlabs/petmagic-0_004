using System.Diagnostics;
using System.Globalization;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Options;

using SixLabors.Fonts;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Drawing.Processing;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateWatermarkRenderer(
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    TemplateWatermarkSettingsStore watermarkSettings,
    IHttpClientFactory httpClientFactory,
    ILogger<TemplateWatermarkRenderer> logger) : ITemplateWatermarkRenderer
{
    public Task<Result<StoredMediaResponse>> CreateWatermarkedCopyAsync(
        StoredMediaResponse original,
        TemplateType mediaType,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        if (!watermarkSettings.Current.Enabled)
        {
            return Task.FromResult(Result.Failure<StoredMediaResponse>(TemplatesErrors.WatermarkDisabled));
        }

        return mediaType == TemplateType.Video
            ? CreateWatermarkedVideoAsync(original, generationId, cancellationToken)
            : CreateWatermarkedImageAsync(original, generationId, cancellationToken);
    }

    private async Task<Result<StoredMediaResponse>> CreateWatermarkedImageAsync(
        StoredMediaResponse original,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        string? tempInput = null;
        try
        {
            var inputPath = await ResolveInputPathAsync(original, ".png", cancellationToken);
            tempInput = inputPath.TempPath;
            await using var inputStream = File.OpenRead(inputPath.Path);
            using var image = await Image.LoadAsync<Rgba32>(inputStream, cancellationToken);

            var settings = watermarkSettings.Current;
            var label = NormalizeWatermarkText(settings.Text);
            var font = ResolveFont(Math.Max(12, image.Width / ResolveImageFontDivisor(settings.Size)));
            var padding = Math.Max(8, image.Width / 80);
            var margin = Math.Max(10, image.Width / 64);
            var textSize = TextMeasurer.MeasureSize(label, new TextOptions(font));
            var boxWidth = (int)Math.Ceiling(textSize.Width + padding * 2);
            var boxHeight = (int)Math.Ceiling(textSize.Height + padding * 1.4);
            var point = ResolveImagePosition(settings.Position, image.Width, image.Height, boxWidth, boxHeight, margin);
            var opacity = (float)Math.Clamp(settings.Opacity, 0.45, 0.65);

            image.Mutate(context =>
            {
                context.Fill(
                    Color.FromRgba(0, 0, 0, (byte)Math.Round(130 * opacity)),
                    new RectangleF(point.X, point.Y, boxWidth, boxHeight));
                context.DrawText(
                    label,
                    font,
                    Color.FromRgba(255, 255, 255, (byte)Math.Round(255 * opacity)),
                    new PointF(point.X + padding, point.Y + padding * 0.55f));
            });

            await using var outputStream = new MemoryStream();
            await image.SaveAsPngAsync(outputStream, cancellationToken);
            outputStream.Position = 0;
            return await mediaStorage.StoreAsync(
                new MediaUploadCommand($"watermarked-{generationId:N}.png", "image/png", outputStream, outputStream.Length),
                cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Image watermark render failed. GenerationId={GenerationId}", generationId);
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.WatermarkRenderFailed);
        }
        finally
        {
            TryDelete(tempInput);
        }
    }

    private async Task<Result<StoredMediaResponse>> CreateWatermarkedVideoAsync(
        StoredMediaResponse original,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        string? tempInput = null;
        string? tempOutput = null;
        try
        {
            var inputPath = await ResolveInputPathAsync(original, ".mp4", cancellationToken);
            tempInput = inputPath.TempPath;
            tempOutput = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-{generationId:N}.mp4");

            var settings = watermarkSettings.Current;
            var opacity = Math.Clamp(settings.Opacity, 0.45, 0.65)
                .ToString("0.##", CultureInfo.InvariantCulture);
            var escapedText = EscapeDrawTextValue(NormalizeVideoWatermarkText(settings.Text));
            var fontFile = ResolveVideoFontFile();
            var fontFileOption = fontFile is null ? string.Empty : $"fontfile='{EscapeDrawTextValue(fontFile)}':";
            var fontSize = ResolveVideoFontSizeExpression(settings.Text, settings.Size);
            var position = ResolveVideoPositionExpression(settings.Position);
            var filter =
                $"drawtext={fontFileOption}text='{escapedText}':fontcolor=white@{opacity}:fontsize={fontSize}:box=1:boxcolor=black@0.25:boxborderw=2:{position}";

            var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = options.Watermark.FfmpegPath,
                    RedirectStandardError = true,
                    RedirectStandardOutput = true,
                    UseShellExecute = false
                }
            };
            process.StartInfo.ArgumentList.Add("-y");
            process.StartInfo.ArgumentList.Add("-i");
            process.StartInfo.ArgumentList.Add(inputPath.Path);
            process.StartInfo.ArgumentList.Add("-vf");
            process.StartInfo.ArgumentList.Add(filter);
            process.StartInfo.ArgumentList.Add("-c:a");
            process.StartInfo.ArgumentList.Add("copy");
            process.StartInfo.ArgumentList.Add("-movflags");
            process.StartInfo.ArgumentList.Add("+faststart");
            process.StartInfo.ArgumentList.Add(tempOutput);

            process.Start();
            await process.WaitForExitAsync(cancellationToken);
            if (process.ExitCode != 0 || !File.Exists(tempOutput) || new FileInfo(tempOutput).Length == 0)
            {
                var error = await process.StandardError.ReadToEndAsync(cancellationToken);
                logger.LogWarning(
                    "Video watermark render failed. GenerationId={GenerationId} ExitCode={ExitCode} Error={Error}",
                    generationId,
                    process.ExitCode,
                    error.Length > 500 ? error[..500] : error);
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.WatermarkRenderFailed);
            }

            await using var output = File.OpenRead(tempOutput);
            return await mediaStorage.StoreAsync(
                new MediaUploadCommand($"watermarked-{generationId:N}.mp4", "video/mp4", output, output.Length),
                cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Video watermark render failed. GenerationId={GenerationId}", generationId);
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.WatermarkRenderFailed);
        }
        finally
        {
            TryDelete(tempInput);
            TryDelete(tempOutput);
        }
    }

    private async Task<(string Path, string? TempPath)> ResolveInputPathAsync(
        StoredMediaResponse original,
        string fallbackExtension,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(original.LocalPath) && File.Exists(original.LocalPath))
        {
            return (original.LocalPath, null);
        }

        var signed = await mediaStorage.CreateReadUrlAsync(
            original.Url,
            TimeSpan.FromMinutes(5),
            cancellationToken);
        if (signed.IsFailure)
        {
            throw new InvalidOperationException("Could not create read URL for watermark input.");
        }

        var tempPath = Path.Combine(Path.GetTempPath(), $"petmagic-watermark-input-{Guid.NewGuid():N}{fallbackExtension}");
        var client = httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName);
        await using var stream = await client.GetStreamAsync(signed.Value, cancellationToken);
        await using var file = File.Create(tempPath);
        await stream.CopyToAsync(file, cancellationToken);
        return (tempPath, tempPath);
    }

    private static string NormalizeWatermarkText(string value)
    {
        var text = value.Trim();
        return string.IsNullOrWhiteSpace(text) ? "PetMagic" : text;
    }

    private static string NormalizeVideoWatermarkText(string value)
    {
        var normalized = NormalizeWatermarkText(value);
        return normalized.Length > 12 ? "PetMagic" : normalized;
    }

    private static float ResolveImageFontDivisor(string size)
    {
        return size.Trim().ToLowerInvariant() switch
        {
            "medium" => 36f,
            "large" => 30f,
            _ => 42f
        };
    }

    private static PointF ResolveImagePosition(
        string position,
        int imageWidth,
        int imageHeight,
        int boxWidth,
        int boxHeight,
        int margin)
    {
        var normalized = position.Trim().ToLowerInvariant();
        var x = normalized.EndsWith("left", StringComparison.Ordinal)
            ? margin
            : Math.Max(margin, imageWidth - boxWidth - margin);
        var y = normalized.StartsWith("top", StringComparison.Ordinal)
            ? margin
            : Math.Max(margin, imageHeight - boxHeight - margin);
        return new PointF(x, y);
    }

    private static string ResolveVideoFontSizeExpression(string text, string size)
    {
        var label = NormalizeVideoWatermarkText(text);
        var baseRatio = size.Trim().ToLowerInvariant() switch
        {
            "medium" => 0.015,
            "large" => 0.018,
            _ => 0.012
        };
        var widthCapRatio = 0.065 / Math.Max(1.0, label.Length * 0.58);
        return string.Create(
            CultureInfo.InvariantCulture,
            $"min(max(4\\,w*{baseRatio:0.###})\\,w*{widthCapRatio:0.####})");
    }

    private static string ResolveVideoPositionExpression(string position)
    {
        return position.Trim().ToLowerInvariant() switch
        {
            "top-left" => "x=w*0.04:y=h*0.04",
            "top-right" => "x=w-tw-w*0.04:y=h*0.04",
            "bottom-left" => "x=w*0.04:y=h-th-h*0.04",
            _ => "x=w-tw-w*0.04:y=h-th-h*0.04"
        };
    }

    private static string EscapeDrawTextValue(string value)
    {
        return value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace(":", "\\:", StringComparison.Ordinal)
            .Replace("'", "\\'", StringComparison.Ordinal);
    }

    private static Font ResolveFont(float size)
    {
        var candidates = new[] { "Arial", "Helvetica", "DejaVu Sans", "Liberation Sans" };
        foreach (var candidate in candidates)
        {
            if (SystemFonts.TryGet(candidate, out var family))
            {
                return family.CreateFont(size, FontStyle.Bold);
            }
        }

        return SystemFonts.Collection.Families.First().CreateFont(size, FontStyle.Bold);
    }

    private static string? ResolveVideoFontFile()
    {
        var candidates = new[]
        {
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/liberation/LiberationSans-Bold.ttf",
            @"C:\Windows\Fonts\arialbd.ttf",
            @"C:\Windows\Fonts\arial.ttf"
        };

        return candidates.FirstOrDefault(File.Exists);
    }

    private static void TryDelete(string? path)
    {
        if (!string.IsNullOrWhiteSpace(path) && File.Exists(path))
        {
            File.Delete(path);
        }
    }
}
