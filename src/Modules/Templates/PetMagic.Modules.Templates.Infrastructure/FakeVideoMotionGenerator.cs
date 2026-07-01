using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeVideoMotionGenerator : IVideoMotionGenerator
{
    public Task<Result<VideoMotionGenerationResult>> CreateAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken)
    {
        if (FakeAiFailure.IsRequested(normalizedImageUrl, referenceVideoUrl, prompt, model))
        {
            return Task.FromResult(Result.Failure<VideoMotionGenerationResult>(TemplatesErrors.AiProviderFailed));
        }

        return Task.FromResult(Result.Success(new VideoMotionGenerationResult(referenceVideoUrl, null, null)));
    }
}
