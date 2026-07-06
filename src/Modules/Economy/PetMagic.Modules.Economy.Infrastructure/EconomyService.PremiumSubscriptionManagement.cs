using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<SubscriptionSummaryResponse>> CancelPremiumSubscriptionAsync(
        CancelPremiumSubscriptionCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        var subscription = await dbContext.UserSubscriptions
            .Where(x => x.UserId == command.UserId && x.Provider == "stripe")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (subscription is null || string.IsNullOrWhiteSpace(subscription.ExternalSubscriptionId))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var stripeApiKey = ResolveStripeApiKey();
        if (string.IsNullOrWhiteSpace(stripeApiKey))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var stripeClient = CreateStripeClient(stripeApiKey);

        try
        {
            await CancelStripeSubscriptionAsync(
                stripeClient,
                subscription.ExternalSubscriptionId,
                cancelImmediately: false,
                cancellationToken);
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                "Failed to request cancel_at_period_end for Stripe subscription. SubscriptionIdSafe={SubscriptionIdSafe} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId),
                SafeLogValues.ExceptionType(ex),
                CurrentCorrelationIdHash);

            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
        }

        subscription.CancelAtPeriodEnd = true;
        if (string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase)
            || string.Equals(subscription.Status, "GracePeriod", StringComparison.OrdinalIgnoreCase))
        {
            subscription.Status = "Canceled";
        }

        subscription.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        await AppendSubscriptionEventAsync(
            command.UserId,
            subscription.Id,
            "stripe",
            "CancelAtPeriodEndRequested",
            subscription.Status,
            null,
            subscription.ExternalSubscriptionId,
            null,
            cancellationToken);

        return await GetSubscriptionSummaryAsync(command.UserId, cancellationToken);
    }

    public async Task<Result<SubscriptionSummaryResponse>> AdminRevokePremiumSubscriptionAsync(
        AdminRevokePremiumSubscriptionCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.PaymentProvider.Trim().ToLowerInvariant();
        if (!string.Equals(provider, "stripe", StringComparison.Ordinal))
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.UnsupportedPaymentProvider);
        }

        if (identityService is null)
        {
            return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
        }

        var subscription = await dbContext.UserSubscriptions
            .Where(x => x.UserId == command.UserId && x.Provider == "stripe")
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        var previousSubscriptionStatus = subscription?.Status;
        if (subscription is not null && !string.IsNullOrWhiteSpace(subscription.ExternalSubscriptionId))
        {
            var stripeApiKey = ResolveStripeApiKey();
            if (string.IsNullOrWhiteSpace(stripeApiKey))
            {
                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PremiumBillingUnavailable);
            }

            var stripeClient = CreateStripeClient(stripeApiKey);

            try
            {
                await CancelStripeSubscriptionAsync(
                    stripeClient,
                    subscription.ExternalSubscriptionId,
                    cancelImmediately: true,
                    cancellationToken);
            }
            catch (Exception ex)
            {
                logger?.LogWarning(
                    "Failed to immediately cancel Stripe subscription for admin premium revoke. SubscriptionIdSafe={SubscriptionIdSafe} ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                    EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId),
                    SafeLogValues.ExceptionType(ex),
                    CurrentCorrelationIdHash);

                return Result.Failure<SubscriptionSummaryResponse>(EconomyErrors.PaymentGatewayFailed);
            }

        }

        if (subscription is not null)
        {
            subscription.CancelAtPeriodEnd = false;
            subscription.Status = "Expired";
            if (subscription.CurrentPeriodEndUtc is null || subscription.CurrentPeriodEndUtc > DateTime.UtcNow)
            {
                subscription.CurrentPeriodEndUtc = DateTime.UtcNow;
            }

            subscription.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            await AppendSubscriptionEventAsync(
                command.UserId,
                subscription.Id,
                "stripe",
                "AdminImmediateCancelRequested",
                subscription.Status,
                null,
                subscription.ExternalSubscriptionId,
                null,
                cancellationToken);

            if (adminAuditLog is not null)
            {
                await adminAuditLog.WriteAsync(
                    new AdminAuditEntry(
                        "admin.subscription.canceled",
                        "subscription",
                        subscription.Id.ToString("D"),
                        previousSubscriptionStatus,
                        subscription.Status,
                        SubjectUserId: command.UserId),
                    cancellationToken);
            }
        }

        var premiumSyncResult = await SynchronizePremiumEntitlementAsync(
            command.UserId,
            false,
            "stripe",
            "AdminImmediateCancelRequested",
            subscription?.Id,
            subscription?.ExternalSubscriptionId,
            cancellationToken);
        if (premiumSyncResult.IsFailure)
        {
            return Result.Failure<SubscriptionSummaryResponse>(premiumSyncResult.Error);
        }

        return await GetSubscriptionSummaryAsync(command.UserId, cancellationToken);
    }

    private static Task<Subscription> CancelStripeSubscriptionAsync(
        IStripeClient stripeClient,
        string externalSubscriptionId,
        bool cancelImmediately,
        CancellationToken cancellationToken)
    {
        var subscriptionService = new SubscriptionService(stripeClient);
        if (cancelImmediately)
        {
            return subscriptionService.CancelAsync(
                externalSubscriptionId,
                cancellationToken: cancellationToken);
        }

        return subscriptionService.UpdateAsync(
            externalSubscriptionId,
            new SubscriptionUpdateOptions
            {
                CancelAtPeriodEnd = true
            },
            cancellationToken: cancellationToken);
    }
}
