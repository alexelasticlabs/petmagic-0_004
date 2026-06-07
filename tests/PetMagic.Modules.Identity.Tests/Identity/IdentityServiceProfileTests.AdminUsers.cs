using Microsoft.AspNetCore.Identity;

using PetMagic.Modules.Identity.Application.Contracts;
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

        var result = await service.ListUsersAsync(
            skip: 1,
            take: 1,
            search: null,
            role: null,
            status: null,
            isPremium: null,
            CancellationToken.None);

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

        var result = await service.ListUsersAsync(
            skip: 0,
            take: 999,
            search: null,
            role: null,
            status: null,
            isPremium: null,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(0, result.Value.Skip);
        Assert.Equal(200, result.Value.Take);
        Assert.Equal(200, result.Value.Items.Count);
        Assert.True(result.Value.HasMore);
    }

    [Fact]
    public async Task ListUsersAsync_ShouldApplyBackendSearchAndFilters()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;
        var matching = CreateListUser("matching@petmagic.app", now);
        matching.DisplayName = "Searched Person";
        matching.IsPremium = true;
        var inactiveAdmin = CreateListUser("other-admin@petmagic.app", now.AddMinutes(-1));
        inactiveAdmin.IsActive = false;
        var regularUser = CreateListUser("regular@petmagic.app", now.AddMinutes(-2));

        identityDb.Users.AddRange(matching, inactiveAdmin, regularUser);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, matching.Id, SystemRoles.Moderator);
        await AddUserRoleAsync(identityDb, inactiveAdmin.Id, SystemRoles.Admin);
        await AddUserRoleAsync(identityDb, regularUser.Id, SystemRoles.User);

        var result = await service.ListUsersAsync(
            skip: 0,
            take: 20,
            search: "searched",
            role: SystemRoles.Moderator,
            status: "active",
            isPremium: true,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(matching.Id, item.UserId);
        Assert.Contains(SystemRoles.Moderator, item.Roles);
    }

    [Fact]
    public async Task GetAdminUserDashboardMetricsAsync_ShouldAggregateUsersRolesAndWeeklyRegistrations()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;
        var todayStart = new DateTime(now.Year, now.Month, now.Day, 0, 0, 0, DateTimeKind.Utc);
        var admin = CreateListUser("admin-metrics@petmagic.app", todayStart.AddHours(12));
        admin.IsPremium = true;
        var moderator = CreateListUser("moderator-metrics@petmagic.app", todayStart.AddDays(-2).AddHours(12));
        var regular = CreateListUser("regular-metrics@petmagic.app", todayStart.AddDays(-8).AddHours(12));
        var older = CreateListUser("older-metrics@petmagic.app", todayStart.AddDays(-20).AddHours(12));
        older.IsPremium = true;
        older.IsActive = false;

        identityDb.Users.AddRange(admin, moderator, regular, older);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, admin.Id, SystemRoles.Admin);
        await AddUserRoleAsync(identityDb, moderator.Id, SystemRoles.Moderator);
        await AddUserRoleAsync(identityDb, regular.Id, SystemRoles.User);
        await AddUserRoleAsync(identityDb, older.Id, SystemRoles.User);

        var result = await service.GetAdminUserDashboardMetricsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(4, result.Value.TotalUsers);
        Assert.Equal(2, result.Value.PremiumUsers);
        Assert.Equal(3, result.Value.ActiveUsers);
        Assert.Equal(1, result.Value.BlockedUsers);
        Assert.Equal(1, result.Value.AdminUsers);
        Assert.Equal(1, result.Value.ModeratorUsers);
        Assert.Equal(2, result.Value.RegularUsers);
        Assert.Equal(2, result.Value.UsersThisWeek);
        Assert.Equal(1, result.Value.UsersPreviousWeek);
        Assert.Equal(2, result.Value.NewUsersLast7Days);
        Assert.Equal(4, result.Value.NewUsersLast30Days);
        Assert.Equal(4, result.Value.NewUsersLast90Days);
    }

    [Fact]
    public async Task RevokeRoleAsync_ShouldRejectRemovingLastAdmin()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var admin = CreateListUser("admin@petmagic.app", DateTime.UtcNow);

        identityDb.Users.Add(admin);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, admin.Id, SystemRoles.Admin);

        var result = await service.RevokeRoleAsync(
            new RevokeRoleCommand(admin.Id, SystemRoles.Admin),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("users.cannot_remove_last_admin", result.Error.Code);
    }

    [Fact]
    public async Task SetUserActiveStatusAsync_ShouldRejectBlockingLastAdmin()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var admin = CreateListUser("admin@petmagic.app", DateTime.UtcNow);

        identityDb.Users.Add(admin);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, admin.Id, SystemRoles.Admin);

        var result = await service.SetUserActiveStatusAsync(
            new SetUserActiveStatusCommand(admin.Id, IsActive: false),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("users.cannot_remove_last_admin", result.Error.Code);
    }

    [Fact]
    public async Task DeleteAdminUserAsync_ShouldRejectDeletingLastAdmin()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var admin = CreateListUser("admin@petmagic.app", DateTime.UtcNow);

        identityDb.Users.Add(admin);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, admin.Id, SystemRoles.Admin);

        var result = await service.DeleteAdminUserAsync(
            new DeleteAdminUserCommand(admin.Id),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("users.cannot_remove_last_admin", result.Error.Code);
    }

    private static async Task AddUserRoleAsync(
        PetMagic.Modules.Identity.Infrastructure.Data.IdentityDbContext identityDb,
        Guid userId,
        string role)
    {
        var roleId = identityDb.Roles.Single(x => x.Name == role).Id;
        identityDb.UserRoles.Add(new IdentityUserRole<Guid> { UserId = userId, RoleId = roleId });
        await identityDb.SaveChangesAsync();
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
