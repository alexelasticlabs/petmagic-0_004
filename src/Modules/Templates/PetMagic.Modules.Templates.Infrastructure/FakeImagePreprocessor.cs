using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FakeImagePreprocessor : IImagePreprocessor
{
    public Task<Result<ImagePreprocessResult>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
    {
        if (FakeAiFailure.IsRequested(originalImageUrl, model, prompt))
        {
            return Task.FromResult(Result.Failure<ImagePreprocessResult>(TemplatesErrors.AiProviderFailed));
        }

        return Task.FromResult(Result.Success(new ImagePreprocessResult(originalImageUrl, null, null)));
    }
}
