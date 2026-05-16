using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeMediaStorage : IMediaStorage
{
    public Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
    {
        var key = $"stub/{Guid.NewGuid():N}/{asset.FileName}";
        return Task.FromResult(Result.Success(new StoredMediaResponse($"http://localhost:5000/{key}", key, asset.FileName, asset.ContentType, asset.Content.LongLength, null)));
    }

    public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success());
    }
}
