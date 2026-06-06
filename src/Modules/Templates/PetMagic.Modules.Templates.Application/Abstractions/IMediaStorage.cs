using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IMediaStorage
{
    Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken);

    Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(assetUrl));
    }
}
