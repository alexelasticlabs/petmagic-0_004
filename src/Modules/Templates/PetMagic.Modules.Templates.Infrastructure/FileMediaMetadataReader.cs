using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FileMediaMetadataReader : IMediaMetadataReader
{
    public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
    }

    public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(storedMedia.LocalPath) || !File.Exists(storedMedia.LocalPath))
        {
            return Task.FromResult(Result.Success<double?>(null));
        }

        try
        {
            using var stream = File.OpenRead(storedMedia.LocalPath);
            if (!Mp4DurationReader.TryReadDurationSeconds(stream, out var durationSeconds))
            {
                return Task.FromResult(Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed));
            }

            var seconds = Math.Round(durationSeconds, 2, MidpointRounding.AwayFromZero);
            return Task.FromResult(Result.Success<double?>(seconds));
        }
        catch
        {
            return Task.FromResult(Result.Failure<double?>(TemplatesErrors.MediaMetadataFailed));
        }
        finally
        {
            TemplateMediaTempFiles.TryDeleteIfOwned(storedMedia.LocalPath);
        }
    }
}
