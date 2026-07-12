namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IUserEconomyResourceOwnershipReader
{
    Task<bool> OwnsPurchaseOrderAsync(
        Guid userId,
        Guid purchaseOrderId,
        CancellationToken cancellationToken);

    Task<bool> OwnsSubscriptionAsync(
        Guid userId,
        Guid subscriptionId,
        CancellationToken cancellationToken);
}
