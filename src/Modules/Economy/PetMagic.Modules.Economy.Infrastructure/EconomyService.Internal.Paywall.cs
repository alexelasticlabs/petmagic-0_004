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
        var usesNativeAndroidPaymentSheet = string.Equals(platform, "android", StringComparison.OrdinalIgnoreCase);
        var isEuRegion = string.Equals(region, "EU", StringComparison.OrdinalIgnoreCase)
            || EconomyPaymentProviderPolicy.IsEuRegion(region);
        if (string.IsNullOrWhiteSpace(title))
        {
            title = "Pay with Stripe";
        }

        if (usesNativeAndroidPaymentSheet)
        {
            message = isEuRegion
                ? "Stripe payment opens in a secure payment form inside PetMagic. Provider terms and support may differ from Google Play."
                : "Stripe payment opens in a secure payment form inside PetMagic. Your payment details are processed securely by Stripe.";
        }
        else if (string.IsNullOrWhiteSpace(message))
        {
            message = isEuRegion
                ? "Stripe billing opens in secure Stripe-hosted Checkout. Provider terms and support may differ from App Store or Google Play."
                : "Stripe billing opens in secure Stripe-hosted Checkout. Your payment details are processed securely by Stripe.";
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

    private static PaywallLegalTextsResponse BuildPaywallLegalTexts(string? locale, string? platform)
    {
        if (string.Equals(
            EconomyPaymentProviderPolicy.NormalizePlatform(platform),
            "android",
            StringComparison.Ordinal))
        {
            return new PaywallLegalTextsResponse(
                BuildPaywallStoreNotice(locale),
                BuildPaywallExternalCheckoutNotice(locale),
                BuildNativeAndroidStripeNotice(locale));
        }

        return NormalizePaywallLocale(locale) switch
        {
            "de" => new PaywallLegalTextsResponse(
                "Zahlungen für In-App-Abonnements werden über den Apple App Store oder Google Play abgewickelt. Du kannst dein Abonnement in den Kontoeinstellungen des jeweiligen Stores verwalten oder kündigen.",
                "Eine alternative Zahlung mit Stripe wird in der App abgeschlossen und kann abhängig von deiner Region zusätzliche Hinweise des Zahlungsanbieters erfordern.",
                "Stripe-Zahlungen werden in der sicheren, von Stripe gehosteten Checkout-Umgebung abgewickelt. PetMagic speichert keine vollständigen Kartendaten."),
            "es" => new PaywallLegalTextsResponse(
                "Los pagos de suscripciones dentro de la aplicación se procesan mediante Apple App Store o Google Play. Puedes gestionar o cancelar la suscripción desde la configuración de tu cuenta en la tienda.",
                "La facturación alternativa con Stripe se completa dentro de la aplicación y puede requerir avisos adicionales del proveedor según tu región.",
                "Los pagos con Stripe se abren en el Checkout seguro alojado por Stripe. PetMagic no almacena los datos completos de la tarjeta."),
            "fr" => new PaywallLegalTextsResponse(
                "Les paiements des abonnements intégrés sont traités par l’App Store d’Apple ou Google Play. Vous pouvez gérer ou annuler votre abonnement dans les réglages de votre compte de la boutique.",
                "La facturation alternative avec Stripe est effectuée dans l’application et peut nécessiter des informations supplémentaires du prestataire selon votre région.",
                "Les paiements Stripe s’ouvrent dans le Checkout sécurisé hébergé par Stripe. PetMagic ne stocke pas les données complètes de votre carte."),
            "it" => new PaywallLegalTextsResponse(
                "I pagamenti degli abbonamenti in-app vengono elaborati da Apple App Store o Google Play. Puoi gestire o annullare l’abbonamento nelle impostazioni dell’account dello store.",
                "La fatturazione alternativa con Stripe viene completata nell’app e potrebbe richiedere ulteriori informative del fornitore in base alla tua area geografica.",
                "I pagamenti Stripe si aprono nel Checkout sicuro ospitato da Stripe. PetMagic non memorizza i dati completi della carta."),
            "pl" => new PaywallLegalTextsResponse(
                "Płatności za subskrypcje w aplikacji są przetwarzane przez Apple App Store lub Google Play. Subskrypcją można zarządzać lub ją anulować w ustawieniach konta w sklepie.",
                "Alternatywne rozliczenie przez Stripe jest realizowane w aplikacji i może wymagać dodatkowych informacji od dostawcy, zależnie od regionu.",
                "Płatności Stripe otwierają się w bezpiecznym Checkout hostowanym przez Stripe. PetMagic nie przechowuje pełnych danych karty."),
            "ru" => new PaywallLegalTextsResponse(
                "Оплата подписок в приложении обрабатывается через Apple App Store или Google Play. Управлять подпиской или отменить её можно в настройках аккаунта соответствующего магазина.",
                "Альтернативная оплата через Stripe завершается внутри приложения и в зависимости от региона может требовать дополнительных раскрытий от платёжного провайдера.",
                "Оплата через Stripe открывается в защищённом Checkout, который размещает Stripe. PetMagic не хранит полные данные банковской карты."),
            _ => new PaywallLegalTextsResponse(
                "Payments for in-app subscriptions are processed by Apple App Store or Google Play. You can manage or cancel your subscription in your store account settings.",
                "Alternative billing with Stripe is completed inside the app and may require additional provider disclosures depending on your region.",
                "Stripe payments open in secure Stripe-hosted Checkout. PetMagic does not store full card details.")
        };
    }

    private static string BuildPaywallStoreNotice(string? locale)
    {
        return BuildPaywallLegalTexts(locale, "web").StoreNotice;
    }

    private static string BuildPaywallExternalCheckoutNotice(string? locale)
    {
        return BuildPaywallLegalTexts(locale, "web").ExternalCheckoutNotice;
    }

    private static string BuildNativeAndroidStripeNotice(string? locale)
    {
        return NormalizePaywallLocale(locale) switch
        {
            "de" => "Stripe-Zahlungen werden in einem sicheren Zahlungsformular innerhalb von PetMagic abgewickelt. PetMagic speichert keine vollständigen Kartendaten.",
            "es" => "Los pagos con Stripe se realizan en un formulario de pago seguro dentro de PetMagic. PetMagic no almacena los datos completos de la tarjeta.",
            "fr" => "Les paiements Stripe sont effectués dans un formulaire de paiement sécurisé au sein de PetMagic. PetMagic ne stocke pas les données complètes de la carte.",
            "it" => "I pagamenti Stripe vengono elaborati in un modulo di pagamento sicuro all’interno di PetMagic. PetMagic non memorizza i dati completi della carta.",
            "pl" => "Płatności Stripe są realizowane w bezpiecznym formularzu płatności wewnątrz PetMagic. PetMagic nie przechowuje pełnych danych karty.",
            "ru" => "Оплата через Stripe проходит в защищённой платёжной форме внутри PetMagic. PetMagic не хранит полные данные банковской карты.",
            _ => "Stripe payments are completed in a secure payment form inside PetMagic. PetMagic does not store full card details."
        };
    }

    private static string NormalizePaywallLocale(string? locale)
    {
        var normalized = locale?.Trim().Replace('_', '-').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return "en";
        }

        var separatorIndex = normalized.IndexOf('-');
        return separatorIndex < 0 ? normalized : normalized[..separatorIndex];
    }

    [GeneratedRegex("\\s+", RegexOptions.CultureInvariant)]
    private static partial Regex WhitespaceRegex();

    [GeneratedRegex("[^A-Z0-9]", RegexOptions.CultureInvariant)]
    private static partial Regex NonAlphanumericRegex();
}
