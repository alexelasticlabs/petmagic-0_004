namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record StripeWebhookResultResponse(string EventId, bool Processed, string Status);

public sealed record StoreWebhookResultResponse(string Provider, string EventId, bool Processed, string Status);

public sealed record StripeDiagnosticsResponse(
    SubscriptionSummaryResponse Subscription,
    string? ExternalCustomerId,
    IReadOnlyList<StripeWebhookEventSnapshotResponse> RecentWebhookEvents,
    IReadOnlyList<StripeSubscriptionEventSnapshotResponse> RecentSubscriptionEvents,
    IReadOnlyList<StripePurchaseSnapshotResponse> RecentStripePurchases,
    DateTime GeneratedAtUtc);

public sealed record StripeWebhookEventSnapshotResponse(
    string EventId,
    string EventType,
    DateTime ProcessedAtUtc);

public sealed record StripeSubscriptionEventSnapshotResponse(
    string EventType,
    string Status,
    string? ExternalEventId,
    string? ExternalSubscriptionId,
    DateTime CreatedAtUtc);

public sealed record StripePurchaseSnapshotResponse(
    Guid OrderId,
    string Status,
    string? ExternalPaymentId,
    decimal PriceAmount,
    string CurrencyCode,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);
