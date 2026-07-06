using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplatePushTokenServiceTests
{
    [Fact]
    public async Task RegisterAsync_ShouldRejectUndersizedTokenWithoutPersisting()
    {
        await using var dbContext = CreateDbContext();
        var service = new TemplatePushTokenService(dbContext);

        var result = await service.RegisterAsync(
            new RegisterTemplatePushTokenCommand(
                Guid.NewGuid(),
                "short-token",
                "android",
                "device-1",
                "1.0.0",
                "en-US"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.push_token_invalid", result.Error.Code);
        Assert.False(await dbContext.TemplatePushDeviceTokens.AnyAsync());
    }

    [Fact]
    public async Task UnregisterAsync_ShouldRejectUndersizedTokenWithoutMutatingState()
    {
        var userId = Guid.NewGuid();
        await using var dbContext = CreateDbContext();
        dbContext.TemplatePushDeviceTokens.Add(new()
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Token = "valid-device-token-12345",
            Platform = "android",
            DeviceId = "device-1",
            AppVersion = "1.0.0",
            Locale = "en-US",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
            LastSeenAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var service = new TemplatePushTokenService(dbContext);
        var result = await service.UnregisterAsync(
            new UnregisterTemplatePushTokenCommand(userId, "short-token"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("templates.push_token_invalid", result.Error.Code);

        var stored = await dbContext.TemplatePushDeviceTokens.SingleAsync();
        Assert.Null(stored.DisabledAtUtc);
    }

    [Fact]
    public async Task RegisterAsync_ShouldDisableLegacyDuplicateTokens()
    {
        var userId = Guid.NewGuid();
        var oldUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "template-device-token-12345";
        await using var dbContext = CreateDbContext();
        dbContext.TemplatePushDeviceTokens.AddRange(
            new()
            {
                Id = Guid.NewGuid(),
                UserId = oldUserId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new()
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

        var service = new TemplatePushTokenService(dbContext);
        var result = await service.RegisterAsync(
            new RegisterTemplatePushTokenCommand(userId, token, "Android", "device-2", "2.0.0", "ru-RU"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var stored = await dbContext.TemplatePushDeviceTokens
            .Where(x => x.Token == token)
            .ToListAsync();
        Assert.Equal(2, stored.Count);
        var active = Assert.Single(stored, x => x.DisabledAtUtc is null);
        Assert.Equal(userId, active.UserId);
        Assert.Equal("android", active.Platform);
        Assert.Equal(SafeLogValues.StableHash("device-2"), active.DeviceId);
        Assert.DoesNotContain(stored, x => x.DeviceId == "device-2");
        Assert.All(stored.Where(x => x.Id != active.Id), x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task UnregisterAsync_ShouldDisableAllMatchingLegacyDuplicateTokens()
    {
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string token = "template-device-token-12345";
        await using var dbContext = CreateDbContext();
        dbContext.TemplatePushDeviceTokens.AddRange(
            new()
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-10),
                UpdatedAtUtc = now.AddMinutes(-10),
                LastSeenAtUtc = now.AddMinutes(-10)
            },
            new()
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

        var service = new TemplatePushTokenService(dbContext);
        var result = await service.UnregisterAsync(
            new UnregisterTemplatePushTokenCommand(userId, token),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.All(
            await dbContext.TemplatePushDeviceTokens.Where(x => x.Token == token).ToListAsync(),
            x => Assert.NotNull(x.DisabledAtUtc));
    }

    [Fact]
    public async Task RegisterAsync_ShouldKeepAtMostTenActiveTokensPerUser()
    {
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        const string currentToken = "template-device-token-current-12345";
        await using var dbContext = CreateDbContext();
        dbContext.TemplatePushDeviceTokens.AddRange(
            Enumerable.Range(0, 10).Select(index => new PetMagic.Modules.Templates.Infrastructure.Entities.TemplatePushDeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = $"template-device-token-{index}-12345",
                Platform = "android",
                CreatedAtUtc = now.AddMinutes(-20 + index),
                UpdatedAtUtc = now.AddMinutes(-20 + index),
                LastSeenAtUtc = now.AddMinutes(-20 + index)
            }));
        await dbContext.SaveChangesAsync();

        var service = new TemplatePushTokenService(dbContext);
        var result = await service.RegisterAsync(
            new RegisterTemplatePushTokenCommand(userId, currentToken, "android", "device-new", "2.0.0", "en-US"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var activeTokens = await dbContext.TemplatePushDeviceTokens
            .Where(x => x.UserId == userId && x.DisabledAtUtc == null)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ToListAsync();
        Assert.Equal(10, activeTokens.Count);
        Assert.Contains(activeTokens, x => x.Token == currentToken);
        Assert.Contains(
            activeTokens,
            x => x.Token == currentToken
                && x.DeviceId == SafeLogValues.StableHash("device-new"));
        Assert.NotNull(await dbContext.TemplatePushDeviceTokens
            .Where(x => x.Token == "template-device-token-0-12345")
            .Select(x => x.DisabledAtUtc)
            .SingleAsync());
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new TemplatesDbContext(options);
    }
}
