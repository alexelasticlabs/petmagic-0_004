using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

internal sealed class GenerationWorkerUnavailablePaymentGateway : IPaymentGateway
{
    private static readonly Error Unavailable = new(
        "economy.generation_worker.payment_unavailable",
        "Payment provider operations are not available in the generation worker host.");

    public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(
        PaymentCreateRequest request,
        CancellationToken cancellationToken) => Failed<PaymentCreateResponse>();

    public Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
        SubscriptionCheckoutCreateRequest request,
        CancellationToken cancellationToken) => Failed<SubscriptionCheckoutCreateResponse>();

    public Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(
        PaymentCustomerCreateRequest request,
        CancellationToken cancellationToken) => Failed<PaymentCustomerCreateResponse>();

    public Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
        BillingPortalCreateRequest request,
        CancellationToken cancellationToken) => Failed<BillingPortalCreateResponse>();

    public Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(
        PaymentMethodSetupCreateRequest request,
        CancellationToken cancellationToken) => Failed<PaymentMethodSetupCreateResponse>();

    public Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(
        PaymentMethodResolveRequest request,
        CancellationToken cancellationToken) => Failed<PaymentMethodDetailsResponse>();

    public Task<Result> DetachPaymentMethodAsync(
        PaymentMethodDetachRequest request,
        CancellationToken cancellationToken) => Task.FromResult(Result.Failure(Unavailable));

    public Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(
        PaymentSavedMethodCreateRequest request,
        CancellationToken cancellationToken) => Failed<PaymentCreateResponse>();

    public Task<Result<PaymentCancelResponse>> CancelPaymentAsync(
        PaymentCancelRequest request,
        CancellationToken cancellationToken) => Failed<PaymentCancelResponse>();

    public Task<Result<PaymentStateResponse>> GetPaymentStateAsync(
        PaymentStateRequest request,
        CancellationToken cancellationToken) => Failed<PaymentStateResponse>();

    public Task<Result<PaymentRefundResponse>> RefundPaymentAsync(
        PaymentRefundRequest request,
        CancellationToken cancellationToken) => Failed<PaymentRefundResponse>();

    private static Task<Result<T>> Failed<T>() =>
        Task.FromResult(Result.Failure<T>(Unavailable));
}

internal sealed class GenerationWorkerUnavailableStoreSubscriptionVerifier : IStoreSubscriptionVerifier
{
    private static readonly Error Unavailable = new(
        "economy.generation_worker.store_verification_unavailable",
        "Store verification operations are not available in the generation worker host.");

    public Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken) =>
        Task.FromResult(Result.Failure<StoreSubscriptionVerificationResponse>(Unavailable));

    public Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken) =>
        Task.FromResult(Result.Failure<StoreProductVerificationResponse>(Unavailable));
}
