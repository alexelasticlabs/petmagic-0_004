using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Economy.Infrastructure;

internal static class EconomyLogSanitizer
{
    internal const string UnknownErrorCode = "economy.error";

    internal static string? SafeUserId(Guid? userId)
    {
        return userId.HasValue
            ? SafeLogValues.StableHash(userId.Value.ToString("D"))
            : null;
    }

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

    internal static string SafeErrorCode(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return UnknownErrorCode;
        }

        var trimmed = value.Trim();
        var sanitized = SafeLogValues.SanitizeText(trimmed, 128);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized
            : UnknownErrorCode;
    }
}
