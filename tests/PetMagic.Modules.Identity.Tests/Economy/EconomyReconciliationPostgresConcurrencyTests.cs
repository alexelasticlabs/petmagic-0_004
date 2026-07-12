using System.Reflection;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Options;

using Npgsql;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyReconciliationPostgresConcurrencyTests
{
    private const long ReconciliationAdvisoryLockKey = 0x5065744D67_02;

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldRejectConcurrentPostgresLease()
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await using var leaseConnection = new NpgsqlConnection(connectionString);
        await leaseConnection.OpenAsync();
        await using var acquireCommand = leaseConnection.CreateCommand();
        acquireCommand.CommandText = "SELECT pg_advisory_lock(@key)";
        acquireCommand.Parameters.AddWithValue("key", ReconciliationAdvisoryLockKey);
        await acquireCommand.ExecuteNonQueryAsync();

        try
        {
            var dbOptions = new DbContextOptionsBuilder<EconomyDbContext>()
                .UseNpgsql(connectionString)
                .Options;
            await using var dbContext = new EconomyDbContext(dbOptions);
            using var memoryCache = new MemoryCache(new MemoryCacheOptions());
            var service = new EconomyService(
                dbContext,
                DispatchProxy.Create<IPaymentGateway, UnusedDependencyProxy>(),
                DispatchProxy.Create<IStoreSubscriptionVerifier, UnusedDependencyProxy>(),
                Options.Create(new EconomyOptions()),
                memoryCache);

            var result = await service.RunEconomyReconciliationAsync(CancellationToken.None);

            Assert.True(result.IsFailure);
            Assert.Equal(EconomyErrors.ReconciliationAlreadyRunning.Code, result.Error.Code);
        }
        finally
        {
            await using var releaseCommand = leaseConnection.CreateCommand();
            releaseCommand.CommandText = "SELECT pg_advisory_unlock(@key)";
            releaseCommand.Parameters.AddWithValue("key", ReconciliationAdvisoryLockKey);
            await releaseCommand.ExecuteNonQueryAsync();
        }
    }

    public class UnusedDependencyProxy : DispatchProxy
    {
        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            throw new InvalidOperationException($"Unexpected dependency call: {targetMethod?.Name ?? "unknown"}.");
        }
    }
}
