using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;

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
}
