using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Contracts;

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
        LogStoreWebhookReceived("app_store", parsed.EventId, appStoreEventType);

        if (!dbContext.Database.IsRelational()
            && await dbContext.ProcessedWebhookEvents.AnyAsync(x => x.Provider == "app_store" && x.EventId == parsed.EventId, cancellationToken))
        {
            LogDuplicateStoreWebhook("app_store", parsed.EventId, appStoreEventType);
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
        }

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, cancellationToken)
            : null;

        try
        {
            dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
            {
                Id = Guid.NewGuid(),
                Provider = "app_store",
                EventId = parsed.EventId,
                EventType = appStoreEventType,
                ProcessedAtUtc = DateTime.UtcNow
            });

            var processedTokenPurchase = false;
            if (!string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId)
                && !string.IsNullOrWhiteSpace(parsed.ProductId))
            {
                var pendingOrder = await dbContext.PurchaseOrders
                    .Join(
                        dbContext.CurrencyPacks.AsNoTracking(),
                        order => order.PackId,
                        pack => pack.Id,
                        (order, pack) => new { order, pack })
                    .Where(x =>
                        x.order.PaymentProvider == "app_store"
                        && x.order.Status == PurchaseOrderStatus.Pending
                        && x.order.ExternalPaymentId == parsed.ExternalPurchaseId)
                    .OrderByDescending(x => x.order.CreatedAtUtc)
                    .Select(x => new { x.order, ExpectedProductId = ResolvePackStoreProductId(x.pack, "app_store") })
                    .FirstOrDefaultAsync(cancellationToken);

                if (pendingOrder is not null
                    && string.Equals(pendingOrder.ExpectedProductId, parsed.ProductId, StringComparison.Ordinal))
                {
                    var confirmResult = await ConfirmPurchaseInternalAsync(pendingOrder.order, cancellationToken);
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

            if (identityService is null)
            {
                return Result.Failure<StoreWebhookResultResponse>(EconomyErrors.PremiumBillingUnavailable);
            }

            var premiumResult = await identityService.SetPremiumStatusAsync(
                new SetPremiumStatusCommand(existingSubscription.UserId, isPremium),
                cancellationToken);

            if (premiumResult.IsFailure)
            {
                return Result.Failure<StoreWebhookResultResponse>(premiumResult.Error);
            }

            logger?.LogInformation(
                "Premium entitlement updated from App Store webhook. Provider={Provider} UserId={UserId} EventId={EventId} EventType={EventType} Status={Status} IsPremium={IsPremium} CorrelationId={CorrelationId}",
                "app_store",
                existingSubscription.UserId,
                EconomyLogSanitizer.SafeExternalId(parsed.EventId),
                appStoreEventType,
                status,
                isPremium,
                CurrentCorrelationId);

            await _pushNotificationSender.NotifyPremiumUpdateAsync(
                existingSubscription.UserId,
                new PremiumPushNotification(
                    Status: isPremium ? "active" : "inactive",
                    Provider: "app_store",
                    PlanCode: plan.PlanCode),
                cancellationToken);

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

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            LogStoreWebhookProcessed("app_store", parsed.EventId, appStoreEventType, existingSubscription.UserId, "processed");
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            LogDuplicateStoreWebhook("app_store", parsed.EventId, appStoreEventType);
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
        }
    }
}
