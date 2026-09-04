using System.Diagnostics;
using System.Globalization;
using System.Text.Json;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface IVideoDurationProbe
{
    Task<Result<double?>> ProbeAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken);
}

internal interface IVideoDimensionsProbe
{
    Task<Result<VideoDimensionsMetadata>> ProbeDimensionsAsync(
        StoredMediaResponse storedMedia,
        CancellationToken cancellationToken);
}

internal sealed record VideoDimensionsMetadata(
    int Width,
    int Height,
    double DisplayWidth,
    double DisplayHeight,
    double RotationDegrees,
    double SampleAspectRatio);

internal sealed class FfprobeVideoDurationProbe(
    TemplatesOptions options,
    ILogger<FfprobeVideoDurationProbe> logger) : IVideoDurationProbe, IVideoDimensionsProbe
{
    public async Task<Result<double?>> ProbeAsync(
        StoredMediaResponse storedMedia,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(storedMedia.LocalPath) || !File.Exists(storedMedia.LocalPath))
        {
            return Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed);
        }

        using var timeoutSource = new CancellationTokenSource(
            TimeSpan.FromSeconds(options.MediaMetadataProbeTimeoutSeconds));
        using var linkedSource = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken,
            timeoutSource.Token);
        using var process = CreateProcess(storedMedia.LocalPath);

        try
        {
            process.Start();
            var stdoutTask = process.StandardOutput.ReadToEndAsync(CancellationToken.None);
            var stderrLengthTask = ProcessOutputDrainer.CountAsync(
                process.StandardError,
                CancellationToken.None);

            try
            {
                await process.WaitForExitAsync(linkedSource.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                TryKill(process);
                await ObserveProcessOutputAsync(stdoutTask, stderrLengthTask);
                logger.LogWarning(
                    "Template video metadata probe timed out. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} TimeoutSeconds={TimeoutSeconds}",
                    "probe_video_duration",
                    TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                    TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                    options.MediaMetadataProbeTimeoutSeconds);
                return Result.Failure<double?>(TemplatesErrors.MediaMetadataTimedOut);
            }
            catch (OperationCanceledException)
            {
                TryKill(process);
                await ObserveProcessOutputAsync(stdoutTask, stderrLengthTask);
                throw;
            }

            var stdout = await stdoutTask;
            var stderrLength = await stderrLengthTask;
            if (process.ExitCode != 0 || !TryParseDuration(stdout, out var durationSeconds))
            {
                logger.LogWarning(
                    "Template video metadata probe rejected media. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExitCode={ExitCode} ErrorLength={ErrorLength}",
                    "probe_video_duration",
                    TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                    TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                    process.ExitCode,
                    stderrLength);
                return Result.Failure<double?>(TemplatesErrors.MediaMetadataInvalid);
            }

            return Result.Success<double?>(Math.Round(durationSeconds, 2, MidpointRounding.AwayFromZero));
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            TryKill(process);
            logger.LogWarning(
                "Template video metadata probe failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "probe_video_duration",
                TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed);
        }
    }

    internal static bool TryParseDuration(string json, out double durationSeconds)
    {
        durationSeconds = 0;
        try
        {
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            if (!root.TryGetProperty("streams", out var streams)
                || streams.ValueKind != JsonValueKind.Array
                || streams.GetArrayLength() == 0)
            {
                return false;
            }

            foreach (var stream in streams.EnumerateArray())
            {
                if (TryReadPositiveFiniteDuration(stream, out durationSeconds))
                {
                    return true;
                }
            }

            return root.TryGetProperty("format", out var format)
                && TryReadPositiveFiniteDuration(format, out durationSeconds);
        }
        catch (JsonException)
        {
            return false;
        }
    }

    public async Task<Result<VideoDimensionsMetadata>> ProbeDimensionsAsync(
        StoredMediaResponse storedMedia,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(storedMedia.LocalPath) || !File.Exists(storedMedia.LocalPath))
        {
            return Result.Failure<VideoDimensionsMetadata>(TemplatesErrors.MediaMetadataFailed);
        }

        using var timeoutSource = new CancellationTokenSource(
            TimeSpan.FromSeconds(options.MediaMetadataProbeTimeoutSeconds));
        using var linkedSource = CancellationTokenSource.CreateLinkedTokenSource(
            cancellationToken,
            timeoutSource.Token);
        using var process = CreateDimensionsProcess(storedMedia.LocalPath);

        try
        {
            process.Start();
            var stdoutTask = process.StandardOutput.ReadToEndAsync(CancellationToken.None);
            var stderrLengthTask = ProcessOutputDrainer.CountAsync(
                process.StandardError,
                CancellationToken.None);

            try
            {
                await process.WaitForExitAsync(linkedSource.Token);
            }
            catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
            {
                TryKill(process);
                await ObserveProcessOutputAsync(stdoutTask, stderrLengthTask);
                logger.LogWarning(
                    "Template video dimensions probe timed out. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} TimeoutSeconds={TimeoutSeconds}",
                    "probe_video_dimensions",
                    TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                    TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                    options.MediaMetadataProbeTimeoutSeconds);
                return Result.Failure<VideoDimensionsMetadata>(TemplatesErrors.MediaMetadataTimedOut);
            }
            catch (OperationCanceledException)
            {
                TryKill(process);
                await ObserveProcessOutputAsync(stdoutTask, stderrLengthTask);
                throw;
            }

            var stdout = await stdoutTask;
            var stderrLength = await stderrLengthTask;
            if (process.ExitCode != 0 || !TryParseDimensions(stdout, out var dimensions))
            {
                logger.LogWarning(
                    "Template video dimensions probe rejected media. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExitCode={ExitCode} ErrorLength={ErrorLength}",
                    "probe_video_dimensions",
                    TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                    TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                    process.ExitCode,
                    stderrLength);
                return Result.Failure<VideoDimensionsMetadata>(TemplatesErrors.MediaMetadataInvalid);
            }

            return Result.Success(dimensions);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            TryKill(process);
            logger.LogWarning(
                "Template video dimensions probe failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "probe_video_dimensions",
                TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<VideoDimensionsMetadata>(TemplatesErrors.MediaMetadataFailed);
        }
    }

    internal static bool TryParseDimensions(string json, out VideoDimensionsMetadata dimensions)
    {
        dimensions = null!;
        try
        {
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            if (!root.TryGetProperty("streams", out var streams)
                || streams.ValueKind != JsonValueKind.Array
                || streams.GetArrayLength() != 1)
            {
                return false;
            }

            var stream = streams[0];
            if (stream.ValueKind != JsonValueKind.Object
                || !TryReadPositiveInt32(stream, "width", out var width)
                || !TryReadPositiveInt32(stream, "height", out var height)
                || !TryReadSampleAspectRatio(stream, out var sampleAspectRatio)
                || !TryReadRotation(stream, out var rotationDegrees))
            {
                return false;
            }

            var squarePixelWidth = width * sampleAspectRatio;
            var normalizedRotation = NormalizeRotation(rotationDegrees);
            double displayWidth;
            double displayHeight;
            if (IsQuarterTurn(normalizedRotation))
            {
                displayWidth = height;
                displayHeight = squarePixelWidth;
            }
            else if (IsHalfOrNoTurn(normalizedRotation))
            {
                displayWidth = squarePixelWidth;
                displayHeight = height;
            }
            else
            {
                var radians = normalizedRotation * Math.PI / 180d;
                displayWidth = Math.Abs(squarePixelWidth * Math.Cos(radians))
                    + Math.Abs(height * Math.Sin(radians));
                displayHeight = Math.Abs(squarePixelWidth * Math.Sin(radians))
                    + Math.Abs(height * Math.Cos(radians));
            }

            if (!double.IsFinite(displayWidth)
                || !double.IsFinite(displayHeight)
                || displayWidth <= 0
                || displayHeight <= 0)
            {
                return false;
            }

            dimensions = new VideoDimensionsMetadata(
                width,
                height,
                displayWidth,
                displayHeight,
                normalizedRotation,
                sampleAspectRatio);
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private Process CreateProcess(string inputPath)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = options.FfprobePath,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        foreach (var argument in new[]
        {
            "-v", "error",
            "-probesize", "5000000",
            "-analyzeduration", "5000000",
            "-select_streams", "v:0",
            "-show_entries", "stream=duration:format=duration",
            "-of", "json",
            inputPath
        })
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        return process;
    }

    private Process CreateDimensionsProcess(string inputPath)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = options.FfprobePath,
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        foreach (var argument in new[]
        {
            "-v", "error",
            "-probesize", "5000000",
            "-analyzeduration", "5000000",
            "-select_streams", "v:0",
            "-show_entries", "stream=width,height,sample_aspect_ratio:stream_tags=rotate:stream_side_data=rotation",
            "-of", "json",
            inputPath
        })
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        return process;
    }

    private static bool TryReadPositiveFiniteDuration(JsonElement container, out double durationSeconds)
    {
        durationSeconds = 0;
        if (!container.TryGetProperty("duration", out var duration))
        {
            return false;
        }

        var parsed = duration.ValueKind switch
        {
            JsonValueKind.Number => duration.TryGetDouble(out var number) ? number : double.NaN,
            JsonValueKind.String => double.TryParse(
                duration.GetString(),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var number)
                ? number
                : double.NaN,
            _ => double.NaN
        };
        if (!double.IsFinite(parsed) || parsed <= 0)
        {
            return false;
        }

        durationSeconds = parsed;
        return true;
    }

    private static bool TryReadPositiveInt32(JsonElement container, string propertyName, out int value)
    {
        value = 0;
        return container.TryGetProperty(propertyName, out var property)
            && property.ValueKind == JsonValueKind.Number
            && property.TryGetInt32(out value)
            && value > 0;
    }

    private static bool TryReadSampleAspectRatio(JsonElement stream, out double ratio)
    {
        ratio = 1;
        if (!stream.TryGetProperty("sample_aspect_ratio", out var property)
            || property.ValueKind is JsonValueKind.Null or JsonValueKind.Undefined)
        {
            return true;
        }

        if (property.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        var raw = property.GetString();
        if (string.IsNullOrWhiteSpace(raw)
            || string.Equals(raw, "N/A", StringComparison.OrdinalIgnoreCase)
            || string.Equals(raw, "0:1", StringComparison.Ordinal))
        {
            return true;
        }

        var separatorIndex = raw.IndexOf(':', StringComparison.Ordinal);
        if (separatorIndex <= 0
            || separatorIndex == raw.Length - 1
            || raw.IndexOf(':', separatorIndex + 1) >= 0
            || !double.TryParse(
                raw.AsSpan(0, separatorIndex),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var numerator)
            || !double.TryParse(
                raw.AsSpan(separatorIndex + 1),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var denominator)
            || !double.IsFinite(numerator)
            || !double.IsFinite(denominator)
            || numerator <= 0
            || denominator <= 0)
        {
            return false;
        }

        ratio = numerator / denominator;
        return double.IsFinite(ratio) && ratio > 0;
    }

    private static bool TryReadRotation(JsonElement stream, out double rotationDegrees)
    {
        rotationDegrees = 0;
        if (stream.TryGetProperty("side_data_list", out var sideDataList))
        {
            if (sideDataList.ValueKind != JsonValueKind.Array)
            {
                return false;
            }

            foreach (var sideData in sideDataList.EnumerateArray())
            {
                if (sideData.ValueKind != JsonValueKind.Object
                    || !sideData.TryGetProperty("rotation", out var rotation))
                {
                    continue;
                }

                return TryReadFiniteDouble(rotation, out rotationDegrees);
            }
        }

        if (!stream.TryGetProperty("tags", out var tags))
        {
            return true;
        }

        if (tags.ValueKind != JsonValueKind.Object)
        {
            return false;
        }

        return !tags.TryGetProperty("rotate", out var tagRotation)
            || TryReadFiniteDouble(tagRotation, out rotationDegrees);
    }

    private static bool TryReadFiniteDouble(JsonElement property, out double value)
    {
        value = property.ValueKind switch
        {
            JsonValueKind.Number => property.TryGetDouble(out var number) ? number : double.NaN,
            JsonValueKind.String => double.TryParse(
                property.GetString(),
                NumberStyles.Float,
                CultureInfo.InvariantCulture,
                out var number)
                ? number
                : double.NaN,
            _ => double.NaN
        };
        return double.IsFinite(value);
    }

    private static double NormalizeRotation(double rotationDegrees)
    {
        var normalized = rotationDegrees % 360d;
        return normalized < 0 ? normalized + 360d : normalized;
    }

    private static bool IsQuarterTurn(double rotationDegrees)
    {
        return Math.Abs(rotationDegrees - 90d) < 0.01d
            || Math.Abs(rotationDegrees - 270d) < 0.01d;
    }

    private static bool IsHalfOrNoTurn(double rotationDegrees)
    {
        return rotationDegrees < 0.01d
            || Math.Abs(rotationDegrees - 180d) < 0.01d
            || Math.Abs(rotationDegrees - 360d) < 0.01d;
    }

    private static void TryKill(Process process)
    {
        try
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                process.WaitForExit(5_000);
            }
        }
        catch
        {
            // The process is already terminating; the original probe outcome remains authoritative.
        }
    }

    private static async Task ObserveProcessOutputAsync(params Task[] outputTasks)
    {
        try
        {
            await Task.WhenAll(outputTasks);
        }
        catch
        {
            // Stream closure after process termination is expected during cancellation.
        }
    }
}
