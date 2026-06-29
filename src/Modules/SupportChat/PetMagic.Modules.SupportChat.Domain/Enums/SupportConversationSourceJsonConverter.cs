using System.Text.Json;
using System.Text.Json.Serialization;

namespace PetMagic.Modules.SupportChat.Domain.Enums;

public sealed class SupportConversationSourceJsonConverter : JsonConverter<SupportConversationSource>
{
    public override SupportConversationSource Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        if (reader.TokenType != JsonTokenType.String)
        {
            throw new JsonException("Support conversation source must be a string.");
        }

        var raw = reader.GetString();
        if (string.IsNullOrWhiteSpace(raw))
        {
            throw new JsonException("Support conversation source must not be empty.");
        }

        if (Enum.TryParse<SupportConversationSource>(raw, ignoreCase: true, out var parsed)
            && Enum.IsDefined(parsed))
        {
            return parsed;
        }

        throw new JsonException($"Unsupported support conversation source '{raw}'.");
    }

    public override void Write(
        Utf8JsonWriter writer,
        SupportConversationSource value,
        JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToString());
    }
}
