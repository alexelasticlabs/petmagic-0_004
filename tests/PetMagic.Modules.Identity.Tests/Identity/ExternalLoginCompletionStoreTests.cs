using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Api.Authentication;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class ExternalLoginCompletionStoreTests
{
    private static readonly LegalAcceptanceStatusResponse DefaultLegalAcceptance = new(
        true,
        "2026-05-20",
        DateTime.UtcNow,
        true,
        "2026-05-20",
        DateTime.UtcNow,
        "2026-05-20",
        "2026-05-20",
        false);

    [Fact]
    public async Task Create_and_try_take_returns_payload_once()
    {
        await using var services = CreateServices();
        var store = new ExternalLoginCompletionStore(
            services.GetRequiredService<IServiceScopeFactory>());
        var session = CreateSession();

        var ticket = await store.CreateAsync(session, CancellationToken.None);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            Assert.True(await dbContext.ExternalAuthTickets.AnyAsync(x => x.Ticket == ticket));
        }

        var restoredSession = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingSession = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.NotNull(restoredSession);
        Assert.Equal(session.AccessToken, restoredSession.AccessToken);
        Assert.Equal(session.RefreshToken, restoredSession.RefreshToken);
        Assert.Null(missingSession);
    }

    [Fact]
    public async Task Try_take_returns_false_for_unknown_ticket()
    {
        await using var services = CreateServices();
        var store = new ExternalLoginCompletionStore(
            services.GetRequiredService<IServiceScopeFactory>());

        var session = await store.TryTakeAsync("missing-ticket", CancellationToken.None);

        Assert.Null(session);
    }

    [Fact]
    public async Task Account_link_ticket_returns_user_once()
    {
        await using var services = CreateServices();
        var store = new ExternalAccountLinkStore(
            services.GetRequiredService<IServiceScopeFactory>());
        var userId = Guid.NewGuid();

        var ticket = await store.CreateAsync(userId, CancellationToken.None);

        var restoredUserId = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingUserId = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.Equal(userId, restoredUserId);
        Assert.Null(missingUserId);
    }

    private static ServiceProvider CreateServices()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        var services = new ServiceCollection();
        services.AddSingleton(connection);
        services.AddDbContext<IdentityDbContext>(options =>
            options.UseSqlite(connection));
        var serviceProvider = services.BuildServiceProvider();
        using var scope = serviceProvider.CreateScope();
        scope.ServiceProvider.GetRequiredService<IdentityDbContext>().Database.EnsureCreated();
        return serviceProvider;
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
                "Active",
                true,
                false,
                false,
                DefaultLegalAcceptance,
                ["user"],
                null));
    }
}
