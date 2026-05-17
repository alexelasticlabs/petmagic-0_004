using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IImageGenerator
{
    Task<Result<ImageGenerationResult>> CreateAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        CancellationToken cancellationToken);
}