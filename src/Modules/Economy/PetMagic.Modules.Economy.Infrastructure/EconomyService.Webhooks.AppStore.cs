using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<StoreWebhookResultResponse>> HandleAppStoreServerNotificationAsync(
        AppStoreServerNotificationCommand command,
        CancellationToken cancellationToken)
    {
        var parsed = EconomyWebhookParser.ParseAppStoreServerNotification(command.SignedPayload);
        if (!parsed.Success || string.IsNullOrWhiteSpace(parsed.EventId))
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var appStoreEventType = parsed.NotificationType ?? "unknown";
        var safeAppStoreEventId = EconomyLogSanitizer.SafeExternalId(parsed.EventId) ?? string.Empty;
        LogStoreWebhookReceived("app_store", safeAppStoreEventId, appStoreEventType);

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken)
            : null;

        try
        {
            if (!await TryClaimWebhookEventAsync("app_store", parsed.EventId, appStoreEventType, cancellationToken))
            {
                EconomyMetrics.RecordDuplicateWebhook("app_store", appStoreEventType);
                LogDuplicateStoreWebhook("app_store", parsed.EventId, appStoreEventType);
                return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
            }

            var processedTokenPurchase = false;
            if (string.Equals(parsed.NotificationType, "ONE_TIME_CHARGE", StringComparison.OrdinalIgnoreCase)
                && !string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId)
                && !string.IsNullOrWhiteSpace(parsed.ProductId))
            {
                var pendingCandidates = await dbContext.PurchaseOrders
                    .Join(
                        dbContext.CurrencyPacks,
                        order => order.PackId,
                        pack => pack.Id,
                        (order, pack) => new { order, pack })
                    .Where(x =>
                        x.order.PaymentProvider == "app_store"
                        && x.order.Status == PurchaseOrderStatus.Pending
                        && (x.order.ExternalPaymentId == parsed.ExternalPurchaseId
                            || (x.order.ExternalPaymentId == null
                                && parsed.AppAccountUserId.HasValue
                                && x.order.UserId == parsed.AppAccountUserId.Value)))
                    .OrderByDescending(x => x.order.CreatedAtUtc)
                    .Take(10)
                    .ToListAsync(cancellationToken);

                var productCandidates = pendingCandidates
                    .Where(x => string.Equals(
                        ResolvePackStoreProductId(x.pack, "app_store"),
                        parsed.ProductId,
                        StringComparison.Ordinal))
                    .ToList();
                var pendingOrder = productCandidates.FirstOrDefault(x =>
                        string.Equals(x.order.ExternalPaymentId, parsed.ExternalPurchaseId, StringComparison.Ordinal))
                    ?? (productCandidates.Count == 1 ? productCandidates[0] : null);

                if (pendingOrder is not null)
                {
                    var confirmResult = await ConfirmStorePurchaseInternalAsync(
                        pendingOrder.order,
                        parsed.ExternalPurchaseId,
                        cancellationToken);
                    if (confirmResult.IsFailure
                        && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
                    {
                        return Result.Failure<StoreWebhookResultResponse>(confirmResult.Error);
                    }

                    processedTokenPurchase = true;
                }
            }

            var existingSubscription = await dbContext.UserSubscriptions
                .FirstOrDefaultAsync(
                    x => x.Provider == "app_store"
                        && ((!string.IsNullOrWhiteSpace(parsed.ExternalSubscriptionId) && x.ExternalSubscriptionId == parsed.ExternalSubscriptionId)
                            || (!string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId) && x.ExternalTransactionId == parsed.ExternalPurchaseId)),
                    cancellationToken);

            if (existingSubscription is null)
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                LogStoreWebhookProcessed(
                    "app_store",
                    parsed.EventId,
                    appStoreEventType,
                    null,
                    processedTokenPurchase ? "processed_token_purchase" : "ignored_not_found");
                return Result.Success(new StoreWebhookResultResponse(
                    "app_store",
                    parsed.EventId,
                    processedTokenPurchase,
                    processedTokenPurchase ? "processed_token_purchase" : "ignored_not_found"));
            }

            var plan = await ResolveStoreNotificationPlanAsync(existingSubscription.PlanId, parsed.ProductId, "app_store", cancellationToken);
            if (plan is null)
            {
                return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
            }

            var currentPeriodEndUtc = parsed.ExpiresAtUtc;
            var status = EconomyWebhookParser.NormalizeStoreSubscriptionStatus(
                EconomyWebhookParser.MapAppStoreNotificationStatus(parsed.NotificationType, parsed.Subtype, currentPeriodEndUtc),
                currentPeriodEndUtc);
            var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, currentPeriodEndUtc);

            var subscriptionResult = await UpsertUserSubscriptionAsync(
                existingSubscription.UserId,
                "app_store",
                existingSubscription.PurchaseChannel,
                existingSubscription.Region,
                plan.PlanCode,
                status,
                existingSubscription.ExternalCustomerId,
                parsed.ExternalSubscriptionId ?? existingSubscription.ExternalSubscriptionId,
                parsed.ExternalPurchaseId ?? existingSubscription.ExternalTransactionId,
                ResolveNotificationPeriodStartUtc(plan.BillingPeriod, currentPeriodEndUtc, existingSubscription.CurrentPeriodStartUtc),
                currentPeriodEndUtc,
                parsed.CancelAtPeriodEnd,
                plan.MonthlyTokenLimit,
                cancellationToken);
            if (subscriptionResult.IsFailure)
            {
                return Result.Failure<StoreWebhookResultResponse>(subscriptionResult.Error);
            }
            var subscription = subscriptionResult.Value;

            await AppendSubscriptionEventAsync(
                existingSubscription.UserId,
                subscription.Id,
                "app_store",
                parsed.NotificationType ?? "AppStoreNotification",
                subscription.Status,
                parsed.EventId,
                subscription.ExternalSubscriptionId,
                BuildSafeAppStoreWebhookPayloadMetadata(parsed),
                cancellationToken);

            LogSubscriptionUpdated(
                "app_store",
                parsed.EventId,
                appStoreEventType,
                existingSubscription.UserId,
                subscription.Status,
                isPremium ? "activated" : "canceled");

            if (isPremium)
            {
                await GrantPremiumSubscriptionAllowanceIfDueAsync(
                    subscription,
                    "app_store",
                    cancellationToken);
            }

            await _pushNotificationSender.NotifyPremiumUpdateAsync(
                existingSubscription.UserId,
                new PremiumPushNotification(
                    Status: isPremium ? "active" : "inactive",
                    Provider: "app_store",
                    PlanCode: plan.PlanCode,
                    EventKey: SafeLogValues.StableHash(parsed.EventId)),
                cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            var premiumSyncResult = await SynchronizePremiumEntitlementAsync(
                existingSubscription.UserId,
                isPremium,
                "app_store",
                parsed.NotificationType ?? "AppStoreNotification",
                subscription.Id,
                subscription.ExternalSubscriptionId,
                cancellationToken);
            _ = premiumSyncResult;

            LogStoreWebhookProcessed("app_store", parsed.EventId, appStoreEventType, existingSubscription.UserId, "processed");
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            EconomyMetrics.RecordDuplicateWebhook("app_store", appStoreEventType);
            LogDuplicateStoreWebhook("app_store", parsed.EventId, appStoreEventType);
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
        }
    }
}
