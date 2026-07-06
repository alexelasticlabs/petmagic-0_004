using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private string CurrentCorrelationId => CorrelationContext.ResolveOrCreate();
    private string CurrentCorrelationIdHash => SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate());

    private void LogPaymentWebhookReceived(
        string provider,
        string eventId,
        string eventType,
        Guid? userId,
        string? paymentIntentId,
        string? stripeCustomerId)
    {
        logger?.LogInformation(
            "Payment webhook received. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} PaymentIntentIdSafe={PaymentIntentIdSafe} StripeCustomerIdSafe={StripeCustomerIdSafe} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationIdHash);
    }

    private void LogPaymentWebhookProcessed(
        string provider,
        string eventId,
        string eventType,
        Guid? userId,
        string? paymentIntentId,
        string? stripeCustomerId)
    {
        logger?.LogInformation(
            "Payment webhook processed. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} PaymentIntentIdSafe={PaymentIntentIdSafe} StripeCustomerIdSafe={StripeCustomerIdSafe} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationIdHash);
    }

    private void LogDuplicatePaymentWebhook(
        string provider,
        string eventId,
        string eventType,
        Guid? userId = null,
        string? paymentIntentId = null,
        string? stripeCustomerId = null)
    {
        logger?.LogWarning(
            "Duplicate payment webhook ignored. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} PaymentIntentIdSafe={PaymentIntentIdSafe} StripeCustomerIdSafe={StripeCustomerIdSafe} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationIdHash);
    }

    private void LogPaymentWebhookFailed(Error error, string stage, string? eventType)
    {
        var errorCode = EconomyLogSanitizer.SafeErrorCode(error.Code);

        logger?.LogError(
            "Payment webhook failed. Stage={Stage} EventType={EventType} ErrorCode={ErrorCode} CorrelationIdHash={CorrelationIdHash}",
            stage,
            eventType,
            errorCode,
            CurrentCorrelationIdHash);
    }

    private void LogPaymentSucceeded(PurchaseOrder order, string source)
    {
        logger?.LogInformation(
            "Payment succeeded. Source={Source} PaymentIntentIdSafe={PaymentIntentIdSafe} UserIdHash={UserIdHash} CorrelationIdHash={CorrelationIdHash}",
            source,
            EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId),
            EconomyLogSanitizer.SafeUserId(order.UserId),
            CurrentCorrelationIdHash);
    }

    private void LogPaymentFailed(PurchaseOrder order, Error error, string source)
    {
        var errorCode = EconomyLogSanitizer.SafeErrorCode(error.Code);

        logger?.LogError(
            "Payment failed. Source={Source} PaymentIntentIdSafe={PaymentIntentIdSafe} UserIdHash={UserIdHash} ErrorCode={ErrorCode} CorrelationIdHash={CorrelationIdHash}",
            source,
            EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId),
            EconomyLogSanitizer.SafeUserId(order.UserId),
            errorCode,
            CurrentCorrelationIdHash);
    }

    private void LogSubscriptionUpdated(
        string provider,
        string eventId,
        string eventType,
        Guid userId,
        string status,
        string subscriptionOutcome,
        string? paymentIntentId = null,
        string? stripeCustomerId = null)
    {
        logger?.LogInformation(
            "Subscription {SubscriptionOutcome}. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} Status={Status} PaymentIntentIdSafe={PaymentIntentIdSafe} StripeCustomerIdSafe={StripeCustomerIdSafe} CorrelationIdHash={CorrelationIdHash}",
            subscriptionOutcome,
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            status,
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationIdHash);
    }

    private void LogStoreWebhookReceived(
        string provider,
        string eventId,
        string eventType,
        Guid? userId = null)
    {
        logger?.LogInformation(
            "Payment webhook received. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            CurrentCorrelationIdHash);
    }

    private void LogStoreWebhookProcessed(
        string provider,
        string eventId,
        string eventType,
        Guid? userId,
        string result)
    {
        logger?.LogInformation(
            "Payment webhook processed. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} UserIdHash={UserIdHash} Result={Result} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            EconomyLogSanitizer.SafeUserId(userId),
            result,
            CurrentCorrelationIdHash);
    }

    private void LogDuplicateStoreWebhook(
        string provider,
        string eventId,
        string eventType)
    {
        logger?.LogWarning(
            "Duplicate payment webhook ignored. Provider={Provider} EventIdSafe={EventIdSafe} EventType={EventType} CorrelationIdHash={CorrelationIdHash}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            CurrentCorrelationIdHash);
    }

    private static InvalidOperationException BuildSafeEconomyOperationException(string operation, Error error)
    {
        return new InvalidOperationException(
            $"Economy operation failed. Operation={operation} ErrorCode={EconomyLogSanitizer.SafeErrorCode(error.Code)}");
    }
}
