using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IPaymentGateway
{
    Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken);

    Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
        SubscriptionCheckoutCreateRequest request,
        CancellationToken cancellationToken);

    Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken);

    Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
        BillingPortalCreateRequest request,
        CancellationToken cancellationToken);

    Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(PaymentMethodSetupCreateRequest request, CancellationToken cancellationToken);

    Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(PaymentMethodResolveRequest request, CancellationToken cancellationToken);

    Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken);

    Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(PaymentSavedMethodCreateRequest request, CancellationToken cancellationToken);
}

public sealed record PaymentCreateRequest(
    string Provider,
    Guid OrderId,
    Guid UserId,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string ProductName,
    string? ApiSecretKey = null,
    string? PublishableKey = null,
    string? ExternalCustomerId = null,
    bool UsePaymentSheet = false);

public sealed record PaymentCreateResponse(
    string ExternalPaymentId,
    string CheckoutUrl,
    string? PaymentIntentClientSecret = null,
    string? CustomerId = null,
    string? CustomerEphemeralKeySecret = null,
    string? PublishableKey = null);

public sealed record SubscriptionCheckoutCreateRequest(
    string Provider,
    Guid UserId,
    string ExternalCustomerId,
    string PlanCode,
    string ProductName,
    decimal PriceAmount,
    string CurrencyCode,
    string BillingInterval,
    string? ApiSecretKey = null);

public sealed record SubscriptionCheckoutCreateResponse(string ExternalCheckoutId, string CheckoutUrl);

public sealed record PaymentCustomerCreateRequest(string Provider, Guid UserId, string? ApiSecretKey = null);

public sealed record PaymentCustomerCreateResponse(string ExternalCustomerId);

public sealed record BillingPortalCreateRequest(string Provider, Guid UserId, string ExternalCustomerId, string? ApiSecretKey = null);

public sealed record BillingPortalCreateResponse(string PortalUrl);

public sealed record PaymentMethodSetupCreateRequest(string Provider, Guid UserId, string ExternalCustomerId, string? ApiSecretKey = null);

public sealed record PaymentMethodSetupCreateResponse(string ExternalSetupId, string CheckoutUrl);

public sealed record PaymentMethodResolveRequest(string Provider, string ExternalSetupId);

public sealed record PaymentMethodDetailsResponse(string ExternalPaymentMethodId, string Brand, string Last4, long? ExpMonth, long? ExpYear);

public sealed record PaymentMethodDetachRequest(string Provider, string ExternalPaymentMethodId);

public sealed record PaymentSavedMethodCreateRequest(
    string Provider,
    Guid OrderId,
    Guid UserId,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string ProductName,
    string ExternalCustomerId,
    string ExternalPaymentMethodId,
    string? ApiSecretKey = null);
