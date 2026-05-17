using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeGeneratedMediaImporter(IMediaStorage mediaStorage) : IGeneratedMediaImporter
{
    public Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return mediaStorage.StoreAsync(
            new MediaUploadCommand($"generated-{generationId:N}.mp4", "video/mp4", "fake-generated-video"u8.ToArray()),
            cancellationToken);
    }

    public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return mediaStorage.StoreAsync(
            new MediaUploadCommand($"generated-{generationId:N}.png", "image/png", "fake-generated-image"u8.ToArray()),
            cancellationToken);
    }
}
