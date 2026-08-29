using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    [Fact]
    public async Task ExternalLoginAsync_ShouldCreateNewUserAndProvider_WhenProviderAndEmailAreNew()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var result = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Google", "google-user-1", "social@petmagic.app", "Social User", true),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("social@petmagic.app", result.Value.User.Email);

        var user = await identityDb.Users.SingleAsync();
        Assert.True(user.EmailConfirmed);
        Assert.Equal(AccountStatus.Active, user.AccountStatus);
        Assert.NotNull(user.LastLoginAtUtc);

        var provider = await identityDb.ExternalAuthProviders.SingleAsync();
        Assert.Equal(user.Id, provider.UserId);
        Assert.Equal("Google", provider.Provider);
        Assert.Equal("google-user-1", provider.ProviderUserId);
        Assert.Equal("social@petmagic.app", provider.Email);
        Assert.True(provider.LastUsedAt >= provider.CreatedAt);
        Assert.Single(await identityDb.RefreshTokenSessions.Where(x => x.UserId == user.Id).ToListAsync());
    }

    [Fact]
    public async Task ExternalLoginAsync_ShouldReuseProviderAccount_AndUpdateLastUsedWithoutDuplicateProvider()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var first = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Google", "google-user-2", "repeat@petmagic.app", "Repeat User", true),
            CancellationToken.None);
        Assert.True(first.IsSuccess);

        var firstProvider = await identityDb.ExternalAuthProviders.SingleAsync();
        firstProvider.LastUsedAt = DateTime.UtcNow.AddMinutes(-10);
        await identityDb.SaveChangesAsync();
        var oldLastUsed = firstProvider.LastUsedAt;

        var second = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Google", "google-user-2", "repeat@petmagic.app", "Repeat User", true),
            CancellationToken.None);

        Assert.True(second.IsSuccess);
        Assert.Equal(first.Value.User.UserId, second.Value.User.UserId);
        Assert.Single(await identityDb.Users.ToListAsync());
        Assert.Single(await identityDb.ExternalAuthProviders.ToListAsync());
        Assert.True((await identityDb.ExternalAuthProviders.SingleAsync()).LastUsedAt > oldLastUsed);
        var sessions = await identityDb.RefreshTokenSessions
            .Where(session => session.UserId == first.Value.User.UserId)
            .OrderBy(session => session.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, sessions.Count);
        Assert.Single(sessions, session => session.RevokedAtUtc is null);
        Assert.Single(sessions, session => session.RevokedAtUtc is not null);
        Assert.Equal("Google", sessions.Single(session => session.RevokedAtUtc is null).AuthenticationProvider);
    }

    [Fact]
    public async Task ExternalLoginAsync_ShouldLinkVerifiedEmailToExistingPendingUser_AndActivateAccount()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = "pending@petmagic.app",
            UserName = "pending@petmagic.app",
            NormalizedEmail = "PENDING@PETMAGIC.APP",
            NormalizedUserName = "PENDING@PETMAGIC.APP",
            EmailConfirmed = false,
            IsActive = true,
            AccountStatus = AccountStatus.PendingEmailVerification,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            CreatedAtUtc = DateTime.UtcNow
        };
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();

        var result = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Apple", "apple-user-1", "pending@petmagic.app", null, true),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(user.Id, result.Value.User.UserId);
        Assert.Single(await identityDb.Users.ToListAsync());

        var linkedUser = await identityDb.Users.SingleAsync();
        Assert.True(linkedUser.EmailConfirmed);
        Assert.Equal(AccountStatus.Active, linkedUser.AccountStatus);

        var provider = await identityDb.ExternalAuthProviders.SingleAsync();
        Assert.Equal("Apple", provider.Provider);
        Assert.Equal("apple-user-1", provider.ProviderUserId);
    }

    [Theory]
    [InlineData(null, true)]
    [InlineData("", true)]
    [InlineData("unverified@petmagic.app", false)]
    public async Task ExternalLoginAsync_ShouldRejectNewProvider_WhenEmailMissingOrUnverified(string? email, bool emailVerified)
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var result = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Google", Guid.NewGuid().ToString("N"), email, null, emailVerified),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(IdentityErrors.ExternalEmailMissing.Code, result.Error.Code);
        Assert.Empty(await identityDb.Users.ToListAsync());
        Assert.Empty(await identityDb.ExternalAuthProviders.ToListAsync());
        Assert.Empty(await identityDb.RefreshTokenSessions.ToListAsync());
    }

    [Fact]
    public async Task LinkExternalLoginAsync_ShouldRejectProviderSubjectOwnedByAnotherUser()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var ownerId = Guid.NewGuid();
        var targetId = Guid.NewGuid();
        identityDb.Users.AddRange(
            CreateActiveUser(ownerId, "owner@petmagic.app"),
            CreateActiveUser(targetId, "target@petmagic.app"));
        identityDb.ExternalAuthProviders.Add(new ExternalAuthProvider
        {
            Id = Guid.NewGuid(),
            UserId = ownerId,
            Provider = "Google",
            ProviderUserId = "shared-google-sub",
            Email = "owner@petmagic.app",
            CreatedAt = DateTime.UtcNow,
            LastUsedAt = DateTime.UtcNow
        });
        await identityDb.SaveChangesAsync();

        var result = await service.LinkExternalLoginAsync(
            targetId,
            new ExternalLoginCallbackCommand("Google", "shared-google-sub", "target@petmagic.app", null, true),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(IdentityErrors.ExternalAlreadyLinked.Code, result.Error.Code);
        Assert.Single(await identityDb.ExternalAuthProviders.ToListAsync());
    }

    [Fact]
    public async Task DeletedAccount_ShouldBlockSocialLoginByProviderAndEmail()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var login = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Apple", "deleted-apple-sub", "deleted@petmagic.app", null, true),
            CancellationToken.None);
        Assert.True(login.IsSuccess);
        var userId = login.Value.User.UserId;

        var delete = await service.DeleteCurrentUserAsync(new DeleteCurrentUserCommand(userId), CancellationToken.None);
        Assert.True(delete.IsSuccess);
        Assert.Empty(await identityDb.Users.ToListAsync());
        Assert.Equal(2, await identityDb.DeletedAccountBlocks.CountAsync());

        var byProvider = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Apple", "deleted-apple-sub", "new-relay@privaterelay.appleid.com", null, true),
            CancellationToken.None);
        var byEmail = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand("Google", "other-google-sub", "deleted@petmagic.app", null, true),
            CancellationToken.None);

        Assert.True(byProvider.IsFailure);
        Assert.Equal(IdentityErrors.AccountDeleted.Code, byProvider.Error.Code);
        Assert.True(byEmail.IsFailure);
        Assert.Equal(IdentityErrors.AccountDeleted.Code, byEmail.Error.Code);
    }

    [Fact]
    public async Task GetLinkedAccountsAsync_ShouldNormalizeCanonicalProviders_AndIgnoreLegacyEmptyProviders()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var userId = Guid.NewGuid();
        identityDb.Users.Add(CreateActiveUser(userId, "linked@petmagic.app"));
        identityDb.ExternalAuthProviders.AddRange(
            new ExternalAuthProvider
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = " google ",
                ProviderUserId = "google-sub-1",
                Email = "linked@petmagic.app",
                CreatedAt = DateTime.UtcNow.AddMinutes(-5),
                LastUsedAt = DateTime.UtcNow.AddMinutes(-1)
            },
            new ExternalAuthProvider
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = string.Empty,
                ProviderUserId = "legacy-empty-provider",
                Email = "linked@petmagic.app",
                CreatedAt = DateTime.UtcNow.AddMinutes(-4),
                LastUsedAt = DateTime.UtcNow.AddMinutes(-2)
            });
        await identityDb.SaveChangesAsync();

        var result = await service.GetLinkedAccountsAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var linkedAccount = Assert.Single(result.Value);
        Assert.Equal("Google", linkedAccount.Provider);
        Assert.Equal("Google", linkedAccount.DisplayName);
        Assert.False(linkedAccount.CanDisconnect);
    }

    [Theory]
    [InlineData(" Google ", "Google")]
    [InlineData(" apple ", "Apple")]
    public async Task LinkExternalLoginAsync_ShouldAcceptTrimmedCanonicalProviderNames(string rawProvider, string expectedProvider)
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var userId = Guid.NewGuid();
        identityDb.Users.Add(CreateActiveUser(userId, "trimmed@petmagic.app"));
        await identityDb.SaveChangesAsync();

        var result = await service.LinkExternalLoginAsync(
            userId,
            new ExternalLoginCallbackCommand(rawProvider, $"{expectedProvider.ToLowerInvariant()}-subject", "trimmed@petmagic.app", null, true),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var provider = await identityDb.ExternalAuthProviders.SingleAsync();
        Assert.Equal(expectedProvider, provider.Provider);
    }

    private static AppUser CreateActiveUser(Guid userId, string email)
    {
        return new AppUser
        {
            Id = userId,
            Email = email,
            UserName = email,
            NormalizedEmail = email.ToUpperInvariant(),
            NormalizedUserName = email.ToUpperInvariant(),
            EmailConfirmed = true,
            IsActive = true,
            AccountStatus = AccountStatus.Active,
            SecurityStamp = Guid.NewGuid().ToString("N"),
            CreatedAtUtc = DateTime.UtcNow
        };
    }
}
