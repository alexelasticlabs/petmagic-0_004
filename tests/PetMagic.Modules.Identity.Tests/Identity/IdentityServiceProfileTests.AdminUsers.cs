using Microsoft.AspNetCore.Identity;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

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
            sort: null,
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
            sort: null,
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
            role: " moderator ",
            status: " ACTIVE ",
            isPremium: true,
            sort: null,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(matching.Id, item.UserId);
        Assert.Contains(SystemRoles.Moderator, item.Roles);
    }

    [Fact]
    public async Task ListUsersAsync_ShouldApplyCreatedSortOnBackend()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;
        var newest = CreateListUser("newest-sort@petmagic.app", now);
        var middle = CreateListUser("middle-sort@petmagic.app", now.AddMinutes(-1));
        var oldest = CreateListUser("oldest-sort@petmagic.app", now.AddMinutes(-2));

        identityDb.Users.AddRange(newest, middle, oldest);
        await identityDb.SaveChangesAsync();

        var result = await service.ListUsersAsync(
            skip: 0,
            take: 3,
            search: null,
            role: null,
            status: null,
            isPremium: null,
            sort: "created_asc",
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(
            [oldest.Id, middle.Id, newest.Id],
            result.Value.Items.Select(item => item.UserId).ToArray());
    }

    [Fact]
    public async Task ListUsersAsync_ShouldApplyLastActivitySortAcrossBackendModules()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var now = DateTime.UtcNow;
        var auditUser = CreateListUser("audit-activity@petmagic.app", now.AddDays(-10));
        var economyUser = CreateListUser("economy-activity@petmagic.app", now.AddDays(-9));
        var templateUser = CreateListUser("template-activity@petmagic.app", now.AddDays(-8));
        var idleUser = CreateListUser("idle-activity@petmagic.app", now);

        identityDb.Users.AddRange(auditUser, economyUser, templateUser, idleUser);
        identityDb.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = auditUser.Id,
            Action = "auth.login.succeeded",
            Details = "login",
            CreatedAtUtc = now.AddHours(-3),
            OccurredAtUtc = now.AddHours(-3)
        });
        await identityDb.SaveChangesAsync();

        economyDb.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = economyUser.Id,
            Delta = 10,
            BalanceAfter = 10,
            Source = "admin_grant",
            Reason = "activity sort test",
            CreatedAtUtc = now.AddHours(-2)
        });
        await economyDb.SaveChangesAsync();

        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = "Activity Sort Template",
            Category = "tests",
            Tags = "tests",
            Status = TemplateStatus.Active,
            PromoBadgeMode = TemplatePromoBadgeMode.Auto,
            TokenCost = 1,
            CreatedAtUtc = now.AddDays(-1),
            UpdatedAtUtc = now.AddDays(-1)
        };
        templatesDb.TemplateItems.Add(template);
        templatesDb.TemplateGenerationJobs.Add(new TemplateGenerationJob
        {
            Id = Guid.NewGuid(),
            UserId = templateUser.Id,
            TemplateId = template.Id,
            Template = template,
            Status = TemplateGenerationStatus.Completed,
            TokenCost = 1,
            SourceImageUrl = "https://cdn.example.com/source.jpg",
            SourceImageFileName = "source.jpg",
            SourceImageContentType = "image/jpeg",
            CreatedAtUtc = now.AddHours(-1),
            UpdatedAtUtc = now.AddHours(-1),
            CompletedAtUtc = now.AddHours(-1)
        });
        await templatesDb.SaveChangesAsync();

        var descending = await service.ListUsersAsync(
            skip: 0,
            take: 4,
            search: "activity@petmagic.app",
            role: null,
            status: null,
            isPremium: null,
            sort: "last_activity_desc",
            CancellationToken.None);
        var ascending = await service.ListUsersAsync(
            skip: 0,
            take: 4,
            search: "activity@petmagic.app",
            role: null,
            status: null,
            isPremium: null,
            sort: "last_activity_asc",
            CancellationToken.None);

        Assert.True(descending.IsSuccess);
        Assert.Equal(
            [templateUser.Id, economyUser.Id, auditUser.Id, idleUser.Id],
            descending.Value.Items.Select(item => item.UserId).ToArray());
        Assert.Equal(now.AddHours(-1), descending.Value.Items[0].LastActivityAtUtc);
        Assert.Equal(now.AddHours(-2), descending.Value.Items[1].LastActivityAtUtc);
        Assert.Equal(now.AddHours(-3), descending.Value.Items[2].LastActivityAtUtc);
        Assert.Null(descending.Value.Items[3].LastActivityAtUtc);

        Assert.True(ascending.IsSuccess);
        Assert.Equal(
            [idleUser.Id, auditUser.Id, economyUser.Id, templateUser.Id],
            ascending.Value.Items.Select(item => item.UserId).ToArray());
    }

    [Fact]
    public async Task ListUsersAsync_ShouldRejectInvalidSort()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var result = await service.ListUsersAsync(
            skip: 0,
            take: 20,
            search: null,
            role: null,
            status: null,
            isPremium: null,
            sort: "random",
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("users.sort_invalid", result.Error.Code);
    }

    [Fact]
    public async Task RoleMutations_ShouldNormalizeSupportedRoleCasing()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var user = CreateListUser("role-normalized@petmagic.app", DateTime.UtcNow);

        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, user.Id, SystemRoles.User);

        var assignResult = await service.AssignRoleAsync(
            new AssignRoleCommand(user.Id, " moderator "),
            CancellationToken.None);

        Assert.True(assignResult.IsSuccess);
        Assert.Contains(
            identityDb.UserRoles,
            userRole => userRole.UserId == user.Id
                && userRole.RoleId == identityDb.Roles.Single(role => role.Name == SystemRoles.Moderator).Id);

        var revokeResult = await service.RevokeRoleAsync(
            new RevokeRoleCommand(user.Id, " MODERATOR "),
            CancellationToken.None);

        Assert.True(revokeResult.IsSuccess);
        Assert.DoesNotContain(
            identityDb.UserRoles,
            userRole => userRole.UserId == user.Id
                && userRole.RoleId == identityDb.Roles.Single(role => role.Name == SystemRoles.Moderator).Id);
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
