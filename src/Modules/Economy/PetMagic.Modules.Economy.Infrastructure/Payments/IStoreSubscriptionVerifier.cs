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

public interface IStoreSubscriptionVerifier
{
    Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
        StoreSubscriptionVerificationRequest request,
        CancellationToken cancellationToken);
}
