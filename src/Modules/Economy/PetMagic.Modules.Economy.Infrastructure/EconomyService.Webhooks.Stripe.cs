using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

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
                "Stripe SDK signature verification failed. Falling back to manual signature validation. ExceptionType={ExceptionType} CorrelationIdHash={CorrelationIdHash}",
                SafeLogValues.ExceptionType(ex),
                CurrentCorrelationIdHash);

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

        var safeStripeEventId = EconomyLogSanitizer.SafeExternalId(eventId) ?? eventId;
        var safeStripeObjectId = EconomyLogSanitizer.SafeExternalId(parsedEvent.ObjectId);
        var safeStripeCustomerId = EconomyLogSanitizer.SafeExternalId(parsedEvent.CustomerId);
        LogPaymentWebhookReceived(
            "stripe",
            safeStripeEventId,
            eventType,
            parsedEvent.UserId,
            safeStripeObjectId,
            safeStripeCustomerId);

        await using var transaction = dbContext.Database.IsRelational()
            ? await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, cancellationToken)
            : null;
        PendingPremiumEntitlementSync? pendingPremiumSync = null;

        try
        {
            if (!await TryClaimWebhookEventAsync("stripe", eventId, eventType, cancellationToken))
            {
                EconomyMetrics.RecordDuplicateWebhook("stripe", eventType);
                LogDuplicatePaymentWebhook(
                    "stripe",
                    eventId,
                    eventType,
                    parsedEvent.UserId,
                    parsedEvent.ObjectId,
                    parsedEvent.CustomerId);
                return Result.Success(new StripeWebhookResultResponse(eventId, false, "ignored_duplicate"));
            }

            var shouldConfirmPackPurchase = string.Equals(eventType, "payment_intent.succeeded", StringComparison.Ordinal)
                || (string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal)
                    && IsStripeCheckoutSessionPaymentConfirmed(parsedEvent.CheckoutPaymentStatus, parsedEvent.Status));
            if (shouldConfirmPackPurchase)
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

            if ((string.Equals(eventType, "refund.created", StringComparison.Ordinal)
                    || string.Equals(eventType, "refund.updated", StringComparison.Ordinal))
                && (parsedEvent.OrderId.HasValue || !string.IsNullOrWhiteSpace(parsedEvent.PaymentReferenceId))
                && (string.IsNullOrWhiteSpace(parsedEvent.Status)
                    || string.Equals(parsedEvent.Status, "succeeded", StringComparison.OrdinalIgnoreCase)))
            {
                var refundOrder = await ResolveOrderAsync(parsedEvent.OrderId, parsedEvent.PaymentReferenceId, cancellationToken);
                if (refundOrder is not null
                    && (string.Equals(refundOrder.Status, PurchaseOrderStatus.Succeeded, StringComparison.Ordinal)
                        || string.Equals(refundOrder.Status, PurchaseOrderStatus.RefundPending, StringComparison.Ordinal)
                        || string.Equals(refundOrder.Status, PurchaseOrderStatus.RefundRequiresManualReview, StringComparison.Ordinal)
                        || string.Equals(refundOrder.Status, PurchaseOrderStatus.Refunded, StringComparison.Ordinal)))
                {
                    if (!IsFullStripePurchaseRefund(refundOrder, parsedEvent.RefundAmountMinor, parsedEvent.RefundCurrency))
                    {
                        await MarkPurchaseRefundForManualReviewAsync(
                            refundOrder,
                            parsedEvent.ObjectId ?? eventId,
                            "stripe_partial_or_unverifiable_refund",
                            new
                            {
                                parsedEvent.RefundAmountMinor,
                                parsedEvent.RefundCurrency,
                                ExpectedAmountMinor = decimal.ToInt64(decimal.Round(refundOrder.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero)),
                                refundOrder.CurrencyCode
                            },
                            cancellationToken);
                    }
                    else
                    {
                        var refundResult = await ApplyPurchaseRefundInternalAsync(
                            refundOrder,
                            parsedEvent.ObjectId ?? string.Empty,
                            cancellationToken);
                        if (refundResult.IsFailure
                            && !string.Equals(refundResult.Error.Code, EconomyErrors.PurchaseNotRefundable.Code, StringComparison.Ordinal))
                        {
                            return StripeWebhookFailure(refundResult.Error, "purchase.refund", eventType);
                        }
                    }
                }
            }

            var isCheckoutCompleted = string.Equals(eventType, "checkout.session.completed", StringComparison.Ordinal);
            var isInvoiceSucceeded = string.Equals(eventType, "invoice.payment_succeeded", StringComparison.Ordinal);
            var isInvoiceFailed = string.Equals(eventType, "invoice.payment_failed", StringComparison.Ordinal);
            var isSubscriptionCreated = string.Equals(eventType, "customer.subscription.created", StringComparison.Ordinal);
            var isSubscriptionUpdated = string.Equals(eventType, "customer.subscription.updated", StringComparison.Ordinal);
            var isSubscriptionDeleted = string.Equals(eventType, "customer.subscription.deleted", StringComparison.Ordinal);
            var isPremiumSubscriptionCheckoutCompleted = isCheckoutCompleted
                && string.Equals(parsedEvent.Purpose, "premium_subscription", StringComparison.Ordinal)
                && IsStripeCheckoutSessionPaymentConfirmed(parsedEvent.CheckoutPaymentStatus, parsedEvent.Status);
            var isStripeSubscriptionLifecycleEvent = isPremiumSubscriptionCheckoutCompleted
                || isInvoiceSucceeded
                || isInvoiceFailed
                || isSubscriptionCreated
                || isSubscriptionUpdated
                || isSubscriptionDeleted;
            var effectiveUserId = parsedEvent.UserId;
            if (!effectiveUserId.HasValue && isStripeSubscriptionLifecycleEvent)
            {
                effectiveUserId = await ResolveStripeWebhookUserIdAsync(
                    parsedEvent.CustomerId,
                    parsedEvent.SubscriptionId,
                    cancellationToken);
            }

            if (effectiveUserId.HasValue && isStripeSubscriptionLifecycleEvent)
            {
                var subscriptionStatusIsActive = string.Equals(parsedEvent.Status, "active", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(parsedEvent.Status, "trialing", StringComparison.OrdinalIgnoreCase);
                ResolvedPremiumPlan? resolvedPlan = null;
                UserSubscription? existingSubscription = null;
                var hasSubscriptionContext = !string.IsNullOrWhiteSpace(parsedEvent.PlanCode)
                    || !string.IsNullOrWhiteSpace(parsedEvent.SubscriptionId);
                if (!hasSubscriptionContext)
                {
                    return StripeWebhookFailure(EconomyErrors.PremiumPlanNotFound, "premium.context", eventType);
                }

                (resolvedPlan, existingSubscription) = await ResolveStripePlanContextAsync(
                    effectiveUserId.Value,
                    parsedEvent.PlanCode,
                    parsedEvent.StripePriceId,
                    parsedEvent.SubscriptionId,
                    cancellationToken);

                if (resolvedPlan is null && existingSubscription is null)
                {
                    return StripeWebhookFailure(EconomyErrors.PremiumPlanNotFound, "premium.plan", eventType);
                }

                if (isStripeSubscriptionLifecycleEvent)
                {
                    var resolvedCurrentPeriodEndUtc = parsedEvent.CurrentPeriodEndUtc ?? existingSubscription?.CurrentPeriodEndUtc;
                    var confirmedCurrentPeriodEndUtc = parsedEvent.CurrentPeriodEndUtc;
                    var shouldKeepPremiumDuringPaymentFailure = isInvoiceFailed
                        && resolvedCurrentPeriodEndUtc.HasValue
                        && resolvedCurrentPeriodEndUtc.Value >= DateTime.UtcNow;
                    var shouldActivatePremium = ((isPremiumSubscriptionCheckoutCompleted || isInvoiceSucceeded)
                            && confirmedCurrentPeriodEndUtc.HasValue
                            && confirmedCurrentPeriodEndUtc.Value >= DateTime.UtcNow)
                        || ((isSubscriptionCreated || isSubscriptionUpdated)
                            && ShouldStripeSubscriptionRemainPremium(
                                parsedEvent.Status,
                                confirmedCurrentPeriodEndUtc,
                                parsedEvent.CancelAtPeriodEnd));
                    var shouldDeactivatePremium = isSubscriptionDeleted
                        || (isInvoiceFailed && !shouldKeepPremiumDuringPaymentFailure)
                        || ((isSubscriptionCreated || isSubscriptionUpdated)
                            && !subscriptionStatusIsActive
                            && !ShouldStripeSubscriptionRemainPremium(
                                parsedEvent.Status,
                                resolvedCurrentPeriodEndUtc,
                                parsedEvent.CancelAtPeriodEnd));
                    var shouldUpdateIdentity = shouldActivatePremium
                        || shouldDeactivatePremium
                        || isInvoiceFailed;
                    var desiredPremiumState = shouldActivatePremium
                        || shouldKeepPremiumDuringPaymentFailure;

                    var resolvedPlanId = resolvedPlan?.PlanCode ?? existingSubscription!.PlanId;
                    var monthlyTokenLimit = resolvedPlan?.MonthlyTokenLimit ?? existingSubscription!.MonthlyTokenLimit;
                    var subscriptionStatus = existingSubscription?.Status ?? "Pending";
                    if (shouldActivatePremium)
                    {
                        subscriptionStatus = parsedEvent.CancelAtPeriodEnd
                            ? "Canceled"
                            : EconomyWebhookParser.MapStripeSubscriptionStatus(parsedEvent.Status);
                    }
                    else if (isInvoiceFailed)
                    {
                        subscriptionStatus = shouldKeepPremiumDuringPaymentFailure
                            ? "PastDue"
                            : "Expired";
                    }
                    else if (isSubscriptionDeleted)
                    {
                        subscriptionStatus = "Expired";
                    }
                    else if (shouldDeactivatePremium)
                    {
                        subscriptionStatus = "Expired";
                    }

                    var subscriptionResult = await UpsertUserSubscriptionAsync(
                        effectiveUserId.Value,
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
                    if (subscriptionResult.IsFailure)
                    {
                        return StripeWebhookFailure(subscriptionResult.Error, "premium.subscription_upsert", eventType);
                    }
                    var subscription = subscriptionResult.Value;
                    var subscriptionRemainsPremium = string.Equals(subscription.Status, "Active", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(subscription.Status, "Trialing", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(subscription.Status, "Canceled", StringComparison.OrdinalIgnoreCase)
                        || string.Equals(subscription.Status, "PastDue", StringComparison.OrdinalIgnoreCase);

                    if (shouldUpdateIdentity)
                    {
                        pendingPremiumSync = new PendingPremiumEntitlementSync(
                            effectiveUserId.Value,
                            desiredPremiumState,
                            "stripe",
                            eventType,
                            subscription.Id,
                            subscription.ExternalSubscriptionId,
                            parsedEvent.PlanCode,
                            SafeLogValues.StableHash(eventId));
                    }

                    if (shouldActivatePremium || isInvoiceFailed || isSubscriptionDeleted || shouldDeactivatePremium)
                    {
                        LogSubscriptionUpdated(
                            "stripe",
                            eventId,
                            eventType,
                            effectiveUserId.Value,
                            subscription.Status,
                            shouldActivatePremium && subscriptionStatusIsActive
                                ? "activated"
                                : isInvoiceFailed
                                    ? "payment_failed"
                                    : subscriptionRemainsPremium
                                        ? "status_updated"
                                        : "canceled",
                            parsedEvent.ObjectId,
                            parsedEvent.CustomerId);
                    }

                    await AppendSubscriptionEventAsync(
                        effectiveUserId.Value,
                        subscription.Id,
                        "stripe",
                        shouldActivatePremium && subscriptionStatusIsActive
                            ? "SubscriptionActivated"
                            : isInvoiceFailed
                                ? "SubscriptionPaymentFailed"
                                : isSubscriptionDeleted
                                    ? "SubscriptionExpired"
                                    : subscriptionRemainsPremium
                                        ? "SubscriptionStatusUpdated"
                                    : shouldDeactivatePremium
                                        ? "SubscriptionExpired"
                                    : "SubscriptionPending",
                        subscription.Status,
                        eventId,
                        subscription.ExternalSubscriptionId,
                        BuildSafeStripeWebhookPayloadMetadata(parsedEvent),
                        cancellationToken);

                    if (shouldActivatePremium)
                    {
                        await GrantPremiumSubscriptionAllowanceIfDueAsync(
                            subscription,
                            "stripe",
                            cancellationToken);

                        await SettlePendingReferralBonusAsync(
                            effectiveUserId.Value,
                            $"premium:stripe:{subscription.PlanId}",
                            DateTime.UtcNow,
                            cancellationToken);
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

                var savePaymentMethodResult = await SavePaymentMethodAsync(parsedEvent.UserId.Value, "stripe", methodResult.Value, cancellationToken);
                if (savePaymentMethodResult.IsFailure)
                {
                    return StripeWebhookFailure(savePaymentMethodResult.Error, "payment_method.save", eventType);
                }
            }

            if (pendingPremiumSync is not null)
            {
                await _pushNotificationSender.NotifyPremiumUpdateAsync(
                    pendingPremiumSync.UserId,
                    new PremiumPushNotification(
                        Status: pendingPremiumSync.DesiredPremium ? "active" : "inactive",
                        Provider: pendingPremiumSync.Provider,
                        PlanCode: pendingPremiumSync.PlanCode,
                        EventKey: pendingPremiumSync.EventKey),
                    cancellationToken);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            if (pendingPremiumSync is not null)
            {
                var premiumSyncResult = await SynchronizePremiumEntitlementAsync(
                    pendingPremiumSync.UserId,
                    pendingPremiumSync.DesiredPremium,
                    pendingPremiumSync.Provider,
                    pendingPremiumSync.Reason,
                    pendingPremiumSync.SubscriptionId,
                    pendingPremiumSync.ExternalSubscriptionId,
                    cancellationToken);
                _ = premiumSyncResult;
            }

            LogPaymentWebhookProcessed(
                "stripe",
                eventId,
                eventType,
                effectiveUserId,
                parsedEvent.ObjectId,
                parsedEvent.CustomerId);
            return Result.Success(new StripeWebhookResultResponse(eventId, true, "processed"));
        }
        catch (DbUpdateException exception) when (IsUniqueWebhookEventConflict(exception))
        {
            dbContext.ChangeTracker.Clear();
            EconomyMetrics.RecordDuplicateWebhook("stripe", eventType);
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

    internal static bool ShouldStripeSubscriptionRemainPremium(
        string? providerStatus,
        DateTime? currentPeriodEndUtc,
        bool cancelAtPeriodEnd)
    {
        if (string.Equals(providerStatus, "active", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "trialing", StringComparison.OrdinalIgnoreCase))
        {
            return currentPeriodEndUtc.HasValue && currentPeriodEndUtc.Value >= DateTime.UtcNow;
        }

        if (string.Equals(providerStatus, "past_due", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "unpaid", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "canceled", StringComparison.OrdinalIgnoreCase)
            || string.Equals(providerStatus, "cancelled", StringComparison.OrdinalIgnoreCase)
            || cancelAtPeriodEnd)
        {
            return currentPeriodEndUtc.HasValue && currentPeriodEndUtc.Value >= DateTime.UtcNow;
        }

        return false;
    }

    private static bool IsFullStripePurchaseRefund(
        PurchaseOrder order,
        long? refundAmountMinor,
        string? refundCurrency)
    {
        if (!refundAmountMinor.HasValue
            || refundAmountMinor.Value <= 0
            || string.IsNullOrWhiteSpace(refundCurrency)
            || !string.Equals(refundCurrency.Trim(), order.CurrencyCode, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var expectedAmountMinor = decimal.ToInt64(
            decimal.Round(order.PriceAmount * 100m, 0, MidpointRounding.AwayFromZero));
        return refundAmountMinor.Value == expectedAmountMinor;
    }

    private sealed record PendingPremiumEntitlementSync(
        Guid UserId,
        bool DesiredPremium,
        string Provider,
        string Reason,
        Guid? SubscriptionId,
        string? ExternalSubscriptionId,
        string? PlanCode,
        string EventKey);
}
