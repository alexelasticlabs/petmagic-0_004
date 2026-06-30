using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<ResolvedPremiumPlan?> ResolveConfiguredPremiumPlanAsync(string? planCode, CancellationToken cancellationToken)
    {
        var normalizedPlanCode = NullIfWhiteSpace(planCode)?.ToLowerInvariant();
        if (normalizedPlanCode is null)
        {
            return null;
        }

        var configuredPlan = await ResolveStoredPremiumPlanAsync(normalizedPlanCode, cancellationToken);
        if (configuredPlan is not null)
        {
            return configuredPlan;
        }

        var catalogPlan = PremiumPlanCatalog.Find(normalizedPlanCode);
        return catalogPlan is null ? null : ToResolvedPremiumPlan(catalogPlan);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoreNotificationPlanAsync(
        string? planCode,
        string? productId,
        string provider,
        CancellationToken cancellationToken)
    {
        var storedPlan = await ResolveStoredPremiumPlanAsync(planCode, cancellationToken);
        if (storedPlan is not null)
        {
            return storedPlan;
        }

        var normalizedProductId = NullIfWhiteSpace(productId);
        if (normalizedProductId is null)
        {
            return null;
        }

        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => provider == "app_store"
                    ? x.AppleProductId == normalizedProductId
                    : x.GoogleProductId == normalizedProductId,
                cancellationToken);

        if (configuredPlan is not null)
        {
            return ToResolvedPremiumPlan(configuredPlan);
        }

        var catalogPlan = PremiumPlanCatalog.All.FirstOrDefault(
            x => string.Equals(
                provider == "app_store" ? x.AppStoreProductId : x.GooglePlayProductId,
                normalizedProductId,
                StringComparison.Ordinal));

        return catalogPlan is null ? null : ToResolvedPremiumPlan(catalogPlan);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoredPremiumPlanAsync(string? planCode, CancellationToken cancellationToken)
    {
        var normalizedPlanCode = NullIfWhiteSpace(planCode)?.ToLowerInvariant();
        if (normalizedPlanCode is null)
        {
            return null;
        }

        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == normalizedPlanCode, cancellationToken);

        if (configuredPlan is not null)
        {
            return ToResolvedPremiumPlan(configuredPlan);
        }

        var catalogPlan = PremiumPlanCatalog.Find(normalizedPlanCode);
        return catalogPlan is null ? null : ToResolvedPremiumPlan(catalogPlan);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoredPremiumPlanByStripePriceIdAsync(string? stripePriceId, CancellationToken cancellationToken)
    {
        var normalizedStripePriceId = NullIfWhiteSpace(stripePriceId);
        if (normalizedStripePriceId is null)
        {
            return null;
        }

        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.StripePriceId == normalizedStripePriceId, cancellationToken);

        return configuredPlan is null ? null : ToResolvedPremiumPlan(configuredPlan);
    }

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(SubscriptionPlan configuredPlan)
    {
        return new ResolvedPremiumPlan(
            configuredPlan.Id,
            configuredPlan.Name,
            configuredPlan.PriceAmount,
            configuredPlan.CurrencyCode,
            configuredPlan.MonthlyTokenLimit,
            configuredPlan.BillingPeriod,
            ToStripeBillingInterval(configuredPlan.BillingPeriod),
            configuredPlan.StripePriceId,
            configuredPlan.GoogleProductId,
            configuredPlan.AppleProductId);
    }

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(PremiumPlanDefinition catalogPlan)
    {
        return new ResolvedPremiumPlan(
            catalogPlan.PlanCode,
            catalogPlan.ProductName,
            catalogPlan.PriceAmount,
            catalogPlan.CurrencyCode,
            catalogPlan.TokenAllowance,
            ToBillingPeriod(catalogPlan.BillingInterval),
            catalogPlan.BillingInterval,
            null,
            catalogPlan.GooglePlayProductId,
            catalogPlan.AppStoreProductId);
    }

    private static string ToStripeBillingInterval(string billingPeriod)
    {
        return billingPeriod.Trim().ToLowerInvariant() switch
        {
            "yearly" or "year" => "year",
            _ => "month"
        };
    }

    private async Task<PaymentProviderConfiguration?> ResolveEnabledPaymentProviderConfigAsync(
        string provider,
        string? platform,
        string? country,
        string? appVersion,
        CancellationToken cancellationToken)
    {
        var normalizedPlatform = EconomyPaymentProviderPolicy.NormalizePlatform(platform ?? "web");
        var normalizedRegion = EconomyPaymentProviderPolicy.NormalizeRegion(country ?? "*");
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(normalizedRegion);
        var normalizedAppVersion = string.IsNullOrWhiteSpace(appVersion) ? "0.0.0" : appVersion.Trim();

        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.Provider == provider && x.IsEnabled)
            .ToListAsync(cancellationToken);

        return EconomyPaymentProviderPolicy.SelectProviderConfig(
            configs,
            provider,
            normalizedPlatform,
            normalizedRegion,
            isEuRegion,
            normalizedAppVersion);
    }

    private bool HasAnyStripeSecretKey()
    {
        return !string.IsNullOrWhiteSpace(options.Value.StripeLiveSecretKey)
            || !string.IsNullOrWhiteSpace(options.Value.StripeTestSecretKey);
    }

    private bool IsStripeModeConfigured(string? mode)
    {
        return !string.IsNullOrWhiteSpace(ResolveStripeApiKey(mode));
    }

    private string? ResolveStripeApiKey(string? mode = null)
    {
        return string.Equals(mode, "live", StringComparison.OrdinalIgnoreCase)
            ? FirstNonEmpty(options.Value.StripeLiveSecretKey, options.Value.StripeTestSecretKey)
            : FirstNonEmpty(options.Value.StripeTestSecretKey, options.Value.StripeLiveSecretKey);
    }

    private string? ResolveStripePublishableKey(string? mode = null)
    {
        return string.Equals(mode, "live", StringComparison.OrdinalIgnoreCase)
            ? FirstNonEmpty(options.Value.StripeLivePublishableKey, options.Value.StripeTestPublishableKey)
            : FirstNonEmpty(options.Value.StripeTestPublishableKey, options.Value.StripeLivePublishableKey);
    }

    private bool IsStripeMobileModeConfigured(string? mode)
    {
        return !string.IsNullOrWhiteSpace(ResolveStripeApiKey(mode))
            && !string.IsNullOrWhiteSpace(ResolveStripePublishableKey(mode));
    }

    private IReadOnlyList<string> ResolveStripeWebhookSecrets()
    {
        var values = new List<string>();
        AppendIfNotEmpty(values, options.Value.StripeTestWebhookSecret);
        AppendIfNotEmpty(values, options.Value.StripeLiveWebhookSecret);
        return values;
    }

    private static void AppendIfNotEmpty(ICollection<string> values, string? candidate)
    {
        var normalized = NullIfWhiteSpace(candidate);
        if (normalized is not null && !values.Contains(normalized, StringComparer.Ordinal))
        {
            values.Add(normalized);
        }
    }

    private static string? FirstNonEmpty(params string?[] candidates)
    {
        return candidates.Select(NullIfWhiteSpace).FirstOrDefault(x => x is not null);
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrWhiteSpace(trimmed) ? null : trimmed;
    }

    private async Task<(ResolvedPremiumPlan? ResolvedPlan, UserSubscription? ExistingSubscription)> ResolveStripePlanContextAsync(
        Guid userId,
        string? planCode,
        string? stripePriceId,
        string? externalSubscriptionId,
        CancellationToken cancellationToken)
    {
        UserSubscription? existingSubscription = null;
        var normalizedSubscriptionId = NullIfWhiteSpace(externalSubscriptionId);

        if (normalizedSubscriptionId is not null)
        {
            existingSubscription = await dbContext.UserSubscriptions
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == userId
                        && x.Provider == "stripe"
                        && x.ExternalSubscriptionId == normalizedSubscriptionId,
                    cancellationToken);
        }

        existingSubscription ??= await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.Provider == "stripe")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        var resolvedPlan = await ResolveStoredPremiumPlanByStripePriceIdAsync(stripePriceId, cancellationToken)
            ?? await ResolveConfiguredPremiumPlanAsync(planCode ?? existingSubscription?.PlanId, cancellationToken);
        return (resolvedPlan, existingSubscription);
    }

    private async Task<Guid?> ResolveStripeWebhookUserIdAsync(
        string? customerId,
        string? externalSubscriptionId,
        CancellationToken cancellationToken)
    {
        var normalizedSubscriptionId = NullIfWhiteSpace(externalSubscriptionId);
        if (normalizedSubscriptionId is not null)
        {
            var subscriptionUserId = await dbContext.UserSubscriptions
                .AsNoTracking()
                .Where(x => x.Provider == "stripe" && x.ExternalSubscriptionId == normalizedSubscriptionId)
                .Select(x => (Guid?)x.UserId)
                .FirstOrDefaultAsync(cancellationToken);

            if (subscriptionUserId.HasValue)
            {
                return subscriptionUserId.Value;
            }
        }

        var normalizedCustomerId = NullIfWhiteSpace(customerId);
        if (normalizedCustomerId is null)
        {
            return null;
        }

        var paymentCustomerUserId = await dbContext.PaymentCustomers
            .AsNoTracking()
            .Where(x => x.Provider == "stripe" && x.ExternalCustomerId == normalizedCustomerId)
            .Select(x => (Guid?)x.UserId)
            .FirstOrDefaultAsync(cancellationToken);

        if (paymentCustomerUserId.HasValue)
        {
            return paymentCustomerUserId.Value;
        }

        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.Provider == "stripe" && x.ExternalCustomerId == normalizedCustomerId)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .Select(x => (Guid?)x.UserId)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private static string ToBillingPeriod(string billingInterval)
    {
        return billingInterval.Trim().ToLowerInvariant() switch
        {
            "year" => "yearly",
            _ => "monthly"
        };
    }

    private sealed record ResolvedPremiumPlan(
        string PlanCode,
        string ProductName,
        decimal PriceAmount,
        string CurrencyCode,
        int MonthlyTokenLimit,
        string BillingPeriod,
        string BillingInterval,
        string? StripePriceId,
        string? GoogleProductId,
        string? AppleProductId);
}
