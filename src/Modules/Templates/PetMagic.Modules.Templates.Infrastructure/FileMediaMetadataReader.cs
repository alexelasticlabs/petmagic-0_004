using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FileMediaMetadataReader(
    IVideoDurationProbe videoDurationProbe,
    ILogger<FileMediaMetadataReader>? logger = null) : IMediaMetadataReader
{
    private static readonly StringComparison FileNameComparison = StringComparison.OrdinalIgnoreCase;

    public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
    }

    public Task<Result<double?>> GetVideoDurationSecondsAsync(
        StoredMediaResponse storedMedia,
        CancellationToken cancellationToken)
    {
        return GetVideoDurationSecondsAsync(
            storedMedia,
            retainLocalPathOnSuccess: false,
            cancellationToken: cancellationToken);
    }

    public async Task<Result<double?>> GetVideoDurationSecondsAsync(
        StoredMediaResponse storedMedia,
        bool retainLocalPathOnSuccess,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(storedMedia.LocalPath) || !File.Exists(storedMedia.LocalPath))
        {
            return Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed);
        }

        var shouldReleaseLocalPath = true;
        try
        {
            if (CanReadMp4Duration(storedMedia))
            {
                using var stream = File.OpenRead(storedMedia.LocalPath);
                if (Mp4DurationReader.TryReadDurationSeconds(stream, out var durationSeconds))
                {
                    var seconds = Math.Round(durationSeconds, 2, MidpointRounding.AwayFromZero);
                    shouldReleaseLocalPath = !retainLocalPathOnSuccess;
                    return Result.Success<double?>(seconds);
                }
            }

            var result = await videoDurationProbe.ProbeAsync(storedMedia, cancellationToken);
            shouldReleaseLocalPath = !retainLocalPathOnSuccess || result.IsFailure;
            return result;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                "Template media metadata read threw while processing file. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ExceptionType={ExceptionType}",
                "read_mp4_duration",
                TemplateLogSanitizer.SafeFileName(storedMedia.FileName),
                TemplateLogSanitizer.SafeContentType(storedMedia.ContentType),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed);
        }
        finally
        {
            if (shouldReleaseLocalPath)
            {
                ReleaseRetainedLocalPath(storedMedia);
            }
        }
    }

    public void ReleaseRetainedLocalPath(StoredMediaResponse storedMedia)
    {
        TemplateMediaTempFiles.TryDeleteIfOwned(storedMedia.LocalPath, logger);
    }

    private static bool CanReadMp4Duration(StoredMediaResponse storedMedia)
    {
        if (string.Equals(storedMedia.ContentType, "video/mp4", StringComparison.OrdinalIgnoreCase)
            || string.Equals(storedMedia.ContentType, "application/mp4", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return storedMedia.FileName.EndsWith(".mp4", FileNameComparison)
            || (storedMedia.LocalPath?.EndsWith(".mp4", FileNameComparison) ?? false)
            || storedMedia.StorageKey.EndsWith(".mp4", FileNameComparison)
            || storedMedia.Url.EndsWith(".mp4", FileNameComparison);
    }
}
