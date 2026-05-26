using System.Data;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<UserSubscription?> GetLatestUserSubscriptionAsync(Guid userId, CancellationToken cancellationToken)
    {
        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<UserSubscription> UpsertUserSubscriptionAsync(
        Guid userId,
        string provider,
        string purchaseChannel,
        string region,
        string planId,
        string status,
        string? externalCustomerId,
        string? externalSubscriptionId,
        string? externalTransactionId,
        DateTime? currentPeriodStartUtc,
        DateTime? currentPeriodEndUtc,
        bool cancelAtPeriodEnd,
        int monthlyTokenLimit,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var subscription = await dbContext.UserSubscriptions.FirstOrDefaultAsync(
            x => x.UserId == userId
                && ((!string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.ExternalSubscriptionId == externalSubscriptionId)
                    || (string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.PlanId == planId)),
            cancellationToken);

        var normalizedStatus = status.Trim();
        var previousPeriodStartUtc = subscription?.CurrentPeriodStartUtc;
        var previousTokensGranted = subscription?.MonthlyTokensGranted ?? 0;

        if (subscription is null)
        {
            subscription = new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = provider,
                CreatedAtUtc = now
            };

            dbContext.UserSubscriptions.Add(subscription);
        }

        subscription.PurchaseChannel = purchaseChannel;
        subscription.Region = region;
        subscription.PlanId = planId;
        subscription.Status = normalizedStatus;
        subscription.ExternalCustomerId = externalCustomerId ?? subscription.ExternalCustomerId;
        subscription.ExternalSubscriptionId = externalSubscriptionId ?? subscription.ExternalSubscriptionId;
        subscription.ExternalTransactionId = externalTransactionId ?? subscription.ExternalTransactionId;

        if (currentPeriodStartUtc.HasValue
            && (!previousPeriodStartUtc.HasValue || currentPeriodStartUtc.Value > previousPeriodStartUtc.Value))
        {
            subscription.MonthlyTokensGranted = 0;
            subscription.LastTokenGrantAtUtc = null;
        }

        subscription.CurrentPeriodStartUtc = currentPeriodStartUtc ?? subscription.CurrentPeriodStartUtc;
        subscription.CurrentPeriodEndUtc = currentPeriodEndUtc ?? subscription.CurrentPeriodEndUtc;
        subscription.CancelAtPeriodEnd = cancelAtPeriodEnd;
        subscription.MonthlyTokenLimit = monthlyTokenLimit;
        subscription.UpdatedAtUtc = now;

        if (ShouldGrantSubscriptionTokens(subscription, previousPeriodStartUtc, previousTokensGranted))
        {
            var wallet = await GetOrCreateWalletAsync(userId, cancellationToken);
            ApplyWalletDelta(
                wallet,
                monthlyTokenLimit,
                WalletLedgerSource.PremiumSubscriptionGrant,
                $"subscription:{provider}:{planId}",
                now);
            subscription.MonthlyTokensGranted += monthlyTokenLimit;
            subscription.LastTokenGrantAtUtc = now;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return subscription;
    }

    private async Task AppendSubscriptionEventAsync(
        Guid userId,
        Guid subscriptionId,
        string provider,
        string eventType,
        string status,
        string? externalEventId,
        string? externalSubscriptionId,
        string? payloadJson,
        CancellationToken cancellationToken)
    {
        dbContext.SubscriptionEventLogs.Add(new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscriptionId,
            Provider = provider,
            EventType = eventType,
            Status = status,
            ExternalEventId = externalEventId,
            ExternalSubscriptionId = externalSubscriptionId,
            PayloadJson = payloadJson,
            CreatedAtUtc = DateTime.UtcNow,
            ProcessedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static bool IsActivePremiumSubscription(UserSubscription? subscription)
    {
        if (subscription is null)
        {
            return false;
        }

        var status = subscription.Status;
        if (!string.Equals(status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "GracePeriod", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc >= DateTime.UtcNow;
    }

    private static string GetManageSubscriptionAction(string? provider)
    {
        return provider switch
        {
            "app_store" => "AppleSettings",
            "google_play" => "GooglePlaySettings",
            "stripe" => "StripeCustomerPortal",
            _ => "None"
        };
    }

    private async Task<ResolvedPremiumPlan?> ResolveConfiguredPremiumPlanAsync(string? planCode, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(planCode))
        {
            return null;
        }

        var normalizedPlanCode = planCode.Trim().ToLowerInvariant();
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == normalizedPlanCode && x.IsActive, cancellationToken);

        if (configuredPlan is not null)
        {
            return new ResolvedPremiumPlan(
                configuredPlan.Id,
                configuredPlan.Name,
                ToStripeBillingInterval(configuredPlan.BillingPeriod),
                configuredPlan.BillingPeriod,
                configuredPlan.PriceAmount,
                configuredPlan.CurrencyCode,
                configuredPlan.MonthlyTokenLimit,
                configuredPlan.GoogleProductId,
                configuredPlan.AppleProductId);
        }

        var catalogPlan = PremiumPlanCatalog.Find(normalizedPlanCode);
        if (catalogPlan is null)
        {
            return null;
        }

        return new ResolvedPremiumPlan(
            catalogPlan.PlanCode,
            catalogPlan.ProductName,
            catalogPlan.BillingInterval,
            catalogPlan.BillingInterval == "year" ? "yearly" : "monthly",
            catalogPlan.PriceAmount,
            catalogPlan.CurrencyCode,
            catalogPlan.TokenAllowance,
            catalogPlan.GooglePlayProductId,
            catalogPlan.AppStoreProductId);
    }

    private async Task<(ResolvedPremiumPlan? Plan, UserSubscription? ExistingSubscription)> ResolveStripePlanContextAsync(
        Guid userId,
        string? planCode,
        string? subscriptionId,
        CancellationToken cancellationToken)
    {
        UserSubscription? existingSubscription = null;
        if (!string.IsNullOrWhiteSpace(subscriptionId))
        {
            existingSubscription = await dbContext.UserSubscriptions
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.UserId == userId && x.Provider == "stripe" && x.ExternalSubscriptionId == subscriptionId,
                    cancellationToken);
        }

        var plan = await ResolveConfiguredPremiumPlanAsync(planCode, cancellationToken);
        if (plan is null && !string.IsNullOrWhiteSpace(existingSubscription?.PlanId))
        {
            plan = await ResolveConfiguredPremiumPlanAsync(existingSubscription.PlanId, cancellationToken);
        }

        return (plan, existingSubscription);
    }

    private async Task<ResolvedPremiumPlan?> ResolveStoreNotificationPlanAsync(
        string? existingPlanId,
        string? productId,
        string provider,
        CancellationToken cancellationToken)
    {
        var plan = await ResolveStoredPremiumPlanAsync(existingPlanId, cancellationToken);
        if (plan is not null)
        {
            return plan;
        }

        if (string.IsNullOrWhiteSpace(productId))
        {
            return null;
        }

        var normalizedProductId = productId.Trim();
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
        if (string.IsNullOrWhiteSpace(planCode))
        {
            return null;
        }

        var normalizedPlanCode = planCode.Trim().ToLowerInvariant();
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

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(SubscriptionPlan configuredPlan)
    {
        return new ResolvedPremiumPlan(
            configuredPlan.Id,
            configuredPlan.Name,
            ToStripeBillingInterval(configuredPlan.BillingPeriod),
            configuredPlan.BillingPeriod,
            configuredPlan.PriceAmount,
            configuredPlan.CurrencyCode,
            configuredPlan.MonthlyTokenLimit,
            configuredPlan.GoogleProductId,
            configuredPlan.AppleProductId);
    }

    private static ResolvedPremiumPlan ToResolvedPremiumPlan(PremiumPlanDefinition catalogPlan)
    {
        return new ResolvedPremiumPlan(
            catalogPlan.PlanCode,
            catalogPlan.ProductName,
            catalogPlan.BillingInterval,
            catalogPlan.BillingInterval == "year" ? "yearly" : "monthly",
            catalogPlan.PriceAmount,
            catalogPlan.CurrencyCode,
            catalogPlan.TokenAllowance,
            catalogPlan.GooglePlayProductId,
            catalogPlan.AppStoreProductId);
    }

    private static string ToStripeBillingInterval(string billingPeriod)
    {
        return string.Equals(billingPeriod, "yearly", StringComparison.OrdinalIgnoreCase)
            ? "year"
            : "month";
    }

    private static DateTime DeriveCurrentPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime fallbackUtc)
    {
        if (!currentPeriodEndUtc.HasValue)
        {
            return fallbackUtc;
        }

        return string.Equals(billingPeriod, "yearly", StringComparison.OrdinalIgnoreCase)
            ? currentPeriodEndUtc.Value.AddYears(-1)
            : currentPeriodEndUtc.Value.AddMonths(-1);
    }

    private static bool ShouldGrantSubscriptionTokens(
        UserSubscription subscription,
        DateTime? previousPeriodStartUtc,
        int previousTokensGranted)
    {
        if (subscription.MonthlyTokenLimit <= 0)
        {
            return false;
        }

        if (!string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(subscription.Status, "GracePeriod", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (subscription.LastTokenGrantAtUtc is null && previousTokensGranted <= 0)
        {
            return true;
        }

        return subscription.CurrentPeriodStartUtc.HasValue
            && (!previousPeriodStartUtc.HasValue || subscription.CurrentPeriodStartUtc.Value > previousPeriodStartUtc.Value)
            && subscription.MonthlyTokensGranted < subscription.MonthlyTokenLimit;
    }

    private async Task<PaymentProviderConfiguration?> ResolveEnabledPaymentProviderConfigAsync(
        string provider,
        string platform,
        string country,
        string appVersion,
        CancellationToken cancellationToken)
    {
        var normalizedPlatform = EconomyPaymentProviderPolicy.NormalizePlatform(platform);
        var normalizedRegion = EconomyPaymentProviderPolicy.NormalizeRegion(country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(normalizedRegion);
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var config = EconomyPaymentProviderPolicy.SelectProviderConfig(
            configs,
            provider,
            normalizedPlatform,
            normalizedRegion,
            isEuRegion,
            appVersion);

        if (config is null)
        {
            return null;
        }

        if (!EconomyPaymentProviderPolicy.IsProviderAllowedForCheckout(provider, normalizedPlatform, config))
        {
            return null;
        }

        if (string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            && !IsStripeModeConfigured(config.Mode))
        {
            return null;
        }

        return config;
    }

    private bool HasAnyStripeSecretKey()
    {
        return !string.IsNullOrWhiteSpace(ResolveStripeApiKey());
    }

    private bool IsStripeModeConfigured(string? mode)
    {
        return !string.IsNullOrWhiteSpace(ResolveStripeApiKey(mode));
    }

    private string? ResolveStripeApiKey(string? mode = null)
    {
        var normalizedMode = mode is null ? null : EconomyPaymentProviderPolicy.NormalizeMode(mode);
        return normalizedMode switch
        {
            "live" => FirstNonEmpty(options.Value.StripeLiveSecretKey, options.Value.StripeSecretKey),
            "test" => FirstNonEmpty(options.Value.StripeTestSecretKey, options.Value.StripeSecretKey),
            _ => FirstNonEmpty(options.Value.StripeSecretKey, options.Value.StripeLiveSecretKey, options.Value.StripeTestSecretKey)
        };
    }

    private IReadOnlyList<string> ResolveStripeWebhookSecrets()
    {
        var secrets = new List<string>();
        AppendIfNotEmpty(secrets, options.Value.StripeWebhookSecret);
        AppendIfNotEmpty(secrets, options.Value.StripeLiveWebhookSecret);
        AppendIfNotEmpty(secrets, options.Value.StripeTestWebhookSecret);
        return secrets;
    }

    private static void AppendIfNotEmpty(ICollection<string> values, string? candidate)
    {
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return;
        }

        if (values.Contains(candidate))
        {
            return;
        }

        values.Add(candidate);
    }

    private static string? FirstNonEmpty(params string?[] candidates)
    {
        return candidates.FirstOrDefault(candidate => !string.IsNullOrWhiteSpace(candidate));
    }

    private async Task<bool> IsPaymentProviderAllowedAsync(
        string provider,
        string platform,
        string country,
        string appVersion,
        CancellationToken cancellationToken)
    {
        var configuration = await ResolveEnabledPaymentProviderConfigAsync(provider, platform, country, appVersion, cancellationToken);
        return configuration is not null;
    }

    private static DateTime? ResolveNotificationPeriodStartUtc(string billingPeriod, DateTime? currentPeriodEndUtc, DateTime? fallbackPeriodStartUtc)
    {
        if (currentPeriodEndUtc.HasValue)
        {
            return DeriveCurrentPeriodStartUtc(billingPeriod, currentPeriodEndUtc, currentPeriodEndUtc.Value);
        }

        return fallbackPeriodStartUtc;
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private sealed record ResolvedPremiumPlan(
        string PlanCode,
        string ProductName,
        string BillingInterval,
        string BillingPeriod,
        decimal PriceAmount,
        string CurrencyCode,
        int MonthlyTokenLimit,
        string? GoogleProductId,
        string? AppleProductId);
}
