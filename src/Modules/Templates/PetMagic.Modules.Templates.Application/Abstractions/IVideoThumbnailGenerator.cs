using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IVideoThumbnailGenerator
{
    Task<StoredMediaResponse?> CreateThumbnailAsync(
        StoredMediaResponse original,
        Guid generationId,
        string outputFileName,
        string? preferredStorageKey,
        CancellationToken cancellationToken);
}
