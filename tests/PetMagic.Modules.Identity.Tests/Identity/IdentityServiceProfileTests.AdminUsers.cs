using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    [Fact]
    public async Task ListUsersAsync_ShouldReturnRequestedPage_WithHasMore()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;
        var newest = CreateListUser("newest@petmagic.app", now);
        var middle = CreateListUser("middle@petmagic.app", now.AddMinutes(-1));
        var oldest = CreateListUser("oldest@petmagic.app", now.AddMinutes(-2));

        identityDb.Users.AddRange(newest, middle, oldest);
        await identityDb.SaveChangesAsync();

        var result = await service.ListUsersAsync(skip: 1, take: 1, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.Skip);
        Assert.Equal(1, result.Value.Take);
        Assert.True(result.Value.HasMore);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(middle.Id, item.UserId);
    }

    [Fact]
    public async Task ListUsersAsync_ShouldClampOversizedTake()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;

        var users = Enumerable.Range(0, 201)
            .Select(index => CreateListUser($"bulk-{index:D3}@petmagic.app", now.AddSeconds(-index)))
            .ToArray();

        identityDb.Users.AddRange(users);
        await identityDb.SaveChangesAsync();

        var result = await service.ListUsersAsync(skip: 0, take: 999, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(0, result.Value.Skip);
        Assert.Equal(200, result.Value.Take);
        Assert.Equal(200, result.Value.Items.Count);
        Assert.True(result.Value.HasMore);
    }

    private static AppUser CreateListUser(string email, DateTime createdAtUtc)
    {
        return new AppUser
        {
            Id = Guid.NewGuid(),
            Email = email,
            UserName = email,
            NormalizedEmail = email.ToUpperInvariant(),
            NormalizedUserName = email.ToUpperInvariant(),
            EmailConfirmed = true,
            IsActive = true,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            AccountStatus = AccountStatus.Active,
            TermsOfUseAccepted = true,
            PrivacyPolicyAccepted = true,
            CreatedAtUtc = createdAtUtc
        };
    }
}
