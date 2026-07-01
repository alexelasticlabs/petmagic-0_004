using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class FakeAiProviderFailureTests
{
    [Fact]
    public async Task FakeImageGenerator_ShouldFail_WhenSentinelIsInPrompt()
    {
        var generator = new FakeImageGenerator();

        var result = await generator.CreateAsync(
            "https://storage.example/source.png",
            $"render {FakeAiFailure.Sentinel}",
            "fake-image-model",
            seed: null,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
    }

    [Fact]
    public async Task FakeImagePreprocessor_ShouldFail_WhenSentinelIsInModel()
    {
        var preprocessor = new FakeImagePreprocessor();

        var result = await preprocessor.NormalizeAsync(
            "https://storage.example/source.png",
            $"fake-preprocess-model-{FakeAiFailure.Sentinel}",
            "normalize pet image",
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
    }

    [Fact]
    public async Task FakeVideoMotionGenerator_ShouldFail_WhenSentinelIsInReferenceVideo()
    {
        var generator = new FakeVideoMotionGenerator();

        var result = await generator.CreateAsync(
            "https://storage.example/normalized.png",
            $"https://storage.example/{FakeAiFailure.Sentinel}/reference.mp4",
            "Front",
            keepOriginalSound: true,
            "animate pet",
            "fake-video-model",
            seed: null,
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.AiProviderFailed.Code, result.Error.Code);
    }
}
