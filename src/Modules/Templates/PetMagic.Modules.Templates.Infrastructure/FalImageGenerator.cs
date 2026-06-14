using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalImageGenerator(FalQueueClient queueClient) : IImageGenerator
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

        var result = await queueClient.RunAsync(model, input, cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<ImageGenerationResult>(result.Error);
        }

        using var document = result.Value.Response;
        if (TryReadFirstImageUrl(document.RootElement, out var imageUrl))
        {
            return Result.Success(new ImageGenerationResult(imageUrl, result.Value.RequestId, result.Value.InferenceTimeSeconds));
        }

        TemplateGenerationMetrics.RecordAiProviderError("fal", "response.parse", TemplatesErrors.AiProviderFailed.Code, model);
        return Result.Failure<ImageGenerationResult>(TemplatesErrors.AiProviderFailed);
    }

    private static bool TryReadFirstImageUrl(JsonElement root, out string imageUrl)
    {
        imageUrl = string.Empty;
        if (!root.TryGetProperty("images", out var images) || images.ValueKind != JsonValueKind.Array || images.GetArrayLength() == 0)
        {
            return false;
        }

        var first = images[0];
        if (!first.TryGetProperty("url", out var url) || url.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        imageUrl = url.GetString() ?? string.Empty;
        return !string.IsNullOrWhiteSpace(imageUrl);
    }
}
