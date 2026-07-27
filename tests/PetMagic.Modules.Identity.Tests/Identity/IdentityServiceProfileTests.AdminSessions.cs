using System.IdentityModel.Tokens.Jwt;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    [Fact]
    public async Task GetAdminUserSessionsAsync_ShouldReturnOnlySafeBoundedMetadata()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(
            identityDb,
            economyDb,
            templatesDb,
            new TrackingAvatarStorage());
        var user = CreateListUser("session-list@petmagic.app", DateTime.UtcNow.AddDays(-3));
        var now = DateTime.UtcNow;
        var activeSession = CreateRefreshSession(user.Id, "secret-active-token-hash", now.AddDays(1));
        var expiredSession = CreateRefreshSession(user.Id, "secret-expired-token-hash", now.AddDays(-1));
        var revokedSession = CreateRefreshSession(user.Id, "secret-revoked-token-hash", now.AddDays(1));
        revokedSession.RevokedAtUtc = now.AddHours(-1);

        identityDb.Users.Add(user);
        identityDb.RefreshTokenSessions.AddRange(activeSession, expiredSession, revokedSession);
        await identityDb.SaveChangesAsync();

        var result = await service.GetAdminUserSessionsAsync(user.Id, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(3, result.Value.TotalCount);
        Assert.Equal(1, result.Value.ActiveCount);
        Assert.False(result.Value.HasMore);
        Assert.Equal(activeSession.Id, result.Value.Items[0].SessionId);
        Assert.Equal("active", result.Value.Items[0].Status);
        Assert.True(result.Value.Items[0].CanRevoke);
        Assert.Contains(result.Value.Items, item => item.Status == "expired" && !item.CanRevoke);
        Assert.Contains(result.Value.Items, item => item.Status == "revoked" && !item.CanRevoke);

        var exposedNames = typeof(AdminUserSessionListItemResponse)
            .GetProperties()
            .Select(property => property.Name)
            .ToArray();
        Assert.DoesNotContain("TokenHash", exposedNames);
        Assert.DoesNotContain("RefreshToken", exposedNames);
        Assert.DoesNotContain("AccessToken", exposedNames);
    }

    [Fact]
    public async Task IssuedAccessToken_ShouldBeBoundToItsRefreshSession()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(
            identityDb,
            economyDb,
            templatesDb,
            new TrackingAvatarStorage());

        var result = await service.ExternalLoginAsync(
            new ExternalLoginCallbackCommand(
                "Google",
                $"session-bound-{Guid.NewGuid():N}",
                "session-bound@petmagic.app",
                "Session Bound",
                EmailVerified: true),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var persistedSession = await identityDb.RefreshTokenSessions.AsNoTracking().SingleAsync();
        var token = new JwtSecurityTokenHandler().ReadJwtToken(result.Value.AccessToken);
        var sessionClaim = Assert.Single(
            token.Claims,
            claim => claim.Type == IdentityJwtClaimTypes.SessionId);
        Assert.Equal(persistedSession.Id, Guid.Parse(sessionClaim.Value));
    }

    [Fact]
    public async Task RevokeAdminUserSessionAsync_ShouldBeActorScopedIdempotentAndAudited()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(
            identityDb,
            economyDb,
            templatesDb,
            new TrackingAvatarStorage());
        var actorUserId = Guid.NewGuid();
        var user = CreateListUser("session-revoke@petmagic.app", DateTime.UtcNow.AddDays(-2));
        var session = CreateRefreshSession(
            user.Id,
            "single-revoke-token-hash",
            DateTime.UtcNow.AddDays(10));

        identityDb.Users.Add(user);
        identityDb.RefreshTokenSessions.Add(session);
        await identityDb.SaveChangesAsync();

        var command = new AdminRevokeUserSessionCommand(
            actorUserId,
            user.Id,
            session.Id,
            "Verified account owner request",
            "session-revoke-intent-1");
        var first = await service.RevokeAdminUserSessionAsync(command, CancellationToken.None);
        var replay = await service.RevokeAdminUserSessionAsync(command, CancellationToken.None);
        var conflict = await service.RevokeAdminUserSessionAsync(
            command with { Reason = "Different operational reason" },
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.Equal(1, first.Value.RevokedCount);
        Assert.False(first.Value.Replayed);
        Assert.True(replay.IsSuccess);
        Assert.Equal(first.Value.OccurredAtUtc, replay.Value.OccurredAtUtc);
        Assert.True(replay.Value.Replayed);
        Assert.True(conflict.IsFailure);
        Assert.Equal("users.session_idempotency_conflict", conflict.Error.Code);
        Assert.NotNull(
            await identityDb.RefreshTokenSessions
                .Where(candidate => candidate.Id == session.Id)
                .Select(candidate => candidate.RevokedAtUtc)
                .SingleAsync());

        var auditEvents = await identityDb.AuditEvents
            .Where(auditEvent => auditEvent.Action == "admin.user.session.revoked")
            .ToListAsync();
        var auditEvent = Assert.Single(auditEvents);
        Assert.Equal(actorUserId, auditEvent.ActorUserId);
        Assert.Equal(user.Id, auditEvent.SubjectUserId);
        Assert.Contains("Verified account owner request", auditEvent.Details, StringComparison.Ordinal);
        Assert.DoesNotContain("session-revoke-intent-1", auditEvent.Details, StringComparison.Ordinal);
        Assert.DoesNotContain("single-revoke-token-hash", auditEvent.Details, StringComparison.Ordinal);
    }

    [Fact]
    public async Task RevokeAllAdminUserSessionsAsync_ShouldRevokeActiveSessionsAndInvalidateAccessTokens()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(
            identityDb,
            economyDb,
            templatesDb,
            new TrackingAvatarStorage());
        var user = CreateListUser("session-revoke-all@petmagic.app", DateTime.UtcNow.AddDays(-4));
        var previousSecurityStamp = user.SecurityStamp;
        var now = DateTime.UtcNow;
        var firstActive = CreateRefreshSession(user.Id, "active-one", now.AddDays(5));
        var secondActive = CreateRefreshSession(user.Id, "active-two", now.AddDays(6));
        var expired = CreateRefreshSession(user.Id, "expired", now.AddMinutes(-1));

        identityDb.Users.Add(user);
        identityDb.RefreshTokenSessions.AddRange(firstActive, secondActive, expired);
        await identityDb.SaveChangesAsync();

        var result = await service.RevokeAllAdminUserSessionsAsync(
            new AdminRevokeAllUserSessionsCommand(
                Guid.NewGuid(),
                user.Id,
                "Security incident containment",
                "session-revoke-all-intent-1"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.RevokedCount);
        var sessions = await identityDb.RefreshTokenSessions
            .AsNoTracking()
            .OrderBy(session => session.TokenHash)
            .ToListAsync();
        Assert.NotNull(sessions.Single(session => session.Id == firstActive.Id).RevokedAtUtc);
        Assert.NotNull(sessions.Single(session => session.Id == secondActive.Id).RevokedAtUtc);
        Assert.Null(sessions.Single(session => session.Id == expired.Id).RevokedAtUtc);
        var updatedUser = await identityDb.Users.AsNoTracking().SingleAsync(candidate => candidate.Id == user.Id);
        Assert.NotEqual(previousSecurityStamp, updatedUser.SecurityStamp);
        Assert.Contains(
            identityDb.AuditEvents,
            auditEvent => auditEvent.SubjectUserId == user.Id
                && auditEvent.Action == "admin.user.sessions.revoked_all");
    }

    [Fact]
    public async Task RevokeAdminUserSessionAsync_ShouldScopeTheSameIdempotencyKeyPerActor()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(
            identityDb,
            economyDb,
            templatesDb,
            new TrackingAvatarStorage());
        var user = CreateListUser("session-actor-scope@petmagic.app", DateTime.UtcNow.AddDays(-1));
        var firstSession = CreateRefreshSession(
            user.Id,
            "actor-scope-first",
            DateTime.UtcNow.AddDays(1));
        var secondSession = CreateRefreshSession(
            user.Id,
            "actor-scope-second",
            DateTime.UtcNow.AddDays(1));

        identityDb.Users.Add(user);
        identityDb.RefreshTokenSessions.AddRange(firstSession, secondSession);
        await identityDb.SaveChangesAsync();

        var first = await service.RevokeAdminUserSessionAsync(
            new AdminRevokeUserSessionCommand(
                Guid.NewGuid(),
                user.Id,
                firstSession.Id,
                "First operator action",
                "shared-operator-intent"),
            CancellationToken.None);
        var second = await service.RevokeAdminUserSessionAsync(
            new AdminRevokeUserSessionCommand(
                Guid.NewGuid(),
                user.Id,
                secondSession.Id,
                "Second operator action",
                "shared-operator-intent"),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(2, await identityDb.AuditEvents.CountAsync(
            auditEvent => auditEvent.Action == "admin.user.session.revoked"));
    }

    private static RefreshTokenSession CreateRefreshSession(
        Guid userId,
        string tokenHash,
        DateTime expiresAtUtc)
    {
        return new RefreshTokenSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TokenHash = tokenHash,
            CreatedAtUtc = DateTime.UtcNow.AddHours(-1),
            ExpiresAtUtc = expiresAtUtc
        };
    }
}
