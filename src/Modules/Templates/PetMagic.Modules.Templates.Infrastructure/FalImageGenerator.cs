using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalImageGenerator(FalQueueClient queueClient) : IImageGenerator, IAsyncImageGenerationQueue
{
    public async Task<Result<ImageGenerationResult>> CreateAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken)
    {
        var input = new Dictionary<string, object?>
        {
            ["prompt"] = prompt,
            ["image_urls"] = new[] { sourceImageUrl },
            ["num_images"] = 1,
            ["output_format"] = "png"
        };
        if (seed is not null)
        {
            input["seed"] = seed.Value;
        }

        var result = await queueClient.RunAsync(
            model,
            input,
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<ImageGenerationResult>(result.Error);
        }

        using var document = result.Value.Response;
        return Complete(document.RootElement, result.Value.RequestId, result.Value.InferenceTimeSeconds);
    }

    public async Task<Result<ProviderQueueSubmission>> SubmitAsync(
        string sourceImageUrl,
        string prompt,
        string model,
        int? seed,
        CancellationToken cancellationToken)
    {
        var input = BuildInput(sourceImageUrl, prompt, seed);
        var result = await queueClient.SubmitAsync(
            model,
            input,
            new FalQueueStageKind("image", FalQueueStages.ImageGeneration),
            cancellationToken);
        return result.IsFailure
            ? Result.Failure<ProviderQueueSubmission>(result.Error)
            : Result.Success(new ProviderQueueSubmission(
                result.Value.RequestId,
                result.Value.StatusUrl.ToString(),
                result.Value.ResponseUrl.ToString()));
    }

    public Result<ImageGenerationResult> Complete(JsonElement response, string? requestId, double? inferenceTimeSeconds)
    {
        if (FalGenerationResponseParser.TryReadFirstImageUrl(response, out var imageUrl))
        {
            return Result.Success(new ImageGenerationResult(imageUrl, requestId, inferenceTimeSeconds));
        }

        TemplateGenerationMetrics.RecordAiProviderError("fal", "response.parse", TemplatesErrors.AiProviderFailed.Code, "image_generation");
        return Result.Failure<ImageGenerationResult>(TemplatesErrors.AiProviderFailed);
    }

    private static Dictionary<string, object?> BuildInput(string sourceImageUrl, string prompt, int? seed)
    {
        var input = new Dictionary<string, object?>
        {
            ["prompt"] = prompt,
            ["image_urls"] = new[] { sourceImageUrl },
            ["num_images"] = 1,
            ["output_format"] = "png"
        };

        if (seed is not null)
        {
            input["seed"] = seed.Value;
        }

        return input;
    }
}
