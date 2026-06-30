using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private async Task<UserSubscription?> GetLatestUserSubscriptionAsync(Guid userId, CancellationToken cancellationToken)
    {
        var subscriptions = await dbContext.UserSubscriptions
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);

        return subscriptions
            .OrderByDescending(IsActivePremiumSubscription)
            .ThenByDescending(x => x.CurrentPeriodEndUtc ?? DateTime.MinValue)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefault();
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
        subscription.ProductId = await ResolveSubscriptionProductIdAsync(provider, planId, cancellationToken)
            ?? subscription.ProductId;
        subscription.Status = normalizedStatus;
        subscription.ExternalCustomerId = externalCustomerId ?? subscription.ExternalCustomerId;
        subscription.ExternalSubscriptionId = externalSubscriptionId ?? subscription.ExternalSubscriptionId;
        subscription.ExternalTransactionId = externalTransactionId ?? subscription.ExternalTransactionId;
        subscription.LastValidatedAtUtc = now;

        if (string.Equals(normalizedStatus, "Canceled", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedStatus, "Cancelled", StringComparison.OrdinalIgnoreCase))
        {
            subscription.CancelledAtUtc ??= now;
        }
        else if (string.Equals(normalizedStatus, "Active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedStatus, "Trialing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedStatus, "GracePeriod", StringComparison.OrdinalIgnoreCase))
        {
            subscription.CancelledAtUtc = cancelAtPeriodEnd ? subscription.CancelledAtUtc : null;
            subscription.ExpiredAtUtc = null;
        }

        if (string.Equals(normalizedStatus, "Expired", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedStatus, "Refunded", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedStatus, "Revoked", StringComparison.OrdinalIgnoreCase))
        {
            subscription.ExpiredAtUtc ??= now;
        }

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

        await dbContext.SaveChangesAsync(cancellationToken);
        return subscription;
    }

    private async Task<bool> StoreSubscriptionBelongsToAnotherUserAsync(
        Guid userId,
        string provider,
        string? externalSubscriptionId,
        string? externalTransactionId,
        CancellationToken cancellationToken)
    {
        var normalizedExternalSubscriptionId = string.IsNullOrWhiteSpace(externalSubscriptionId)
            ? null
            : externalSubscriptionId.Trim();
        var normalizedExternalTransactionId = string.IsNullOrWhiteSpace(externalTransactionId)
            ? null
            : externalTransactionId.Trim();

        if (normalizedExternalSubscriptionId is null && normalizedExternalTransactionId is null)
        {
            return false;
        }

        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .AnyAsync(
                x => x.Provider == provider
                    && x.UserId != userId
                    && ((normalizedExternalSubscriptionId != null && x.ExternalSubscriptionId == normalizedExternalSubscriptionId)
                        || (normalizedExternalTransactionId != null && x.ExternalTransactionId == normalizedExternalTransactionId)),
                cancellationToken);
    }

    private async Task<string?> ResolveSubscriptionProductIdAsync(
        string provider,
        string planId,
        CancellationToken cancellationToken)
    {
        var configuredPlan = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == planId, cancellationToken);

        if (configuredPlan is not null)
        {
            return provider switch
            {
                "google_play" => configuredPlan.GoogleProductId,
                "app_store" => configuredPlan.AppleProductId,
                "stripe" => configuredPlan.StripePriceId,
                _ => null
            };
        }

        var catalogPlan = PremiumPlanCatalog.Find(planId);
        if (catalogPlan is null)
        {
            return null;
        }

        return provider switch
        {
            "google_play" => catalogPlan.GooglePlayProductId,
            "app_store" => catalogPlan.AppStoreProductId,
            _ => null
        };
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
            && !string.Equals(status, "PastDue", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        if (string.Equals(status, "PastDue", StringComparison.OrdinalIgnoreCase)
            || string.Equals(status, "Canceled", StringComparison.OrdinalIgnoreCase))
        {
            return subscription.CurrentPeriodEndUtc.HasValue
                && subscription.CurrentPeriodEndUtc.Value >= DateTime.UtcNow;
        }

        return subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc >= DateTime.UtcNow;
    }
}
