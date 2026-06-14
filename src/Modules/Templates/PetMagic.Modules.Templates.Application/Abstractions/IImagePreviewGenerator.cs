using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IImagePreviewGenerator
{
    Task<StoredMediaResponse?> CreatePreviewAsync(
        StoredMediaResponse original,
        string outputFileName,
        string? preferredStorageKey,
        CancellationToken cancellationToken);
}
