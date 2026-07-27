using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure;

internal static class AdminRoleInvariantExecutor
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const long AdvisoryLockKey = 0x5045544D524F4C45L;

    // The database advisory lock is the cross-replica guarantee. The local gate
    // keeps non-relational test providers and same-process callers deterministic.
    private static readonly SemaphoreSlim LocalGate = new(1, 1);

    public static async Task<TResult> ExecuteAsync<TResult>(
        IdentityDbContext dbContext,
        bool lockAdminInvariant,
        Func<CancellationToken, Task<TResult>> mutation,
        Func<TResult, bool> shouldCommit,
        CancellationToken cancellationToken)
    {
        if (lockAdminInvariant)
        {
            await LocalGate.WaitAsync(cancellationToken);
        }

        IDbContextTransaction? transaction = null;
        try
        {
            var isPostgres = IsPostgres(dbContext);
            if (dbContext.Database.IsRelational() && dbContext.Database.CurrentTransaction is null)
            {
                transaction = await dbContext.Database.BeginTransactionAsync(
                    isPostgres ? IsolationLevel.ReadCommitted : IsolationLevel.Serializable,
                    cancellationToken);
            }

            if (lockAdminInvariant && isPostgres)
            {
                await dbContext.Database.ExecuteSqlInterpolatedAsync(
                    $"SELECT pg_advisory_xact_lock({AdvisoryLockKey})",
                    cancellationToken);
            }

            var result = await mutation(cancellationToken);
            if (transaction is not null && shouldCommit(result))
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return result;
        }
        finally
        {
            if (transaction is not null)
            {
                await transaction.DisposeAsync();
            }

            if (lockAdminInvariant)
            {
                LocalGate.Release();
            }
        }
    }

    private static bool IsPostgres(IdentityDbContext dbContext)
    {
        return string.Equals(
            dbContext.Database.ProviderName,
            NpgsqlProviderName,
            StringComparison.Ordinal);
    }
}
