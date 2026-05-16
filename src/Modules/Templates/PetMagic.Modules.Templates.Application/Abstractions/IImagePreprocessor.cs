using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IImagePreprocessor
{
    Task<Result<string>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken);
}
