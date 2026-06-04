using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class DatabaseIndexModelTests
{
    [Fact]
    public void IdentityDbContext_ShouldExposeHotPathIndexes()
    {
        using var dbContext = new IdentityDbContext(
            new DbContextOptionsBuilder<IdentityDbContext>()
                .UseInMemoryDatabase($"identity-indexes-{Guid.NewGuid():N}")
                .Options);

        AssertHasIndex<AppUser>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<AppUser>(dbContext, ["AccountStatus", "AccountStatusUpdatedAtUtc", "CreatedAtUtc"]);
        AssertHasIndex<AuditEvent>(dbContext, ["SubjectUserId", "OccurredAtUtc"]);
        AssertHasIndex<EmailDispatchJob>(dbContext, ["Status", "UpdatedAtUtc"]);
    }

    [Fact]
    public void EconomyDbContext_ShouldExposeHotPathIndexes()
    {
        using var dbContext = new EconomyDbContext(
            new DbContextOptionsBuilder<EconomyDbContext>()
                .UseInMemoryDatabase($"economy-indexes-{Guid.NewGuid():N}")
                .Options);

        AssertHasIndex<WalletLedgerEntry>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<WalletLedgerEntry>(dbContext, ["Source", "CreatedAtUtc"]);
        AssertHasIndex<PurchaseOrder>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<PurchaseOrder>(dbContext, ["Status", "CreatedAtUtc"]);
        AssertHasIndex<RedeemCode>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<RedeemCodeRedemption>(dbContext, ["RedeemCodeId", "RedeemedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["UpdatedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["Status", "UpdatedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["Provider", "UpdatedAtUtc"]);
        AssertHasIndex<SubscriptionEventLog>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<SubscriptionEventLog>(dbContext, ["Provider", "Status", "CreatedAtUtc"]);
    }

    private static void AssertHasIndex<TEntity>(DbContext dbContext, IReadOnlyList<string> propertyNames)
    {
        var entityType = dbContext.Model.FindEntityType(typeof(TEntity));
        Assert.NotNull(entityType);

        var indexes = entityType!.GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToArray();

        Assert.Contains(indexes, index => index.SequenceEqual(propertyNames));
    }
}
