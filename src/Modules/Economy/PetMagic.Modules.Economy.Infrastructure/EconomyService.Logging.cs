using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Economy.Infrastructure;

public sealed partial class EconomyService
{
    private string CurrentCorrelationId => CorrelationContext.ResolveOrCreate();

    private void LogPaymentWebhookReceived(
        string provider,
        string eventId,
        string eventType,
        Guid? userId,
        string? paymentIntentId,
        string? stripeCustomerId)
    {
        logger?.LogInformation(
            "Payment webhook received. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} PaymentIntentId={PaymentIntentId} StripeCustomerId={StripeCustomerId} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationId);
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
            "Payment webhook processed. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} PaymentIntentId={PaymentIntentId} StripeCustomerId={StripeCustomerId} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationId);
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
            "Duplicate payment webhook ignored. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} PaymentIntentId={PaymentIntentId} StripeCustomerId={StripeCustomerId} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationId);
    }

    private void LogPaymentWebhookFailed(Error error, string stage, string? eventType)
    {
        logger?.LogError(
            "Payment webhook failed. Stage={Stage} EventType={EventType} ErrorCode={ErrorCode} CorrelationId={CorrelationId}",
            stage,
            eventType,
            error.Code,
            CurrentCorrelationId);
    }

    private void LogPaymentSucceeded(PurchaseOrder order, string source)
    {
        logger?.LogInformation(
            "Payment succeeded. Source={Source} PaymentIntentId={PaymentIntentId} UserId={UserId} CorrelationId={CorrelationId}",
            source,
            EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId),
            order.UserId,
            CurrentCorrelationId);
    }

    private void LogPaymentFailed(PurchaseOrder order, Error error, string source)
    {
        logger?.LogError(
            "Payment failed. Source={Source} PaymentIntentId={PaymentIntentId} UserId={UserId} ErrorCode={ErrorCode} CorrelationId={CorrelationId}",
            source,
            EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId),
            order.UserId,
            error.Code,
            CurrentCorrelationId);
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
            "Subscription {SubscriptionOutcome}. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} Status={Status} PaymentIntentId={PaymentIntentId} StripeCustomerId={StripeCustomerId} CorrelationId={CorrelationId}",
            subscriptionOutcome,
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            status,
            EconomyLogSanitizer.SafeExternalId(paymentIntentId),
            EconomyLogSanitizer.SafeExternalId(stripeCustomerId),
            CurrentCorrelationId);
    }

    private void LogStoreWebhookReceived(
        string provider,
        string eventId,
        string eventType,
        Guid? userId = null)
    {
        logger?.LogInformation(
            "Payment webhook received. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            CurrentCorrelationId);
    }

    private void LogStoreWebhookProcessed(
        string provider,
        string eventId,
        string eventType,
        Guid? userId,
        string result)
    {
        logger?.LogInformation(
            "Payment webhook processed. Provider={Provider} EventId={EventId} EventType={EventType} UserId={UserId} Result={Result} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            userId,
            result,
            CurrentCorrelationId);
    }

    private void LogDuplicateStoreWebhook(
        string provider,
        string eventId,
        string eventType)
    {
        logger?.LogWarning(
            "Duplicate payment webhook ignored. Provider={Provider} EventId={EventId} EventType={EventType} CorrelationId={CorrelationId}",
            provider,
            EconomyLogSanitizer.SafeExternalId(eventId),
            eventType,
            CurrentCorrelationId);
    }
}
