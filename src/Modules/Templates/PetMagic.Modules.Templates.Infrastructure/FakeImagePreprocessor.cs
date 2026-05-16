using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeImagePreprocessor : IImagePreprocessor
{
    public Task<Result<string>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(originalImageUrl));
    }
}
