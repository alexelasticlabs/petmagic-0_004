namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record PurchaseCheckoutResponse(
    Guid OrderId,
    Guid UserId,
    string PaymentProvider,
    string ExternalPaymentId,
    string CheckoutUrl,
    string? PaymentIntentClientSecret,
    string? CustomerId,
    string? CustomerEphemeralKeySecret,
    string? PublishableKey,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    DateTime CreatedAtUtc);

public sealed record VerifyStripeCheckoutSessionCommand(Guid UserId, Guid OrderId, string? StripeReferenceId);

public sealed record CancelPackPurchaseCommand(Guid UserId, Guid OrderId);

public sealed record PurchaseOrderResponse(
    Guid OrderId,
    Guid UserId,
    Guid PackId,
    string PaymentProvider,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string? ExternalPaymentId,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);

public sealed record PurchaseHistoryItemResponse(
    Guid OrderId,
    Guid UserId,
    Guid PackId,
    string PackCode,
    string PackDisplayName,
    string PaymentProvider,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string? ExternalPaymentId,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc,
    bool CanRefund = false,
    string ProductType = "TokenPack",
    int TokenAmount = 0,
    string RefundStatus = "none");

public sealed record AdminPurchaseCapabilitiesResponse(
    bool CanRefund,
    bool CanRetryRefund,
    bool RequiresManualReview);

public sealed record AdminPurchaseTimelineItemResponse(
    string EventType,
    string Status,
    DateTime OccurredAtUtc);

public sealed record AdminPurchaseIncidentLinkResponse(
    Guid IncidentId,
    string Type,
    string Severity,
    string Status,
    DateTime FirstDetectedAtUtc,
    DateTime? ResolvedAtUtc);

public sealed record AdminPurchaseDetailResponse(
    Guid OrderId,
    Guid UserId,
    Guid PackId,
    string PackCode,
    string PackDisplayName,
    string PaymentProvider,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc,
    string RefundStatus,
    string SettlementState,
    AdminPurchaseCapabilitiesResponse Capabilities,
    IReadOnlyList<AdminPurchaseTimelineItemResponse> Timeline,
    IReadOnlyList<AdminPurchaseIncidentLinkResponse> Incidents);

public sealed record PaymentMethodResponse(
    Guid PaymentMethodId,
    string PaymentProvider,
    string Brand,
    string Last4,
    long? ExpMonth,
    long? ExpYear,
    bool IsDefault,
    DateTime CreatedAtUtc);

public sealed record PaymentMethodSetupResponse(
    string PaymentProvider,
    string ExternalSetupId,
    string CheckoutUrl);

public sealed record PremiumCheckoutResponse(
    string PaymentProvider,
    string CheckoutUrl,
    string Status,
    string? ExternalSubscriptionId = null,
    string? PaymentIntentClientSecret = null,
    string? CustomerId = null,
    string? CustomerEphemeralKeySecret = null,
    string? PublishableKey = null);

public sealed record BillingPortalSessionResponse(
    string PaymentProvider,
    string PortalUrl);

public sealed record PremiumStoreVerificationResponse(
    string PaymentProvider,
    string ProductId,
    bool IsActive,
    DateTime? ExpiresAtUtc,
    string Status);

public sealed record BillingProductsResponse(
    IReadOnlyList<BillingTokenPackProductResponse> TokenPacks,
    IReadOnlyList<BillingSubscriptionProductResponse> Subscriptions);

public sealed record BillingTokenPackProductResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    int TokenAmount,
    string GooglePlayProductId,
    string AppleAppStoreProductId);

public sealed record BillingSubscriptionProductResponse(
    string PlanId,
    string Name,
    string BillingPeriod,
    int MonthlyTokenLimit,
    string? GooglePlayProductId,
    string? AppleAppStoreProductId);

public sealed record StoreBillingValidationResponse(
    string Provider,
    string ProductType,
    string ProductId,
    string Status,
    bool TokensGranted,
    int TokenAmount,
    bool IsPremium,
    DateTime? ExpiresAtUtc);
