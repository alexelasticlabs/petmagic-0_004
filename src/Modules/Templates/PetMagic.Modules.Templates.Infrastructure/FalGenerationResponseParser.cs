using System.Text.Json;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class FalGenerationResponseParser
{
    public static bool TryReadFirstImageUrl(JsonElement root, out string imageUrl)
    {
        imageUrl = string.Empty;
        if (!root.TryGetProperty("images", out var images)
            || images.ValueKind != JsonValueKind.Array
            || images.GetArrayLength() == 0)
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

    public static bool TryReadVideoUrl(JsonElement root, out string videoUrl)
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
