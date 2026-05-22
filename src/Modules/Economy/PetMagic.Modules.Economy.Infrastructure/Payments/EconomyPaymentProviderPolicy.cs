using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

internal static class EconomyPaymentProviderPolicy
{
    public static string NormalizeConfigRegion(string value)
    {
        var normalized = value.Trim();
        return string.Equals(normalized, "*", StringComparison.Ordinal) ? "*" : normalized.ToUpperInvariant();
    }

    public static string NormalizePlatform(string platform)
    {
        var normalized = platform.Trim().ToLowerInvariant();
        return normalized switch
        {
            "iphone" => "ios",
            "ipad" => "ios",
            _ => normalized
        };
    }

    public static string NormalizeRegion(string region)
    {
        return string.IsNullOrWhiteSpace(region) ? "*" : region.Trim().ToUpperInvariant();
    }

    public static bool IsEuRegion(string region)
    {
        return region is "AT" or "BE" or "BG" or "HR" or "CY" or "CZ" or "DK" or "EE" or "FI" or "FR"
            or "DE" or "GR" or "HU" or "IE" or "IT" or "LV" or "LT" or "LU" or "MT" or "NL"
            or "PL" or "PT" or "RO" or "SK" or "SI" or "ES" or "SE";
    }

    public static PaymentProviderConfiguration? SelectProviderConfig(
        IEnumerable<PaymentProviderConfiguration> configs,
        string provider,
        string platform,
        string region,
        bool isEuRegion,
        string appVersion)
    {
        return configs
            .Where(x => string.Equals(x.Provider, provider, StringComparison.OrdinalIgnoreCase)
                && string.Equals(x.Platform, platform, StringComparison.OrdinalIgnoreCase)
                && MatchesRegion(x.Region, region, isEuRegion)
                && IsAppVersionAllowed(x.AllowedFromAppVersion, appVersion))
            .OrderByDescending(x => string.Equals(x.Region, region, StringComparison.OrdinalIgnoreCase))
            .ThenByDescending(x => string.Equals(x.Region, "EU", StringComparison.OrdinalIgnoreCase) && isEuRegion)
            .ThenByDescending(x => string.Equals(x.Region, "*", StringComparison.OrdinalIgnoreCase))
            .FirstOrDefault();
    }

    public static bool IsProviderAllowedForCheckout(
        string provider,
        string normalizedPlatform,
        PaymentProviderConfiguration config)
    {
        return string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            ? string.Equals(normalizedPlatform, "web", StringComparison.Ordinal) || config.ExternalCheckoutAllowed
            : true;
    }

    private static bool MatchesRegion(string configuredRegion, string region, bool isEuRegion)
    {
        return string.Equals(configuredRegion, "*", StringComparison.OrdinalIgnoreCase)
            || string.Equals(configuredRegion, region, StringComparison.OrdinalIgnoreCase)
            || (isEuRegion && string.Equals(configuredRegion, "EU", StringComparison.OrdinalIgnoreCase));
    }

    private static bool IsAppVersionAllowed(string configuredVersion, string appVersion)
    {
        if (!Version.TryParse(configuredVersion, out var minimumVersion))
        {
            return true;
        }

        if (!Version.TryParse(appVersion, out var currentVersion))
        {
            return true;
        }

        return currentVersion >= minimumVersion;
    }
}
