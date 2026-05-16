using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IVideoMotionGenerator
{
    Task<Result<string>> CreateAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        CancellationToken cancellationToken);
}
