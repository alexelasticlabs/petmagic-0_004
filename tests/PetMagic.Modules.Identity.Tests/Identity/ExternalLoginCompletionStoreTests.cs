using System.Text.Json;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.ExternalAuthentication;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class ExternalLoginCompletionStoreTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

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
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());
        var session = CreateSession();

        var ticket = await store.CreateAsync(session, CancellationToken.None);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var persistedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.DoesNotContain(session.AccessToken, persistedTicket.PayloadJson);
            Assert.DoesNotContain(session.RefreshToken, persistedTicket.PayloadJson);
            Assert.DoesNotContain(session.User.Email, persistedTicket.PayloadJson);
        }

        var restoredSession = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingSession = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.NotNull(restoredSession);
        Assert.Equal(session.AccessToken, restoredSession.AccessToken);
        Assert.Equal(session.RefreshToken, restoredSession.RefreshToken);
        Assert.Null(missingSession);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var consumedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.NotNull(consumedTicket.ConsumedAtUtc);
            Assert.Equal("{}", consumedTicket.PayloadJson);
        }
    }

    [Fact]
    public async Task Concurrent_try_take_returns_login_payload_to_exactly_one_consumer()
    {
        var (services, databasePath) = CreateFileServices();
        try
        {
            var store = new ExternalLoginCompletionStore(
                services.GetRequiredService<IServiceScopeFactory>(),
                services.GetRequiredService<IDataProtectionProvider>());
            var ticket = await store.CreateAsync(CreateSession(), CancellationToken.None);

            var results = await Task.WhenAll(
                store.TryTakeAsync(ticket, CancellationToken.None),
                store.TryTakeAsync(ticket, CancellationToken.None));

            Assert.Single(results, result => result is not null);
            Assert.Single(results, result => result is null);
        }
        finally
        {
            await services.DisposeAsync();
            SqliteConnection.ClearAllPools();
            File.Delete(databasePath);
        }
    }

    [Fact]
    public async Task Try_take_returns_false_for_unknown_ticket()
    {
        await using var services = CreateServices();
        var store = new ExternalLoginCompletionStore(
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());

        var session = await store.TryTakeAsync("missing-ticket", CancellationToken.None);

        Assert.Null(session);
    }

    [Fact]
    public async Task Account_link_ticket_returns_user_once()
    {
        await using var services = CreateServices();
        var store = new ExternalAccountLinkStore(
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());
        var userId = Guid.NewGuid();

        var ticket = await store.CreateAsync(userId, CancellationToken.None);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var persistedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.DoesNotContain(userId.ToString("D"), persistedTicket.PayloadJson);
        }

        var restoredUserId = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingUserId = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.Equal(userId, restoredUserId);
        Assert.Null(missingUserId);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var consumedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.NotNull(consumedTicket.ConsumedAtUtc);
            Assert.Equal("\"\"", consumedTicket.PayloadJson);
        }
    }

    [Fact]
    public async Task Concurrent_try_take_returns_account_link_to_exactly_one_consumer()
    {
        var (services, databasePath) = CreateFileServices();
        try
        {
            var store = new ExternalAccountLinkStore(
                services.GetRequiredService<IServiceScopeFactory>(),
                services.GetRequiredService<IDataProtectionProvider>());
            var ticket = await store.CreateAsync(Guid.NewGuid(), CancellationToken.None);

            var results = await Task.WhenAll(
                store.TryTakeAsync(ticket, CancellationToken.None),
                store.TryTakeAsync(ticket, CancellationToken.None));

            Assert.Single(results, result => result.HasValue);
            Assert.Single(results, result => !result.HasValue);
        }
        finally
        {
            await services.DisposeAsync();
            SqliteConnection.ClearAllPools();
            File.Delete(databasePath);
        }
    }

    [Fact]
    public async Task Try_take_accepts_legacy_unprotected_payload_once()
    {
        await using var services = CreateServices();
        var session = CreateSession();
        var ticket = Guid.NewGuid().ToString("N");
        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            dbContext.ExternalAuthTickets.Add(new ExternalAuthTicket
            {
                Ticket = ticket,
                Purpose = "external_login_completion",
                PayloadJson = JsonSerializer.Serialize(session, JsonOptions),
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddMinutes(2)
            });
            await dbContext.SaveChangesAsync();
        }
        var store = new ExternalLoginCompletionStore(
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());

        var restoredSession = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingSession = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.NotNull(restoredSession);
        Assert.Equal(session.AccessToken, restoredSession.AccessToken);
        Assert.Equal(session.RefreshToken, restoredSession.RefreshToken);
        Assert.Null(missingSession);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var consumedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.NotNull(consumedTicket.ConsumedAtUtc);
            Assert.Equal("{}", consumedTicket.PayloadJson);
            Assert.DoesNotContain(session.AccessToken, consumedTicket.PayloadJson);
            Assert.DoesNotContain(session.RefreshToken, consumedTicket.PayloadJson);
        }
    }

    [Fact]
    public async Task Try_take_invalid_legacy_login_payload_returns_null_and_wipes_payload()
    {
        await using var services = CreateServices();
        var ticket = Guid.NewGuid().ToString("N");
        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            dbContext.ExternalAuthTickets.Add(new ExternalAuthTicket
            {
                Ticket = ticket,
                Purpose = "external_login_completion",
                PayloadJson = "not-json token=raw-secret",
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddMinutes(2)
            });
            await dbContext.SaveChangesAsync();
        }
        var store = new ExternalLoginCompletionStore(
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());

        var restoredSession = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingSession = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.Null(restoredSession);
        Assert.Null(missingSession);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var consumedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.NotNull(consumedTicket.ConsumedAtUtc);
            Assert.Equal("{}", consumedTicket.PayloadJson);
            Assert.DoesNotContain("raw-secret", consumedTicket.PayloadJson);
        }
    }

    [Fact]
    public async Task Account_link_invalid_payload_returns_null_and_wipes_payload()
    {
        await using var services = CreateServices();
        var ticket = Guid.NewGuid().ToString("N");
        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            dbContext.ExternalAuthTickets.Add(new ExternalAuthTicket
            {
                Ticket = ticket,
                Purpose = "external_account_link",
                PayloadJson = "not-json user-secret",
                CreatedAtUtc = DateTime.UtcNow,
                ExpiresAtUtc = DateTime.UtcNow.AddMinutes(5)
            });
            await dbContext.SaveChangesAsync();
        }
        var store = new ExternalAccountLinkStore(
            services.GetRequiredService<IServiceScopeFactory>(),
            services.GetRequiredService<IDataProtectionProvider>());

        var restoredUserId = await store.TryTakeAsync(ticket, CancellationToken.None);
        var missingUserId = await store.TryTakeAsync(ticket, CancellationToken.None);

        Assert.Null(restoredUserId);
        Assert.Null(missingUserId);

        using (var scope = services.CreateScope())
        {
            var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
            var consumedTicket = await dbContext.ExternalAuthTickets.SingleAsync(x => x.Ticket == ticket);
            Assert.NotNull(consumedTicket.ConsumedAtUtc);
            Assert.Equal("\"\"", consumedTicket.PayloadJson);
            Assert.DoesNotContain("user-secret", consumedTicket.PayloadJson);
        }
    }

    private static ServiceProvider CreateServices()
    {
        var connection = new SqliteConnection("Data Source=:memory:");
        connection.Open();
        var services = new ServiceCollection();
        services.AddSingleton(connection);
        services.AddDataProtection().UseEphemeralDataProtectionProvider();
        services.AddDbContext<IdentityDbContext>(options =>
            options.UseSqlite(connection));
        var serviceProvider = services.BuildServiceProvider();
        using var scope = serviceProvider.CreateScope();
        scope.ServiceProvider.GetRequiredService<IdentityDbContext>().Database.EnsureCreated();
        return serviceProvider;
    }

    private static (ServiceProvider Services, string DatabasePath) CreateFileServices()
    {
        var databasePath = Path.Combine(
            Path.GetTempPath(),
            $"petmagic-external-auth-ticket-tests-{Guid.NewGuid():N}.db");
        var services = new ServiceCollection();
        services.AddDataProtection().UseEphemeralDataProtectionProvider();
        services.AddDbContext<IdentityDbContext>(options =>
            options.UseSqlite($"Data Source={databasePath};Default Timeout=30;Pooling=False"));
        var serviceProvider = services.BuildServiceProvider();
        using var scope = serviceProvider.CreateScope();
        scope.ServiceProvider.GetRequiredService<IdentityDbContext>().Database.EnsureCreated();
        return (serviceProvider, databasePath);
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
