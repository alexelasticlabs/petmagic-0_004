using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportPushTokenServiceTests
{
    [Fact]
    public async Task RegisterAsync_ShouldRejectUndersizedTokenWithoutPersisting()
    {
        await using var dbContext = CreateDbContext();
        var service = new SupportPushTokenService(dbContext);

        var result = await service.RegisterAsync(
            new RegisterSupportPushTokenCommand(
                Guid.NewGuid(),
                "too-short-token-123",
                "android",
                "device-1",
                "1.0.0",
                "en-US"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(SupportChatErrors.InvalidPushToken.Code, result.Error.Code);
        Assert.Empty(await dbContext.SupportPushDeviceTokens.ToListAsync());
    }

    [Fact]
    public async Task UnregisterAsync_ShouldRejectUndersizedTokenWithoutMutatingState()
    {
        await using var dbContext = CreateDbContext();
        var service = new SupportPushTokenService(dbContext);

        var result = await service.UnregisterAsync(
            new UnregisterSupportPushTokenCommand(Guid.NewGuid(), "too-short-token-123"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(SupportChatErrors.InvalidPushToken.Code, result.Error.Code);
        Assert.Empty(await dbContext.SupportPushDeviceTokens.ToListAsync());
    }

    [Fact]
    public async Task RegisterAsync_ShouldDisableLegacyDuplicateTokens()
    {
        var userId = Guid.NewGuid();
        var oldUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "support-device-token-12345";
        await using var dbContext = CreateDbContext();
        dbContext.SupportPushDeviceTokens.AddRange(
            new()
            {
                Id = Guid.NewGuid(),
                UserId = oldUserId,
                Token = token,
                Platform = "ios",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new()
            {
                Id = Guid.NewGuid(),
                UserId = oldUserId,
                Token = token,
                Platform = "ios",
                CreatedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                LastSeenAtUtc = now.AddMinutes(-5)
            });
        await dbContext.SaveChangesAsync();

        var service = new SupportPushTokenService(dbContext);
        var result = await service.RegisterAsync(
            new RegisterSupportPushTokenCommand(userId, token, "iOS", "device-2", "2.0.0", "ru-RU"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var stored = await dbContext.SupportPushDeviceTokens
            .Where(x => x.Token == token)
            .ToListAsync();
        Assert.Equal(2, stored.Count);
        var active = Assert.Single(stored, x => x.DisabledAtUtc is null);
        Assert.Equal(userId, active.UserId);
        Assert.Equal("ios", active.Platform);
        Assert.Equal(SafeLogValues.StableHash("device-2"), active.DeviceId);
        Assert.DoesNotContain(stored, x => x.DeviceId == "device-2");
        Assert.All(stored.Where(x => x.Id != active.Id), x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task UnregisterAsync_ShouldDisableAllMatchingLegacyDuplicateTokens()
    {
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "support-device-token-12345";
        await using var dbContext = CreateDbContext();
        dbContext.SupportPushDeviceTokens.AddRange(
            new()
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = "ios",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new()
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = "ios",
                CreatedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                LastSeenAtUtc = now.AddMinutes(-5)
            });
        await dbContext.SaveChangesAsync();

        var service = new SupportPushTokenService(dbContext);
        var result = await service.UnregisterAsync(
            new UnregisterSupportPushTokenCommand(userId, token),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.All(
            await dbContext.SupportPushDeviceTokens.Where(x => x.Token == token).ToListAsync(),
            x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task RegisterAsync_ShouldKeepAtMostTenActiveTokensPerUser()
    {
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string currentToken = "support-device-token-current-12345";
        await using var dbContext = CreateDbContext();
        dbContext.SupportPushDeviceTokens.AddRange(
            Enumerable.Range(0, 10).Select(index => new PetMagic.Modules.SupportChat.Infrastructure.Entities.SupportPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = $"support-device-token-{index}-12345",
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-20 + index),
                UpdatedAtUtc = now.AddMinutes(-20 + index),
                LastSeenAtUtc = now.AddMinutes(-20 + index)
            }));
        await dbContext.SaveChangesAsync();

        var service = new SupportPushTokenService(dbContext);
        var result = await service.RegisterAsync(
            new RegisterSupportPushTokenCommand(userId, currentToken, "android", "device-new", "2.0.0", "en-US"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var activeTokens = await dbContext.SupportPushDeviceTokens
            .Where(x => x.UserId == userId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ToListAsync();
        Assert.Equal(10, activeTokens.Count);
        Assert.Contains(activeTokens, x => x.Token == currentToken);
        Assert.Contains(
            activeTokens,
            x => x.Token == currentToken
                && x.DeviceId == SafeLogValues.StableHash("device-new"));
        Assert.NotNull(await dbContext.SupportPushDeviceTokens
            .Where(x => x.Token == "support-device-token-0-12345")
            .Select(x => x.DisabledAtUtc)
            .SingleAsync());
    }

    private static SupportChatDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new SupportChatDbContext(options);
    }
}
