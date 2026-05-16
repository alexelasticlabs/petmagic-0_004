using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeMediaMetadataReader : IMediaMetadataReader
{
    public Task<Result<double?>> GetVideoDurationSecondsAsync(TemplateAssetCommand asset, CancellationToken cancellationToken)
    {
        if (asset.DurationSeconds is > 0)
        {
            return Task.FromResult(Result.Success<double?>(asset.DurationSeconds));
        }

        return Task.FromResult(Result.Success<double?>(null));
    }

    public Task<Result<double?>> GetVideoDurationSecondsAsync(StoredMediaResponse storedMedia, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success<double?>(null));
    }
}
