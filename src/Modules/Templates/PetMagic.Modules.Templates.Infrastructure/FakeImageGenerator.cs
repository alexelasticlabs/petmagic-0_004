using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeImageGenerator : IImageGenerator
{
    public Task<Result<ImageGenerationResult>> CreateAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(new ImageGenerationResult(sourceImageUrl, null, null)));
    }
}
