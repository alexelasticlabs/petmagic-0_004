using System.Text;

namespace PetMagic.BuildingBlocks.Observability;

public static class SafeHttpContentReader
{
    public const int DefaultMaxChars = 8192;

    public static async Task<string> ReadStringPrefixAsync(
        HttpContent content,
        CancellationToken cancellationToken,
        int maxChars = DefaultMaxChars)
    {
        var value = await ReadRawStringPrefixAsync(content, cancellationToken, maxChars);
        return SafeLogValues.SanitizeText(value, maxChars);
    }

    public static async Task<string> ReadRawStringPrefixAsync(
        HttpContent content,
        CancellationToken cancellationToken,
        int maxChars = DefaultMaxChars)
    {
        ArgumentNullException.ThrowIfNull(content);

        if (maxChars <= 0)
        {
            return string.Empty;
        }

        await using var stream = await content.ReadAsStreamAsync(cancellationToken);
        using var reader = new StreamReader(
            stream,
            Encoding.UTF8,
            detectEncodingFromByteOrderMarks: true,
            bufferSize: Math.Min(1024, maxChars),
            leaveOpen: false);

        var buffer = new char[Math.Min(1024, maxChars)];
        var builder = new StringBuilder(capacity: Math.Min(maxChars, 1024));
        while (builder.Length < maxChars)
        {
            var remaining = maxChars - builder.Length;
            var read = await reader.ReadAsync(buffer.AsMemory(0, Math.Min(buffer.Length, remaining)), cancellationToken);
            if (read == 0)
            {
                break;
            }

            builder.Append(buffer, 0, read);
        }

        return builder.ToString();
    }
}
