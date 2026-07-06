using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task RegisterPushTokenAsync_ShouldRejectOversizedTokenWithoutPersisting()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(
                Guid.NewGuid(),
                new string('x', 513),
                "android",
                "device-1",
                "1.0.0",
                "en-US"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidPushToken.Code, result.Error.Code);
        Assert.Empty(await dbContext.EconomyPushDeviceTokens.ToListAsync());
    }

    [Fact]
    public async Task UnregisterPushTokenAsync_ShouldNotDisableTokenMovedToAnotherUser()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        const string token = "economy-device-token-1234567890";

        var firstRegister = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(
                firstUserId,
                token,
                "android",
                "device-1",
                "1.0.0",
                "en-US"),
            CancellationToken.None);
        var secondRegister = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(
                secondUserId,
                token,
                "android",
                "device-1",
                "1.0.0",
                "en-US"),
            CancellationToken.None);

        Assert.True(firstRegister.IsSuccess);
        Assert.True(secondRegister.IsSuccess);

        var staleUnregister = await service.UnregisterPushTokenAsync(
            new UnregisterEconomyPushTokenCommand(firstUserId, token),
            CancellationToken.None);

        Assert.True(staleUnregister.IsSuccess);

        var persisted = await dbContext.EconomyPushDeviceTokens.SingleAsync(x => x.Token == token);
        Assert.Equal(secondUserId, persisted.UserId);
        Assert.Null(persisted.DisabledAtUtc);
    }

    [Fact]
    public async Task RegisterPushTokenAsync_ShouldDisableLegacyDuplicateTokens()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var oldUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "economy-device-token-1234567890";
        dbContext.EconomyPushDeviceTokens.AddRange(
            new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = oldUserId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = oldUserId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                LastSeenAtUtc = now.AddMinutes(-5)
            });
        await dbContext.SaveChangesAsync();

        var result = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(userId, token, "android", "device-2", "2.0.0", "ru-RU"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var stored = await dbContext.EconomyPushDeviceTokens
            .Where(x => x.Token == token)
            .ToListAsync();
        Assert.Equal(2, stored.Count);
        var active = Assert.Single(stored, x => x.DisabledAtUtc is null);
        Assert.Equal(userId, active.UserId);
        Assert.Equal(SafeLogValues.StableHash("device-2"), active.DeviceId);
        Assert.DoesNotContain(stored, x => x.DeviceId == "device-2");
        Assert.All(stored.Where(x => x.Id != active.Id), x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task UnregisterPushTokenAsync_ShouldDisableAllMatchingLegacyDuplicateTokens()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "economy-device-token-1234567890";
        dbContext.EconomyPushDeviceTokens.AddRange(
            new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-5),
                UpdatedAtUtc = now.AddMinutes(-5),
                LastSeenAtUtc = now.AddMinutes(-5)
            });
        await dbContext.SaveChangesAsync();

        var result = await service.UnregisterPushTokenAsync(
            new UnregisterEconomyPushTokenCommand(userId, token),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.All(
            await dbContext.EconomyPushDeviceTokens.Where(x => x.Token == token).ToListAsync(),
            x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task RegisterPushTokenAsync_ShouldKeepAtMostTenActiveTokensPerUser()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string currentToken = "economy-device-token-current-1234567890";
        dbContext.EconomyPushDeviceTokens.AddRange(
            Enumerable.Range(0, 10).Select(index => new EconomyPushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = $"economy-device-token-{index}-1234567890",
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-20 + index),
                UpdatedAtUtc = now.AddMinutes(-20 + index),
                LastSeenAtUtc = now.AddMinutes(-20 + index)
            }));
        await dbContext.SaveChangesAsync();

        var result = await service.RegisterPushTokenAsync(
            new RegisterEconomyPushTokenCommand(userId, currentToken, "android", "device-new", "2.0.0", "en-US"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var activeTokens = await dbContext.EconomyPushDeviceTokens
            .Where(x => x.UserId == userId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ToListAsync();
        Assert.Equal(10, activeTokens.Count);
        Assert.Contains(activeTokens, x => x.Token == currentToken);
        Assert.Contains(
            activeTokens,
            x => x.Token == currentToken
                && x.DeviceId == SafeLogValues.StableHash("device-new"));
        Assert.NotNull(await dbContext.EconomyPushDeviceTokens
            .Where(x => x.Token == "economy-device-token-0-1234567890")
            .Select(x => x.DisabledAtUtc)
            .SingleAsync());
    }
}
