using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityAccessTokenValidatorTests
{
    [Fact]
    public async Task IsCurrentAsync_ShouldRequireAnActiveUserWithTheMatchingSecurityStamp()
    {
        var userId = Guid.NewGuid();
        const string securityStamp = "current-security-stamp";
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        await using var dbContext = new IdentityDbContext(options);
        dbContext.Users.Add(new AppUser
        {
            Id = userId,
            Email = "token-validator@petmagic.app",
            UserName = "token-validator@petmagic.app",
            NormalizedEmail = "TOKEN-VALIDATOR@PETMAGIC.APP",
            NormalizedUserName = "TOKEN-VALIDATOR@PETMAGIC.APP",
            IsActive = true,
            SecurityStamp = securityStamp,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var validator = new IdentityAccessTokenValidator(dbContext);

        Assert.True(await validator.IsCurrentAsync(userId, securityStamp, CancellationToken.None));
        Assert.False(await validator.IsCurrentAsync(userId, "stale-security-stamp", CancellationToken.None));

        var user = await dbContext.Users.SingleAsync();
        user.IsActive = false;
        await dbContext.SaveChangesAsync();

        Assert.False(await validator.IsCurrentAsync(userId, securityStamp, CancellationToken.None));

        dbContext.Users.Remove(user);
        await dbContext.SaveChangesAsync();

        Assert.False(await validator.IsCurrentAsync(userId, securityStamp, CancellationToken.None));
    }

    [Fact]
    public async Task IsCurrentAsync_ShouldRejectRevokedOrExpiredClaimedSessions()
    {
        var userId = Guid.NewGuid();
        var sessionId = Guid.NewGuid();
        const string securityStamp = "session-bound-security-stamp";
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        await using var dbContext = new IdentityDbContext(options);
        dbContext.Users.Add(new AppUser
        {
            Id = userId,
            Email = "session-token-validator@petmagic.app",
            UserName = "session-token-validator@petmagic.app",
            NormalizedEmail = "SESSION-TOKEN-VALIDATOR@PETMAGIC.APP",
            NormalizedUserName = "SESSION-TOKEN-VALIDATOR@PETMAGIC.APP",
            IsActive = true,
            SecurityStamp = securityStamp,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.RefreshTokenSessions.Add(new RefreshTokenSession
        {
            Id = sessionId,
            UserId = userId,
            TokenHash = "session-bound-token-hash",
            CreatedAtUtc = DateTime.UtcNow,
            ExpiresAtUtc = DateTime.UtcNow.AddDays(1)
        });
        await dbContext.SaveChangesAsync();

        var validator = new IdentityAccessTokenValidator(dbContext);

        Assert.True(
            await validator.IsCurrentAsync(
                userId,
                securityStamp,
                sessionId,
                CancellationToken.None));
        Assert.False(
            await validator.IsCurrentAsync(
                userId,
                securityStamp,
                Guid.NewGuid(),
                CancellationToken.None));

        var session = await dbContext.RefreshTokenSessions.SingleAsync();
        session.RevokedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        Assert.False(
            await validator.IsCurrentAsync(
                userId,
                securityStamp,
                sessionId,
                CancellationToken.None));
    }
}
