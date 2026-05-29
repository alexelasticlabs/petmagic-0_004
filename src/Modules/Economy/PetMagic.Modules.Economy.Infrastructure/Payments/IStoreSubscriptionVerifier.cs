using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Infrastructure.Payments;

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
    string? ExternalSubscriptionId);

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
    string? ExternalTransactionId);

public interface IStoreSubscriptionVerifier
{
    Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken);

    Task<Result<StoreProductVerificationResponse>> VerifyProductPurchaseAsync(
        StoreProductVerificationRequest request,
        CancellationToken cancellationToken);
}
