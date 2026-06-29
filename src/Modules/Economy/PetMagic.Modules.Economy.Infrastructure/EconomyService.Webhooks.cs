using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using Npgsql;
using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Contracts;

using Stripe;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    public async Task<Result<StripeWebhookResultResponse>> HandleStripeWebhookAsync(StripeWebhookCommand command, CancellationToken cancellationToken)
    {
        string? eventId;
        string? eventType;
        var stripeWebhookSecrets = ResolveStripeWebhookSecrets();
        if (stripeWebhookSecrets.Count == 0)
        {
            return StripeWebhookFailure(EconomyErrors.InvalidStripeSignature, "configuration");
        }

        try
        {
            Event? stripeEvent = null;
            Exception? lastVerificationError = null;

            foreach (var webhookSecret in stripeWebhookSecrets)
            {
                try
                {
                    stripeEvent = EventUtility.ConstructEvent(command.RawBody, command.StripeSignature, webhookSecret);
                    break;
                }
                catch (Exception ex)
                {
                    lastVerificationError = ex;
                }
            }

            if (stripeEvent is null)
            {
                throw lastVerificationError ?? new InvalidOperationException("Stripe webhook signature validation failed.");
            }

            eventId = stripeEvent.Id;
            eventType = stripeEvent.Type;
        }
        catch (Exception ex)
        {
            logger?.LogWarning(
                ex,
                "Stripe SDK signature verification failed. Falling back to manual signature validation. CorrelationId={CorrelationId}",
                CurrentCorrelationId);

            var isSignatureValid = stripeWebhookSecrets.Any(
                webhookSecret => EconomyWebhookParser.VerifyStripeSignatureFallback(command.RawBody, command.StripeSignature, webhookSecret));

            if (!isSignatureValid)
            {
                return StripeWebhookFailure(EconomyErrors.InvalidStripeSignature, "signature");
            }

            var envelope = EconomyWebhookParser.ParseStripeEnvelope(command.RawBody);
            if (!envelope.Success)
            {
                return StripeWebhookFailure(EconomyErrors.InvalidWebhookPayload, "fallback.parse");
            }

            eventId = envelope.EventId;
            eventType = envelope.EventType;
        }

        if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(eventType))
        {
            return StripeWebhookFailure(EconomyErrors.InvalidWebhookPayload, "envelope");
        }

        var parsedEvent = EconomyWebhookParser.ParseStripeEvent(command.RawBody);
        if (!parsedEvent.Success)
        {
            return StripeWebhookFailure(EconomyErrors.InvalidWebhookPayload, "event.parse", eventType);
        }

        LogPaymentWebhookReceived(
            "stripe",
            eventId,
            eventType,
            parsedEvent.UserId,
            parsedEvent.ObjectId,
            parsedEvent.CustomerId);

        if (!dbContext.Database.IsRelational()
            && await dbContext.ProcessedWebhookEvents.AnyAsync(x => x.Provider == "stripe" && x.EventId == eventId, cancellationToken))
        {
            LogDuplicatePaymentWebhook(
                "stripe",
                eventId,
                eventType,
                parsedEvent.UserId,
                parsedEvent.ObjectId,
                parsedEvent.CustomerId);
            return Result.Success(new StripeWebhookResultResponse(eventId, false, "ignored_duplicate"));
        }

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.ReadCommitted, cancellationToken)
            : null;

        try
        {
            dbContext.ProcessedWebhookEvents.Add(new ProcessedWebhookEvent
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                EventId = eventId,
                EventType = eventType,
                ProcessedAtUtc = DateTime.UtcNow
            });

            if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
                || string.Equals(eventType, "payment_intent.succeeded", StringComparison.Ordinal))
            {
                var order = await ResolveOrderAsync(parsedEvent.OrderId, parsedEvent.ObjectId, cancellationToken);
                if (order is not null)
                {
                    var confirmResult = await ConfirmPurchaseInternalAsync(order, cancellationToken);
                    if (confirmResult.IsFailure && !string.Equals(confirmResult.Error.Code, EconomyErrors.PurchaseAlreadyProcessed.Code, StringComparison.Ordinal))
                    {
                        return StripeWebhookFailure(confirmResult.Error, "purchase.confirm", eventType);
                    }
                }
            }

            if (parsedEvent.UserId.HasValue
                && string.Equals(parsedEvent.Purpose, "premium_subscription", StringComparison.Ordinal))
            {
                var isCheckoutCompleted = string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal);
                var isInvoiceSucceeded = string.Equals(eventType, "invoice.payment_succeeded", StringComparison.Ordinal);
                var isInvoiceFailed = string.Equals(eventType, "invoice.payment_failed", StringComparison.Ordinal);
                var isSubscriptionCreated = string.Equals(eventType, "customer.subscription.created", StringComparison.Ordinal);
                var isSubscriptionUpdated = string.Equals(eventType, "customer.subscription.updated", StringComparison.Ordinal);
                var isSubscriptionDeleted = string.Equals(eventType, "customer.subscription.deleted", StringComparison.Ordinal);
                var subscriptionStatusIsActive = string.Equals(parsedEvent.Status, "active", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(parsedEvent.Status, "trialing", StringComparison.OrdinalIgnoreCase);

                if (isCheckoutCompleted
                    || isInvoiceSucceeded
                    || isInvoiceFailed
                    || isSubscriptionCreated
                    || isSubscriptionUpdated
                    || isSubscriptionDeleted)
                {
                    var shouldActivatePremium = isCheckoutCompleted
                        || isInvoiceSucceeded
                        || ((isSubscriptionCreated || isSubscriptionUpdated) && subscriptionStatusIsActive);
                    var shouldDeactivatePremium = isInvoiceFailed || isSubscriptionDeleted;
                    var shouldUpdateIdentity = shouldActivatePremium || shouldDeactivatePremium || isSubscriptionUpdated;

                    if (shouldUpdateIdentity)
                    {
                        if (identityService is null)
                        {
                            return StripeWebhookFailure(EconomyErrors.PremiumBillingUnavailable, "premium.identity", eventType);
                        }

                        var premiumResult = await identityService.SetPremiumStatusAsync(
                            new SetPremiumStatusCommand(parsedEvent.UserId.Value, shouldActivatePremium),
                            cancellationToken);

                        if (premiumResult.IsFailure)
                        {
                            return StripeWebhookFailure(premiumResult.Error, "premium.identity", eventType);
                        }

                        logger?.LogInformation(
                            "Premium entitlement updated from Stripe webhook. Provider={Provider} UserId={UserId} EventId={EventId} EventType={EventType} Activated={Activated} Status={Status} PaymentIntentId={PaymentIntentId} StripeCustomerId={StripeCustomerId} CorrelationId={CorrelationId}",
                            "stripe",
                            parsedEvent.UserId.Value,
                            eventId,
                            eventType,
                            shouldActivatePremium,
                            parsedEvent.Status,
                            parsedEvent.ObjectId,
                            parsedEvent.CustomerId,
                            CurrentCorrelationId);

                        await _pushNotificationSender.NotifyPremiumUpdateAsync(
                            parsedEvent.UserId.Value,
                            new PremiumPushNotification(
                                Status: shouldActivatePremium ? "active" : "inactive",
                                Provider: "stripe",
                                PlanCode: parsedEvent.PlanCode),
                            cancellationToken);
                    }

                    if (!string.IsNullOrWhiteSpace(parsedEvent.PlanCode) || !string.IsNullOrWhiteSpace(parsedEvent.SubscriptionId))
                    {
                        var (resolvedPlan, existingSubscription) = await ResolveStripePlanContextAsync(
                            parsedEvent.UserId.Value,
                            parsedEvent.PlanCode,
                            parsedEvent.SubscriptionId,
                            cancellationToken);

                        if (resolvedPlan is null && existingSubscription is null)
                        {
                            return StripeWebhookFailure(EconomyErrors.PremiumPlanNotFound, "premium.plan", eventType);
                        }

                        var resolvedPlanId = resolvedPlan?.PlanCode ?? existingSubscription!.PlanId;
                        var monthlyTokenLimit = resolvedPlan?.MonthlyTokenLimit ?? existingSubscription!.MonthlyTokenLimit;
                        var subscriptionStatus = "Pending";
                        if (shouldActivatePremium)
                        {
                            subscriptionStatus = parsedEvent.CancelAtPeriodEnd
                                ? "Canceled"
                                : EconomyWebhookParser.MapStripeSubscriptionStatus(parsedEvent.Status);
                        }
                        else if (isInvoiceFailed)
                        {
                            subscriptionStatus = "PastDue";
                        }
                        else if (isSubscriptionDeleted)
                        {
                            subscriptionStatus = "Expired";
                        }

                        var subscription = await UpsertUserSubscriptionAsync(
                            parsedEvent.UserId.Value,
                            "stripe",
                            isCheckoutCompleted ? "web" : "payment_sheet",
                            string.Empty,
                            resolvedPlanId,
                            subscriptionStatus,
                            parsedEvent.CustomerId,
                            parsedEvent.SubscriptionId,
                            parsedEvent.ObjectId,
                            parsedEvent.CurrentPeriodStartUtc ?? existingSubscription?.CurrentPeriodStartUtc ?? DateTime.UtcNow,
                            parsedEvent.CurrentPeriodEndUtc,
                            parsedEvent.CancelAtPeriodEnd,
                            monthlyTokenLimit,
                            cancellationToken);

                        if (shouldActivatePremium || isInvoiceFailed || isSubscriptionDeleted)
                        {
                            LogSubscriptionUpdated(
                                "stripe",
                                eventId,
                                eventType,
                                parsedEvent.UserId.Value,
                                subscription.Status,
                                shouldActivatePremium
                                    ? "activated"
                                    : isInvoiceFailed
                                        ? "payment_failed"
                                        : "canceled",
                                parsedEvent.ObjectId,
                                parsedEvent.CustomerId);
                        }

                        await AppendSubscriptionEventAsync(
                            parsedEvent.UserId.Value,
                            subscription.Id,
                            "stripe",
                            shouldActivatePremium
                                ? "SubscriptionActivated"
                                : isInvoiceFailed
                                    ? "SubscriptionPaymentFailed"
                                    : isSubscriptionDeleted
                                        ? "SubscriptionExpired"
                                        : "SubscriptionPending",
                            subscription.Status,
                            eventId,
                            subscription.ExternalSubscriptionId,
                            command.RawBody,
                            cancellationToken);

                        if (shouldActivatePremium)
                        {
                            await GrantPremiumSubscriptionAllowanceIfDueAsync(
                            subscription,
                            "stripe",
                            cancellationToken);

                            await SettlePendingReferralBonusAsync(
                                parsedEvent.UserId.Value,
                                $"premium:stripe:{subscription.PlanId}",
                                DateTime.UtcNow,
                                cancellationToken);
                        }
                    }
                }
            }

            if (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
                && string.Equals(parsedEvent.Purpose, "payment_method_setup", StringComparison.Ordinal)
                && parsedEvent.UserId.HasValue
                && !string.IsNullOrWhiteSpace(parsedEvent.SetupIntentId))
            {
                var methodResult = await paymentGateway.ResolveSetupIntentPaymentMethodAsync(
                    new PaymentMethodResolveRequest("stripe", parsedEvent.SetupIntentId),
                    cancellationToken);

                if (methodResult.IsFailure)
                {
                    return StripeWebhookFailure(methodResult.Error, "payment_method.resolve", eventType);
                }

                await SavePaymentMethodAsync(parsedEvent.UserId.Value, "stripe", methodResult.Value, cancellationToken);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            LogPaymentWebhookProcessed(
                "stripe",
                eventId,
                eventType,
                parsedEvent.UserId,
                parsedEvent.ObjectId,
                parsedEvent.CustomerId);
            return Result.Success(new StripeWebhookResultResponse(eventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            LogDuplicatePaymentWebhook(
                "stripe",
                eventId,
                eventType,
                parsedEvent.UserId,
                parsedEvent.ObjectId,
                parsedEvent.CustomerId);
            return Result.Success(new StripeWebhookResultResponse(eventId, false, "ignored_duplicate"));
        }
    }

    private static bool IsUniqueWebhookEventConflict(DbUpdateException exception)
    {
        return exception.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation };
    }

    private Result<StripeWebhookResultResponse> StripeWebhookFailure(Error error, string stage, string? eventType = null)
    {
        EconomyMetrics.RecordStripeWebhookFailure(error.Code, stage, eventType);
        LogPaymentWebhookFailed(error, stage, eventType);
        return Result.Failure<StripeWebhookResultResponse>(error);
    }

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

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "app_store" && x.EventId == parsed.EventId, cancellationToken);

        if (alreadyProcessed)
        {
            LogDuplicateStoreWebhook("app_store", parsed.EventId, appStoreEventType);
            return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, false, "ignored_duplicate"));
        }

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

        var status = EconomyWebhookParser.MapAppStoreNotificationStatus(parsed.NotificationType, parsed.Subtype, parsed.ExpiresAtUtc);
        var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, parsed.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

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
            parsed.EventId,
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

        var subscription = await UpsertUserSubscriptionAsync(
            existingSubscription.UserId,
            "app_store",
            existingSubscription.PurchaseChannel,
            existingSubscription.Region,
            plan.PlanCode,
            status,
            parsed.EventId,
            parsed.ExternalSubscriptionId ?? existingSubscription.ExternalSubscriptionId,
            parsed.ExternalPurchaseId ?? existingSubscription.ExternalTransactionId,
            ResolveNotificationPeriodStartUtc(plan.BillingPeriod, parsed.ExpiresAtUtc, existingSubscription.CurrentPeriodStartUtc),
            parsed.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc,
            parsed.CancelAtPeriodEnd,
            plan.MonthlyTokenLimit,
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

        LogStoreWebhookProcessed("app_store", parsed.EventId, appStoreEventType, existingSubscription.UserId, "processed");
        return Result.Success(new StoreWebhookResultResponse("app_store", parsed.EventId, true, "processed"));
    }

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

        var alreadyProcessed = await dbContext.ProcessedWebhookEvents
            .AnyAsync(x => x.Provider == "google_play" && x.EventId == parsed.EventId, cancellationToken);

        if (alreadyProcessed)
        {
            LogDuplicateStoreWebhook("google_play", parsed.EventId, googlePlayEventType);
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, false, "ignored_duplicate"));
        }

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
            LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, pendingOrder.order.UserId, "processed_token_purchase");
            return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed_token_purchase"));
        }

        if (!parsed.IsSubscriptionNotification)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
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

        var status = EconomyWebhookParser.MapGooglePlayNotificationStatus(parsed.NotificationType, verification.Value.Status, verification.Value.IsActive);
        var cancelAtPeriodEnd = parsed.NotificationType == 3;
        var isPremium = EconomyWebhookParser.IsStoreSubscriptionPremium(status, verification.Value.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc);

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
            parsed.EventId,
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
            ResolveNotificationPeriodStartUtc(plan.BillingPeriod, verification.Value.ExpiresAtUtc, existingSubscription.CurrentPeriodStartUtc),
            verification.Value.ExpiresAtUtc ?? existingSubscription.CurrentPeriodEndUtc,
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

        LogStoreWebhookProcessed("google_play", parsed.EventId, googlePlayEventType, existingSubscription.UserId, "processed");
        return Result.Success(new StoreWebhookResultResponse("google_play", parsed.EventId, true, "processed"));
    }

    private static string BuildSafeAppStoreWebhookPayloadMetadata(
        (bool Success, string? EventId, string? NotificationType, string? Subtype, string? ProductId, string? ExternalSubscriptionId, string? ExternalPurchaseId, DateTime? ExpiresAtUtc, bool CancelAtPeriodEnd) parsed)
    {
        return JsonSerializer.Serialize(new
        {
            parsed.NotificationType,
            parsed.Subtype,
            parsed.ProductId,
            parsed.ExpiresAtUtc,
            parsed.CancelAtPeriodEnd,
            HasExternalSubscriptionId = !string.IsNullOrWhiteSpace(parsed.ExternalSubscriptionId),
            HasExternalPurchaseId = !string.IsNullOrWhiteSpace(parsed.ExternalPurchaseId)
        });
    }

    private static string BuildSafeGooglePlayWebhookPayloadMetadata(
        (bool Success, string? EventId, int NotificationType, string? ProductId, string? PurchaseToken, bool IsSubscriptionNotification, bool IsOneTimeProductNotification) parsed)
    {
        return JsonSerializer.Serialize(new
        {
            parsed.NotificationType,
            parsed.ProductId,
            parsed.IsSubscriptionNotification,
            parsed.IsOneTimeProductNotification
        });
    }
}
