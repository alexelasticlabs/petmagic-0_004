namespace PetMagic.Modules.Economy.Infrastructure;

internal static class EconomyLogSanitizer
{
    internal static string? SafePaymentIntentId(string? externalPaymentId)
    {
        if (string.IsNullOrWhiteSpace(externalPaymentId))
        {
            return null;
        }

        var trimmed = externalPaymentId.Trim();
        return trimmed.StartsWith("pi_", StringComparison.OrdinalIgnoreCase) ? SafeExternalId(externalPaymentId) : null;
    }

    internal static string? SafeExternalId(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        if (trimmed.Length <= 6)
        {
            return "***";
        }

        var separatorIndex = trimmed.IndexOf('_');
        var prefixLength = separatorIndex >= 0
            ? separatorIndex + 1
            : Math.Min(4, trimmed.Length - 2);
        prefixLength = Math.Min(prefixLength, trimmed.Length - 2);

        var suffixLength = Math.Min(4, trimmed.Length - prefixLength);
        if (prefixLength <= 0 || suffixLength <= 0)
        {
            return "***";
        }

        return $"{trimmed[..prefixLength]}***{trimmed[^suffixLength..]}";
    }
}
