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
        LogStoreWebhookReceived("google_play", parsed.EventId, googlePlayEventType);

        if (!dbContext.Database.IsRelational()
            && await dbContext.ProcessedWebhookEvents.AnyAsync(x => x.Provider == "google_play" && x.EventId == parsed.EventId, cancellationToken))
        {
            LogDuplicateStoreWebhook("google_play", parsed.EventId, googlePlayEventType);
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
        }

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, cancellationToken)
            : null;

        try
        {
            dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
            {
                Id = Guid.NewGuid(),
                Provider = "google_play",
                EventId = parsed.EventId,
                EventType = googlePlayEventType,
                ProcessedAtUtc = DateTime.UtcNow
            });

            if (parsed.IsOneTimeProductNotification)
            {
                var pendingOrder = await dbContext.PurchaseOrders
                    .Join(
                        dbContext.CurrencyPacks.AsNoTracking(),
                        order => order.PackId,
                        pack => pack.Id,
                        (order, pack) => new { order, pack })
                    .Where(x =>
                        x.order.PaymentProvider == "google_play"
                        && x.order.Status == PurchaseOrderStatus.Pending
                        && !string.IsNullOrWhiteSpace(parsed.PurchaseToken)
                        && x.order.ExternalPaymentId == parsed.PurchaseToken)
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

            var existingSubscription = await dbContext.UserSubscriptions
                .FirstOrDefaultAsync(
                    x => x.Provider == "google_play"
                        && ((!string.IsNullOrWhiteSpace(parsed.PurchaseToken) && x.ExternalTransactionId == parsed.PurchaseToken)
                            || (!string.IsNullOrWhiteSpace(parsed.PurchaseToken) && x.ExternalSubscriptionId == parsed.PurchaseToken)),
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
                "Premium entitlement updated from Google Play webhook. Provider={Provider} UserId={UserId} EventId={EventId} EventType={EventType} Status={Status} IsPremium={IsPremium} CorrelationId={CorrelationId}",
                "google_play",
                existingSubscription.UserId,
                EconomyLogSanitizer.SafeExternalId(parsed.EventId),
                googlePlayEventType,
                status,
                isPremium,
                CurrentCorrelationId);

            await _pushNotificationSender.NotifyPremiumUpdateAsync(
                existingSubscription.UserId,
                new PremiumPushNotification(
                    Status: isPremium ? "active" : "inactive",
                    Provider: "google_play",
                    PlanCode: plan.PlanCode),
                cancellationToken);

            var subscription = await UpsertUserSubscriptionAsync(
                existingSubscription.UserId,
                "google_play",
                existingSubscription.PurchaseChannel,
                existingSubscription.Region,
                plan.PlanCode,
                status,
                parsed.EventId,
                existingSubscription.ExternalSubscriptionId ?? verification.Value.ExternalSubscriptionId,
                parsed.PurchaseToken ?? existingSubscription.ExternalTransactionId,
                ResolveNotificationPeriodStartUtc(plan.BillingPeriod, currentPeriodEndUtc, existingSubscription.CurrentPeriodStartUtc),
                currentPeriodEndUtc,
                cancelAtPeriodEnd,
                plan.MonthlyTokenLimit,
                cancellationToken);

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

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, existingSubscription.UserId, "processed");
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            LogDuplicateStoreWebhook("google_play", parsed.EventId, googlePlayEventType);
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
        }
    }
}
