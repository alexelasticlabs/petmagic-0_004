using Microsoft.EntityFrameworkCore;

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

    private static SupportChatDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        return new SupportChatDbContext(options);
    }
}
