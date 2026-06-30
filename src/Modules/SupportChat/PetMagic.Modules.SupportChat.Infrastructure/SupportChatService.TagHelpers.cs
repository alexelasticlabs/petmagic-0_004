using System.Text.Json;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private static IReadOnlyList<string> ParseTags(string? tagsJson)
    {
        if (string.IsNullOrWhiteSpace(tagsJson))
        {
            return [];
        }

        try
        {
            return JsonSerializer.Deserialize<List<string>>(tagsJson)
                ?.Where(tag => !string.IsNullOrWhiteSpace(tag))
                .Select(tag => tag.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList()
                ?? [];
        }
        catch (JsonException)
        {
            return [];
        }
    }

    private static List<string>? NormalizeTags(IReadOnlyList<string>? tags)
    {
        if (tags is null || tags.Count == 0)
        {
            return [];
        }

        var normalized = tags
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Select(tag => tag.Trim())
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        if (normalized.Count > 8 || normalized.Any(tag => tag.Length > 32))
        {
            return null;
        }

        return normalized;
    }

    private static string SerializeTags(IReadOnlyList<string> tags)
    {
        return tags.Count == 0
            ? "[]"
            : JsonSerializer.Serialize(tags);
    }
}
