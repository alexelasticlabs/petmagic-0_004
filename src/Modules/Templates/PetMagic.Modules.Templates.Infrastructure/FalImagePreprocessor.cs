using System.Text.Json;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalImagePreprocessor(FalQueueClient queueClient) : IImagePreprocessor
{
    public async Task<Result<string>> NormalizeAsync(string originalImageUrl, string model, string prompt, CancellationToken cancellationToken)
    {
        var input = new
        {
            prompt,
            image_urls = new[] { originalImageUrl },
            num_images = 1,
            output_format = "png"
        };

        var result = await queueClient.RunAsync(model, input, cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<string>(result.Error);
        }

        using var document = result.Value;
        return TryReadFirstImageUrl(document.RootElement, out var imageUrl)
            ? Result.Success(imageUrl)
            : Result.Failure<string>(TemplatesErrors.AiProviderFailed);
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
