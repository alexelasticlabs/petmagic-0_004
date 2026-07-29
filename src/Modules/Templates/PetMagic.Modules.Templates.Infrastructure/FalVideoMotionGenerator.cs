using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalVideoMotionGenerator(FalQueueClient queueClient) : IVideoMotionGenerator, IAsyncVideoMotionGenerationQueue
{
    public async Task<Result<VideoMotionGenerationResult>> CreateAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken)
    {
        var input = BuildInput(normalizedImageUrl, referenceVideoUrl, characterOrientation, keepOriginalSound, prompt, seed);

        var result = await queueClient.RunAsync(
            model,
            input,
            new FalQueueStageKind("video", FalQueueStages.VideoGeneration),
            cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<VideoMotionGenerationResult>(result.Error);
        }

        using var document = result.Value.Response;
        return Complete(document.RootElement, result.Value.RequestId, result.Value.InferenceTimeSeconds);
    }

    public async Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken) =>
        await SubmitAsync(
            normalizedImageUrl,
            referenceVideoUrl,
            characterOrientation,
            keepOriginalSound,
            prompt,
            model,
            seed,
            callbackToken: null,
            cancellationToken);

    public async Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        string model,
        int? seed,
        string? callbackToken,
        CancellationToken cancellationToken)
    {
        var input = BuildInput(normalizedImageUrl, referenceVideoUrl, characterOrientation, keepOriginalSound, prompt, seed);
        var result = await queueClient.SubmitAsync(
            model,
            input,
            new FalQueueStageKind("video", FalQueueStages.VideoGeneration),
            callbackToken,
            cancellationToken);
        return result.IsFailure
            ? Result.Failure<ProviderQueueSubmission>(result.Error)
            : Result.Success(new ProviderQueueSubmission(
                result.Value.RequestId,
                result.Value.StatusUrl.ToString(),
                result.Value.ResponseUrl.ToString(),
                result.Value.CancelUrl.ToString()));
    }

    public Result<VideoMotionGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
    {
        if (FalGenerationResponseParser.TryReadVideoUrl(response, out var videoUrl))
        {
            return Result.Success(new VideoMotionGenerationResult(videoUrl, requestId, inferenceTimeSeconds));
        }

        TemplateGenerationMetrics.RecordAiProviderError("fal", "response.parse", TemplatesErrors.AiProviderFailed.Code, "video_generation");
        return Result.Failure<VideoMotionGenerationResult>(TemplatesErrors.AiProviderFailed);
    }

    private static Dictionary<string, object?> BuildInput(
        string normalizedImageUrl,
        string referenceVideoUrl,
        string characterOrientation,
        bool keepOriginalSound,
        string prompt,
        int? seed)
    {
        var input = new Dictionary<string, object?>
        {
            ["prompt"] = prompt,
            ["image_url"] = normalizedImageUrl,
            ["video_url"] = referenceVideoUrl,
            ["character_orientation"] = characterOrientation.ToLowerInvariant(),
            ["keep_original_sound"] = keepOriginalSound
        };

        if (seed is not null)
        {
            input["seed"] = seed.Value;
        }

        return input;
    }
}
