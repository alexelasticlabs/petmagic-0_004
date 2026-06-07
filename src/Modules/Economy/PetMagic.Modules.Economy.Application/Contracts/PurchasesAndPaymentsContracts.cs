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
    bool CanRefund = false);

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
