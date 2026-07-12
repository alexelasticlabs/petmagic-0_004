using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
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

    private async Task<Result<UserSubscription>> UpsertUserSubscriptionAsync(
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
        CancellationToken cancellationToken,
        string? legacyExternalTransactionId = null)
    {
        var now = DateTime.UtcNow;
        var subscription = await dbContext.UserSubscriptions.FirstOrDefaultAsync(
            x => x.UserId == userId
                && ((!string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.ExternalSubscriptionId == externalSubscriptionId)
                    || (string.IsNullOrWhiteSpace(externalSubscriptionId) && x.Provider == provider && x.PlanId == planId)),
            cancellationToken);

        var normalizedStatus = status.Trim();
        var previousPeriodStartUtc = subscription?.CurrentPeriodStartUtc;

        var ownershipCheck = await EnsureSubscriptionOwnershipAvailableAsync(
            userId,
            provider,
            externalCustomerId,
            externalSubscriptionId,
            externalTransactionId,
            subscription?.Id,
            cancellationToken,
            legacyExternalTransactionId);
        if (ownershipCheck.IsFailure)
        {
            return Result.Failure<UserSubscription>(ownershipCheck.Error);
        }

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

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsSubscriptionOwnershipUniqueViolation(exception))
        {
            // Concurrent redemption of the same store receipt/subscription by another account lost
            // the race against the unique (Provider, ExternalSubscriptionId/ExternalTransactionId)
            // indexes. Surface the same ownership-conflict error as the pre-check instead of a 500.
            dbContext.ChangeTracker.Clear();
            return Result.Failure<UserSubscription>(EconomyErrors.SubscriptionOwnershipConflict);
        }

        return Result.Success(subscription);
    }

    private static bool IsSubscriptionOwnershipUniqueViolation(DbUpdateException exception)
    {
        return exception.InnerException is Npgsql.PostgresException
        {
            SqlState: Npgsql.PostgresErrorCodes.UniqueViolation,
            ConstraintName: { } constraintName
        }
            && (constraintName.Contains("economy_user_subscriptions", StringComparison.OrdinalIgnoreCase)
                || constraintName.StartsWith("UX_eus_", StringComparison.OrdinalIgnoreCase));
    }

    private async Task<bool> StoreSubscriptionBelongsToAnotherUserAsync(
        Guid userId,
        string provider,
        string? externalSubscriptionId,
        string? externalTransactionId,
        CancellationToken cancellationToken,
        string? legacyExternalTransactionId = null)
    {
        var normalizedExternalSubscriptionId = string.IsNullOrWhiteSpace(externalSubscriptionId)
            ? null
            : externalSubscriptionId.Trim();
        var normalizedExternalTransactionId = string.IsNullOrWhiteSpace(externalTransactionId)
            ? null
            : externalTransactionId.Trim();
        var normalizedLegacyExternalTransactionId = string.IsNullOrWhiteSpace(legacyExternalTransactionId)
            ? null
            : legacyExternalTransactionId.Trim();
        if (string.Equals(normalizedLegacyExternalTransactionId, normalizedExternalTransactionId, StringComparison.Ordinal))
        {
            normalizedLegacyExternalTransactionId = null;
        }

        if (normalizedExternalSubscriptionId is null
            && normalizedExternalTransactionId is null
            && normalizedLegacyExternalTransactionId is null)
        {
            return false;
        }

        return await dbContext.UserSubscriptions
            .AsNoTracking()
            .AnyAsync(
                x => x.Provider == provider
                    && x.UserId != userId
                    && ((normalizedExternalSubscriptionId != null && x.ExternalSubscriptionId == normalizedExternalSubscriptionId)
                        || (normalizedExternalTransactionId != null && x.ExternalTransactionId == normalizedExternalTransactionId)
                        || (normalizedLegacyExternalTransactionId != null && x.ExternalTransactionId == normalizedLegacyExternalTransactionId)),
                cancellationToken);
    }

    private async Task<Result> EnsureSubscriptionOwnershipAvailableAsync(
        Guid userId,
        string provider,
        string? externalCustomerId,
        string? externalSubscriptionId,
        string? externalTransactionId,
        Guid? currentSubscriptionId,
        CancellationToken cancellationToken,
        string? legacyExternalTransactionId = null)
    {
        var normalizedExternalCustomerId = string.IsNullOrWhiteSpace(externalCustomerId)
            ? null
            : externalCustomerId.Trim();
        var normalizedExternalSubscriptionId = string.IsNullOrWhiteSpace(externalSubscriptionId)
            ? null
            : externalSubscriptionId.Trim();
        var normalizedExternalTransactionId = string.IsNullOrWhiteSpace(externalTransactionId)
            ? null
            : externalTransactionId.Trim();
        var normalizedLegacyExternalTransactionId = string.IsNullOrWhiteSpace(legacyExternalTransactionId)
            ? null
            : legacyExternalTransactionId.Trim();
        if (string.Equals(normalizedLegacyExternalTransactionId, normalizedExternalTransactionId, StringComparison.Ordinal))
        {
            normalizedLegacyExternalTransactionId = null;
        }

        if (normalizedExternalCustomerId is null
            && normalizedExternalSubscriptionId is null
            && normalizedExternalTransactionId is null
            && normalizedLegacyExternalTransactionId is null)
        {
            return Result.Success();
        }

        var conflictingSubscriptionExists = await dbContext.UserSubscriptions
            .AsNoTracking()
            .AnyAsync(
                x => x.Provider == provider
                    && x.UserId != userId
                    && (!currentSubscriptionId.HasValue || x.Id != currentSubscriptionId.Value)
                    && ((normalizedExternalCustomerId != null && x.ExternalCustomerId == normalizedExternalCustomerId)
                        || (normalizedExternalSubscriptionId != null && x.ExternalSubscriptionId == normalizedExternalSubscriptionId)
                        || (normalizedExternalTransactionId != null && x.ExternalTransactionId == normalizedExternalTransactionId)
                        || (normalizedLegacyExternalTransactionId != null && x.ExternalTransactionId == normalizedLegacyExternalTransactionId)),
                cancellationToken);
        if (conflictingSubscriptionExists)
        {
            return Result.Failure(EconomyErrors.SubscriptionOwnershipConflict);
        }

        if (string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            && normalizedExternalCustomerId is not null)
        {
            var conflictingCustomerExists = await dbContext.PaymentCustomers
                .AsNoTracking()
                .AnyAsync(
                    x => x.Provider == provider
                        && x.UserId != userId
                        && x.ExternalCustomerId == normalizedExternalCustomerId,
                    cancellationToken);
            if (conflictingCustomerExists)
            {
                return Result.Failure(EconomyErrors.SubscriptionOwnershipConflict);
            }
        }

        return Result.Success();
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

        var catalogPlan = PremiumPlanCatalog.Find(options.Value, planId);
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
            PayloadJson = SanitizeSubscriptionEventPayloadJson(payloadJson),
            CreatedAtUtc = DateTime.UtcNow,
            ProcessedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static string? SerializeSafeSubscriptionEventPayload(object? payload)
    {
        return payload is null
            ? null
            : SanitizeSubscriptionEventPayloadJson(JsonSerializer.Serialize(payload));
    }

    private static string? SanitizeSubscriptionEventPayloadJson(string? payloadJson)
    {
        return SanitizeWebhookPayloadSnapshot(payloadJson);
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
