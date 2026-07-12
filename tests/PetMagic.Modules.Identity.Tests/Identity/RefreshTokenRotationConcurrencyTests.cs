using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class RefreshTokenRotationConcurrencyTests
{
    [Fact]
    public async Task ConcurrentRotationCas_ShouldPersistExactlyOneReplacementSession()
    {
        var databasePath = Path.Combine(
            Path.GetTempPath(),
            $"petmagic-refresh-rotation-tests-{Guid.NewGuid():N}.db");
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseSqlite($"Data Source={databasePath};Default Timeout=30;Pooling=False")
            .Options;
        var originalSessionId = Guid.NewGuid();
        var userId = Guid.NewGuid();

        try
        {
            await using (var seedContext = new IdentityDbContext(options))
            {
                await seedContext.Database.EnsureCreatedAsync();
                seedContext.RefreshTokenSessions.Add(new RefreshTokenSession
                {
                    Id = originalSessionId,
                    UserId = userId,
                    TokenHash = "original-token-hash",
                    CreatedAtUtc = DateTime.UtcNow.AddMinutes(-1),
                    ExpiresAtUtc = DateTime.UtcNow.AddDays(30)
                });
                await seedContext.SaveChangesAsync();
            }

            await using var firstContext = new IdentityDbContext(options);
            await using var secondContext = new IdentityDbContext(options);
            var firstOriginal = await firstContext.RefreshTokenSessions
                .SingleAsync(x => x.Id == originalSessionId);
            var secondOriginal = await secondContext.RefreshTokenSessions
                .SingleAsync(x => x.Id == originalSessionId);
            var revokedAtUtc = DateTime.UtcNow;

            firstOriginal.RevokedAtUtc = revokedAtUtc;
            firstContext.RefreshTokenSessions.Add(CreateReplacement(userId, "first-replacement-hash"));
            secondOriginal.RevokedAtUtc = revokedAtUtc;
            secondContext.RefreshTokenSessions.Add(CreateReplacement(userId, "second-replacement-hash"));

            await firstContext.SaveChangesAsync();
            await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => secondContext.SaveChangesAsync());

            await using var verificationContext = new IdentityDbContext(options);
            var sessions = await verificationContext.RefreshTokenSessions
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .ToListAsync();
            Assert.Equal(2, sessions.Count);
            Assert.NotNull(sessions.Single(x => x.Id == originalSessionId).RevokedAtUtc);
            Assert.Single(sessions, session => session.RevokedAtUtc is null);
            Assert.DoesNotContain(sessions, session => session.TokenHash == "second-replacement-hash");
        }
        finally
        {
            SqliteConnection.ClearAllPools();
            File.Delete(databasePath);
        }
    }

    private static RefreshTokenSession CreateReplacement(Guid userId, string tokenHash)
    {
        var now = DateTime.UtcNow;
        return new RefreshTokenSession
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            TokenHash = tokenHash,
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(30)
        };
    }
}
