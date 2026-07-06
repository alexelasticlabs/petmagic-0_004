namespace PetMagic.BuildingBlocks.Storage;

public static class ManagedPathSegments
{
    public static bool IsUnsafe(string? segment)
    {
        if (string.IsNullOrWhiteSpace(segment)
            || string.Equals(segment, ".", StringComparison.Ordinal)
            || string.Equals(segment, "..", StringComparison.Ordinal)
            || ContainsInvalidPercentEncoding(segment))
        {
            return true;
        }

        string decodedSegment;
        try
        {
            decodedSegment = Uri.UnescapeDataString(segment);
        }
        catch (UriFormatException)
        {
            return true;
        }

        return string.Equals(decodedSegment, ".", StringComparison.Ordinal)
            || string.Equals(decodedSegment, "..", StringComparison.Ordinal)
            || decodedSegment.Contains('/', StringComparison.Ordinal)
            || decodedSegment.Contains('\\', StringComparison.Ordinal);
    }

    private static bool ContainsInvalidPercentEncoding(string value)
    {
        for (var i = 0; i < value.Length; i++)
        {
            if (value[i] != '%')
            {
                continue;
            }

            if (i + 2 >= value.Length
                || !IsHexDigit(value[i + 1])
                || !IsHexDigit(value[i + 2]))
            {
                return true;
            }
        }

        return false;
    }

    private static bool IsHexDigit(char value) =>
        value is >= '0' and <= '9'
            or >= 'a' and <= 'f'
            or >= 'A' and <= 'F';
}
