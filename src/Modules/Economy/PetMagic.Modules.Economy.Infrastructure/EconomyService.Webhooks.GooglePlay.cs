using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<StoreWebhookResultResponse>> HandleGooglePlayDeveloperNotificationAsync(
        GooglePlayDeveloperNotificationCommand command,
        CancellationToken cancellationToken)
    {
        var parsed = EconomyWebhookParser.ParseGooglePlayDeveloperNotification(command.MessageData, command.MessageId);
        if (!parsed.Success || string.IsNullOrWhiteSpace(parsed.EventId))
        {
            return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.InvalidWebhookPayload);
        }

        var googlePlayEventType = $"notification_{parsed.NotificationType}";
        var safeGooglePlayEventId = EconomyLogSanitizer.SafeExternalId(parsed.EventId) ?? string.Empty;
        LogStoreWebhookReceived("google_play", safeGooglePlayEventId, googlePlayEventType);

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken)
            : null;

        try
        {
            if (!await TryClaimWebhookEventAsync("google_play", parsed.EventId, googlePlayEventType, cancellationToken))
            {
                EconomyMetrics.RecordDuplicateWebhook("google_play", googlePlayEventType);
                LogDuplicateStoreWebhook("google_play", parsed.EventId, googlePlayEventType);
                return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
            }

            if (parsed.IsOneTimeProductNotification)
            {
                var purchaseTokenExternalPaymentId = string.IsNullOrWhiteSpace(parsed.PurchaseToken)
                    ? null
                    : ResolveStoreExternalPaymentId("google_play", parsed.PurchaseToken, null, parsed.PurchaseToken);
                var legacyPurchaseTokenExternalPaymentId = string.IsNullOrWhiteSpace(parsed.PurchaseToken)
                    ? null
                    : ResolveLegacyStoreExternalPaymentId("google_play", parsed.PurchaseToken, null, parsed.PurchaseToken);

                var pendingOrder = await dbContext.PurchaseOrders
                    .Join(
                        dbContext.CurrencyPacks.AsNoTracking(),
                        order => order.PackId,
                        pack => pack.Id,
                        (order, pack) => new { order, pack })
                    .Where(x =>
                        x.order.PaymentProvider == "google_play"
                        && x.order.Status == PurchaseOrderStatus.Pending
                        && purchaseTokenExternalPaymentId != null
                        && (x.order.ExternalPaymentId == purchaseTokenExternalPaymentId
                            || (legacyPurchaseTokenExternalPaymentId != null && x.order.ExternalPaymentId == legacyPurchaseTokenExternalPaymentId)))
                    .OrderByDescending(x => x.order.CreatedAtUtc)
                    .Select(x => new { x.order, ExpectedProductId = ResolvePackStoreProductId(x.pack, "google_play") })
                    .FirstOrDefaultAsync(cancellationToken);

                if (pendingOrder is null
                    || string.IsNullOrWhiteSpace(parsed.ProductId)
                    || !string.Equals(pendingOrder.ExpectedProductId, parsed.ProductId, StringComparison.Ordinal))
                {
                    await dbContext.SaveChangesAsync(cancellationToken);
                    if (transaction is not null)
                    {
                        await transaction.CommitAsync(cancellationToken);
                    }

                    LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, null, "ignored_not_found");
                    return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_not_found"));
                }

                var confirmResult = await ConfirmPurchaseInternalAsync(pendingOrder.order, cancellationToken);
                if (confirmResult.IsFailure
                    && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
                {
                    return Result.Failure<StoreWebhookResultResponse>(confirmResult.Error);
                }

                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, pendingOrder.order.UserId, "processed_token_purchase");
                return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed_token_purchase"));
            }

            if (!parsed.IsSubscriptionNotification)
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, null, "ignored_unknown_notification");
                return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_unknown_notification"));
            }

            var purchaseTokenExternalTransactionId = string.IsNullOrWhiteSpace(parsed.PurchaseToken)
                ? null
                : BuildGooglePlayPurchaseTokenReference(parsed.PurchaseToken);
            var legacyPurchaseTokenExternalTransactionId = string.IsNullOrWhiteSpace(parsed.PurchaseToken)
                ? null
                : parsed.PurchaseToken.Trim();

            var existingSubscription = await dbContext.UserSubscriptions
                .FirstOrDefaultAsync(
                    x => x.Provider == "google_play"
                        && purchaseTokenExternalTransactionId != null
                        && (x.ExternalTransactionId == purchaseTokenExternalTransactionId
                            || x.ExternalSubscriptionId == purchaseTokenExternalTransactionId
                            || (legacyPurchaseTokenExternalTransactionId != null
                                && (x.ExternalTransactionId == legacyPurchaseTokenExternalTransactionId
                                    || x.ExternalSubscriptionId == legacyPurchaseTokenExternalTransactionId))),
                    cancellationToken);

            if (existingSubscription is null)
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, null, "ignored_not_found");
                return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_not_found"));
            }

            var plan = await ResolveStoreNotificationPlanAsync(existingSubscription.PlanId, parsed.ProductId, "google_play", cancellationToken);
            if (plan is null)
            {
                return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumPlanNotFound);
            }

            var verification = await storeSubscriptionVerifier.VerifyAsync(
                new StoreSubscriptionVerificationRequest(
                    existingSubscription.UserId,
                    "google_play",
                    plan.PlanCode,
                    parsed.ProductId ?? string.Empty,
                    parsed.PurchaseToken ?? string.Empty,
                    null,
                    parsed.PurchaseToken,
                    null),
                cancellationToken);

            if (verification.IsFailure)
            {
                return Result.Failure<StoreWebhookResultResponse>(verification.Error);
            }

            var currentPeriodEndUtc = verification.Value.ExpiresAtUtc;
            var status = EconomyWebhookParser.NormalizeStoreSubscriptionStatus(
                EconomyWebhookParser.MapGooglePlayNotificationStatus(parsed.NotificationType, verification.Value.Status, verification.Value.IsActive),
                currentPeriodEndUtc);
            var cancelAtPeriodEnd = parsed.NotificationType == 3;
            var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, currentPeriodEndUtc);

            var subscriptionResult = await UpsertUserSubscriptionAsync(
                existingSubscription.UserId,
                "google_play",
                existingSubscription.PurchaseChannel,
                existingSubscription.Region,
                plan.PlanCode,
                status,
                existingSubscription.ExternalCustomerId,
                existingSubscription.ExternalSubscriptionId ?? verification.Value.ExternalSubscriptionId,
                purchaseTokenExternalTransactionId ?? existingSubscription.ExternalTransactionId,
                ResolveNotificationPeriodStartUtc(plan.BillingPeriod, currentPeriodEndUtc, existingSubscription.CurrentPeriodStartUtc),
                currentPeriodEndUtc,
                cancelAtPeriodEnd,
                plan.MonthlyTokenLimit,
                cancellationToken,
                legacyPurchaseTokenExternalTransactionId);
            if (subscriptionResult.IsFailure)
            {
                return Result.Failure<StoreWebhookResultResponse>(subscriptionResult.Error);
            }
            var subscription = subscriptionResult.Value;

            await AppendSubscriptionEventAsync(
                existingSubscription.UserId,
                subscription.Id,
                "google_play",
                $"GooglePlayNotification:{parsed.NotificationType}",
                subscription.Status,
                parsed.EventId,
                subscription.ExternalSubscriptionId,
                BuildSafeGooglePlayWebhookPayloadMetadata(parsed),
                cancellationToken);

            LogSubscriptionUpdated(
                "google_play",
                parsed.EventId,
                googlePlayEventType,
                existingSubscription.UserId,
                subscription.Status,
                isPremium ? "activated" : "canceled");

            if (isPremium)
            {
                await GrantPremiumSubscriptionAllowanceIfDueAsync(
                    subscription,
                    "google_play",
                    cancellationToken);
            }

            await _pushNotificationSender.NotifyPremiumUpdateAsync(
                existingSubscription.UserId,
                new PremiumPushNotification(
                    Status: isPremium ? "active" : "inactive",
                    Provider: "google_play",
                    PlanCode: plan.PlanCode),
                cancellationToken);

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            var premiumSyncResult = await SynchronizePremiumEntitlementAsync(
                existingSubscription.UserId,
                isPremium,
                "google_play",
                $"GooglePlayNotification:{parsed.NotificationType}",
                subscription.Id,
                subscription.ExternalSubscriptionId,
                cancellationToken);
            _ = premiumSyncResult;

            LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, existingSubscription.UserId, "processed");
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            EconomyMetrics.RecordDuplicateWebhook("google_play", googlePlayEventType);
            LogDuplicateStoreWebhook("google_play", parsed.EventId, googlePlayEventType);
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
        }
    }
}
