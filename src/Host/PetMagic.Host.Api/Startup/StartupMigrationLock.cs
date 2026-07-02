using Npgsql;

using Serilog;

namespace PetMagic.Host.Api.Startup;

/// <summary>
/// Serializes EF Core migrations and seed execution across API replicas using a PostgreSQL
/// session-level advisory lock. Without this, several replicas starting at the same time race
/// inside <c>Database.MigrateAsync()</c> and the seed upserts, which can fail the deployment or
/// leave the schema in a partially migrated state.
/// </summary>
internal static class StartupMigrationLock
{
    /// <summary>Stable, project-wide lock key ("PetMagic startup migrations"), must not collide with app-level advisory locks.</summary>
    private const long LockKey = 0x5065744D67_01;

    public static async Task RunWithMigrationLockAsync(
        string? connectionString,
        Func<Task> migrateAndSeed,
        TimeSpan acquireTimeout)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            // Non-relational/test hosting (e.g. integration tests with in-memory providers):
            // nothing to lock against, run directly.
            await migrateAndSeed();
            return;
        }

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();

        Log.Information(
            "Acquiring startup migration advisory lock. LockKey={LockKey} TimeoutSeconds={TimeoutSeconds}",
            LockKey,
            acquireTimeout.TotalSeconds);

        using var timeoutCts = new CancellationTokenSource(acquireTimeout);
        try
        {
            // Session-level lock: held until released or the connection closes, so a crashed
            // replica can never leave the lock stuck.
            await using var acquireCommand = connection.CreateCommand();
            acquireCommand.CommandText = "SELECT pg_advisory_lock(@key)";
            acquireCommand.Parameters.AddWithValue("key", LockKey);
            await acquireCommand.ExecuteNonQueryAsync(timeoutCts.Token);
        }
        catch (OperationCanceledException) when (timeoutCts.IsCancellationRequested)
        {
            throw new TimeoutException(
                $"Could not acquire the startup migration advisory lock within {acquireTimeout.TotalSeconds:F0}s. "
                + "Another replica is likely stuck applying migrations; refusing to start with an unverified schema.");
        }

        try
        {
            await migrateAndSeed();
            Log.Information("Startup migrations and seed data applied under advisory lock.");
        }
        finally
        {
            await using var releaseCommand = connection.CreateCommand();
            releaseCommand.CommandText = "SELECT pg_advisory_unlock(@key)";
            releaseCommand.Parameters.AddWithValue("key", LockKey);
            await releaseCommand.ExecuteNonQueryAsync();
        }
    }
}
