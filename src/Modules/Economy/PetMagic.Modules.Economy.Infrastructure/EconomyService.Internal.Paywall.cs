using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private static OffsetPagedResponse<T> ToPaged<T>(List<T> items, int skip, int take)
    {
        var hasMore = items.Count > take;
        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        return new OffsetPagedResponse<T>(items, skip, take, hasMore);
    }

    private static int NormalizeTake(int take, int fallback, int max)
    {
        if (take <= 0)
        {
            return fallback;
        }

        return Math.Min(take, max);
    }

    private static string NormalizeRedeemCode(string rawCode)
    {
        return WhitespaceRegex().Replace(rawCode.Trim().ToUpperInvariant(), string.Empty);
    }

    private static string NormalizeReferralCode(string rawCode)
    {
        return NonAlphanumericRegex().Replace(rawCode.Trim().ToUpperInvariant(), string.Empty);
    }

    private static string NormalizeRewardKind(string rawRewardKind)
    {
        return rawRewardKind.Trim().ToLowerInvariant();
    }

    private static string HashRedeemCode(string normalizedCode)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(normalizedCode));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }

    private static string BuildRedeemCodePrefix(string normalizedCode)
    {
        return normalizedCode[..Math.Min(normalizedCode.Length, 4)];
    }

    private async Task<List<PaywallPaymentMethodResponse>> BuildAvailablePaymentMethodsAsync(
        GetPaywallConfigQuery query,
        CancellationToken cancellationToken)
    {
        var platform = EconomyPaymentProviderPolicy.NormalizePlatform(query.Platform);
        var region = EconomyPaymentProviderPolicy.NormalizeRegion(query.Country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(region);

        const string configsCacheKey = "economy:payment_provider_configs";
        if (!memoryCache.TryGetValue(configsCacheKey, out List<PaymentProviderConfiguration>? configs) || configs is null)
        {
            configs = await dbContext.PaymentProviderConfigurations
                .AsNoTracking()
                .Where(x => x.IsEnabled)
                .ToListAsync(cancellationToken);
            memoryCache.Set(configsCacheKey, configs, TimeSpan.FromMinutes(5));
        }

        var methods = new List<PaywallPaymentMethodResponse>();

        if (string.Equals(platform, "web", StringComparison.Ordinal))
        {
            var stripeConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
            if (stripeConfig is not null && IsStripeModeConfigured(stripeConfig.Mode))
            {
                methods.Add(ToPaywallPaymentMethodResponse(stripeConfig, platform, region, "web"));
            }

            return SortPaymentMethods(methods);
        }

        var nativeProvider = string.Equals(platform, "ios", StringComparison.Ordinal) ? "app_store" : "google_play";
        var nativeConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, nativeProvider, platform, region, isEuRegion, query.AppVersion);
        if (nativeConfig is not null)
        {
            methods.Add(ToPaywallPaymentMethodResponse(nativeConfig, platform, region, "in_app"));
        }

        var stripeMobileConfig = EconomyPaymentProviderPolicy.SelectProviderConfig(configs, "stripe", platform, region, isEuRegion, query.AppVersion);
        if (stripeMobileConfig is not null
            && stripeMobileConfig.ExternalCheckoutAllowed
            && IsStripeMobileModeConfigured(stripeMobileConfig.Mode))
        {
            methods.Add(ToPaywallPaymentMethodResponse(
                stripeMobileConfig,
                platform,
                region,
                "in_app"));
        }

        return SortPaymentMethods(methods);
    }

    private static PaywallPaymentMethodResponse ToPaywallPaymentMethodResponse(
        PaymentProviderConfiguration config,
        string platform,
        string region,
        string purchaseChannel)
    {
        if (string.Equals(config.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            return ToStripePaywallPaymentMethodResponse(
                config,
                platform,
                region,
                purchaseChannel);
        }

        return new PaywallPaymentMethodResponse(
            config.Provider,
            purchaseChannel,
            platform,
            region,
            config.IsEnabled,
            config.IsSelectedByDefault,
            config.RequiresExternalWarning,
            config.RequiresStoreDisclosure,
            config.IsRecommended,
            config.BonusTokensPercent,
            config.DisplayLabel,
            config.DisplaySubtitle,
            config.WarningTitle,
            config.WarningMessage,
            config.Notes);
    }

    private static PaywallPaymentMethodResponse ToStripePaywallPaymentMethodResponse(
        PaymentProviderConfiguration config,
        string platform,
        string region,
        string purchaseChannel)
    {
        var title = config.WarningTitle;
        var message = config.WarningMessage;
        var note = config.Notes;
        var isEuRegion = string.Equals(region, "EU", StringComparison.OrdinalIgnoreCase)
            || EconomyPaymentProviderPolicy.IsEuRegion(region);
        if (string.IsNullOrWhiteSpace(title))
        {
            title = "Pay with Stripe";
        }

        if (string.IsNullOrWhiteSpace(message))
        {
            message = isEuRegion
                ? "Stripe billing is completed inside PetMagic with native payment sheet (Card / Apple Pay / Google Pay). Provider terms and support may differ from App Store or Google Play."
                : "Stripe billing is completed inside PetMagic with native payment sheet (Card / Apple Pay / Google Pay). Your payment details are processed securely by Stripe.";
        }

        if (string.IsNullOrWhiteSpace(note))
        {
            note = string.Equals(platform, "ios", StringComparison.OrdinalIgnoreCase)
                ? "Subscription renewal and cancellation are available in PetMagic subscription management."
                : "You can manage renewal and cancellation in PetMagic subscription management.";
        }

        return new PaywallPaymentMethodResponse(
            config.Provider,
            purchaseChannel,
            platform,
            region,
            config.IsEnabled,
            config.IsSelectedByDefault,
            config.RequiresExternalWarning,
            config.RequiresStoreDisclosure,
            config.IsRecommended,
            config.BonusTokensPercent,
            config.DisplayLabel,
            config.DisplaySubtitle,
            title,
            message,
            note);
    }

    private static List<PaywallPaymentMethodResponse> SortPaymentMethods(IEnumerable<PaywallPaymentMethodResponse> methods)
    {
        var source = methods.ToList();
        var hasStripe = source.Any(x => IsStripeProvider(x.Provider));

        if (hasStripe)
        {
            source = [.. source.Select(x => x with
            {
                IsSelectedByDefault = IsStripeProvider(x.Provider),
                IsRecommended = IsStripeProvider(x.Provider)
            })];
        }

        return [.. source
            .OrderByDescending(x => IsStripeProvider(x.Provider))
            .ThenByDescending(x => x.IsSelectedByDefault)
            .ThenByDescending(x => x.IsRecommended)
            .ThenBy(x => x.Provider, StringComparer.Ordinal)];
    }

    private static bool IsStripeProvider(string provider)
    {
        return string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase);
    }

    private static PaywallLegalTextsResponse BuildPaywallLegalTexts()
    {
        return new PaywallLegalTextsResponse(
            "Payments for in-app subscriptions are processed by Apple App Store or Google Play. You can manage or cancel the subscription in your store account settings.",
            "Alternative billing with Stripe is completed inside the app and may require additional provider disclosures depending on your region.",
            "Stripe payments are completed inside PetMagic with native payment sheets. PetMagic does not store raw card details.");
    }

    [GeneratedRegex("\\s+", RegexOptions.CultureInvariant)]
    private static partial Regex WhitespaceRegex();

    [GeneratedRegex("[^A-Z0-9]", RegexOptions.CultureInvariant)]
    private static partial Regex NonAlphanumericRegex();
}
