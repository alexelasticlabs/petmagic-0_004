using Microsoft.Extensions.Caching.Memory;
using PetMagic.Modules.Identity.Api.Authentication;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class ExternalLoginCompletionStoreTests
{
    [Fact]
    public void Create_and_try_take_returns_payload_once()
    {
        using var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var store = new ExternalLoginCompletionStore(memoryCache);
        var session = CreateSession();

        var ticket = store.Create(session);

        var firstTake = store.TryTake(ticket, out var restoredSession);
        var secondTake = store.TryTake(ticket, out var missingSession);

        Assert.True(firstTake);
        Assert.NotNull(restoredSession);
        Assert.Equal(session.AccessToken, restoredSession!.AccessToken);
        Assert.Equal(session.RefreshToken, restoredSession.RefreshToken);
        Assert.False(secondTake);
        Assert.Null(missingSession);
    }

    [Fact]
    public void Try_take_returns_false_for_unknown_ticket()
    {
        using var memoryCache = new MemoryCache(new MemoryCacheOptions());
        var store = new ExternalLoginCompletionStore(memoryCache);

        var found = store.TryTake("missing-ticket", out var session);

        Assert.False(found);
        Assert.Null(session);
    }

    private static TokenPairResponse CreateSession()
    {
        return new TokenPairResponse(
            "access-token",
            "refresh-token",
            DateTime.UtcNow.AddMinutes(30),
            new UserProfileResponse(
                Guid.NewGuid(),
                "pet@example.com",
                "Pet Parent",
                false,
                true,
                ["user"],
                null));
    }
}