using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Data;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class UserEconomyResourceOwnershipReader(EconomyDbContext dbContext)
    : IUserEconomyResourceOwnershipReader
{
    public Task<bool> OwnsPurchaseOrderAsync(
        Guid userId,
        Guid purchaseOrderId,
        CancellationToken cancellationToken)
    {
        return dbContext.PurchaseOrders
            .AsNoTracking()
            .AnyAsync(
                purchaseOrder => purchaseOrder.Id == purchaseOrderId
                    && purchaseOrder.UserId == userId,
                cancellationToken);
    }

    public Task<bool> OwnsSubscriptionAsync(
        Guid userId,
        Guid subscriptionId,
        CancellationToken cancellationToken)
    {
        return dbContext.UserSubscriptions
            .AsNoTracking()
            .AnyAsync(
                subscription => subscription.Id == subscriptionId
                    && subscription.UserId == userId,
                cancellationToken);
    }
}
