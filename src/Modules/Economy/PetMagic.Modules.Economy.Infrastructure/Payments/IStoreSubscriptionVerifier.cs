using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

public enum StoreAccountBindingState
{
    Missing = 0,
    Matched = 1,
    Mismatched = 2
}

public sealed record StoreSubscriptionVerificationRequest(
    Guid UserId,
    string PaymentProvider,
    string PlanCode,
    string ProductId,
    string ServerVerificationData,
    string? LocalVerificationData,
    string? PurchaseId,
    string? TransactionDate);

public sealed record StoreSubscriptionVerificationResponse(
    bool IsActive,
    DateTime? ExpiresAtUtc,
    string Status,
    string? ExternalSubscriptionId,
    StoreAccountBindingState AccountBindingState = StoreAccountBindingState.Missing,
    Guid? BoundUserId = null);

public sealed record StoreProductVerificationRequest(
    Guid UserId,
    string PaymentProvider,
    string ProductId,
    string ServerVerificationData,
    string? LocalVerificationData,
    string? PurchaseId,
    string? TransactionDate);

public sealed record StoreProductVerificationResponse(
    bool IsPurchased,
    string Status,
    string? ExternalTransactionId,
    StoreAccountBindingState AccountBindingState = StoreAccountBindingState.Missing,
    Guid? BoundUserId = null);

public interface IStoreSubscriptionVerifier
{
    Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken);

    Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken);
}
