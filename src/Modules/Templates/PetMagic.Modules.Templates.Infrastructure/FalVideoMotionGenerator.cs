using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FalVideoMotionGenerator(FalQueueClient queueClient) : IVideoMotionGenerator
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

        var result = await queueClient.RunAsync(model, input, cancellationToken);
        if (result.IsFailure)
        {
            return Result.Failure<VideoMotionGenerationResult>(result.Error);
        }

        using var document = result.Value.Response;
        if (TryReadVideoUrl(document.RootElement, out var videoUrl))
        {
            return Result.Success(new VideoMotionGenerationResult(videoUrl, result.Value.RequestId, result.Value.InferenceTimeSeconds));
        }

        TemplateGenerationMetrics.RecordAiProviderError("fal", "response.parse", TemplatesErrors.AiProviderFailed.Code, model);
        return Result.Failure<VideoMotionGenerationResult>(TemplatesErrors.AiProviderFailed);
    }

    private static bool TryReadVideoUrl(JsonElement root, out string videoUrl)
    {
        videoUrl = string.Empty;
        if (!root.TryGetProperty("video", out var video) || video.ValueKind != JsonValueKind.Object)
        {
            return false;
        }

        if (!video.TryGetProperty("url", out var url) || url.ValueKind != JsonValueKind.String)
        {
            return false;
        }

        videoUrl = url.GetString() ?? string.Empty;
        return !string.IsNullOrWhiteSpace(videoUrl);
    }
}
