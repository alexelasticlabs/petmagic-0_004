using Microsoft.EntityFrameworkCore;

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

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new TemplatesDbContext(options);
    }
}
