using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public interface IVideoMotionGenerator
{
    Task<Result<VideoMotionGenerationResult>> CreateAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken);
}
