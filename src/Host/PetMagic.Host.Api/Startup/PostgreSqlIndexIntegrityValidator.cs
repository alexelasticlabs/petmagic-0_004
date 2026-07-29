using Npgsql;

using Serilog;

namespace PetMagic.Host.Api.Startup;

internal static class PostgreSqlIndexIntegrityValidator
{
    private static readonly IReadOnlyDictionary<string, string> RetryableConcurrentIndexMigrations =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["IX_tgj_Status_QueueMediaType_QueueTier_QueuedAtUtc"] = "20260630234809_AddGenerationSchedulerQueueFields",
            ["IX_tgj_Status_QueueMediaType_StartedAtUtc"] = "20260630234809_AddGenerationSchedulerQueueFields",
            ["IX_tgj_Status_ProviderStatusCheckedAtUtc"] = "20260701093000_AddAsyncGenerationProviderPipeline",
            ["IX_tgj_ChargedAtUtc"] = "20260702234729_AddGenerationBillingReconciliationIndexes",
            ["IX_tgj_CreatedAtUtc_Id"] = "20260702234729_AddGenerationBillingReconciliationIndexes",
            ["IX_tgj_RefundedAtUtc"] = "20260702234729_AddGenerationBillingReconciliationIndexes",
            ["IX_tgj_UpdatedAtUtc_Id"] = "20260702234729_AddGenerationBillingReconciliationIndexes",
            ["IX_tgj_PendingGamification"] = "20260710093545_AddGamificationSyncDeliveryState",
            ["IX_tgj_PendingGamificationShare"] = "20260710094027_AddGamificationShareDeliveryState",
            ["IX_tgj_ImportingMedia_NextAttempt"] = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments",
            ["IX_tgpa_Completed_Stage_ProviderCompletedAtUtc"] = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments",
            ["IX_tgj_Completed_MediaType_ImportCompletedAtUtc"] = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments",
            ["IX_tgj_UserId_QueueTier_LastAttemptAtUtc"] = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments",
            ["IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc"] = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments"
        };

    public static async Task RepairPendingMigrationIndexesAsync(
        string? connectionString,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await using var dataSource = NpgsqlDataSource.Create(connectionString);
        await RepairPendingMigrationIndexesAsync(dataSource, cancellationToken);
    }

    public static async Task RepairPendingMigrationIndexesAsync(
        NpgsqlDataSource dataSource,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(dataSource);
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        var invalidIndexes = await ReadInvalidIndexesAsync(connection, cancellationToken);
        if (invalidIndexes.Count == 0)
        {
            return;
        }

        var appliedMigrations = await ReadAppliedMigrationsAsync(connection, cancellationToken);
        var repairedIndexes = new HashSet<(string Schema, string Name)>();
        foreach (var index in invalidIndexes)
        {
            if (!RetryableConcurrentIndexMigrations.TryGetValue(index.Name, out var ownerMigration)
                || appliedMigrations.Contains(ownerMigration))
            {
                continue;
            }

            await using var dropCommand = connection.CreateCommand();
            dropCommand.CommandText =
                $"DROP INDEX CONCURRENTLY IF EXISTS {QuoteIdentifier(index.Schema)}.{QuoteIdentifier(index.Name)};";
            await dropCommand.ExecuteNonQueryAsync(cancellationToken);
            repairedIndexes.Add((index.Schema, index.Name));
            Log.Warning(
                "Removed invalid concurrent index left by an interrupted pending migration. Schema={Schema} Index={Index} Migration={Migration}",
                index.Schema,
                index.Name,
                ownerMigration);
        }

        var unresolvedIndexes = invalidIndexes
            .Where(index => !repairedIndexes.Contains((index.Schema, index.Name)))
            .ToArray();
        ThrowIfInvalidIndexesRemain(unresolvedIndexes);
    }

    public static async Task ValidateAsync(
        string? connectionString,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await using var dataSource = NpgsqlDataSource.Create(connectionString);
        await ValidateAsync(dataSource, cancellationToken);
    }

    public static async Task ValidateAsync(
        NpgsqlDataSource dataSource,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(dataSource);
        await using var connection = await dataSource.OpenConnectionAsync(cancellationToken);
        var invalidIndexes = await ReadInvalidIndexesAsync(connection, cancellationToken);
        ThrowIfInvalidIndexesRemain(invalidIndexes);
    }

    private static async Task<HashSet<string>> ReadAppliedMigrationsAsync(
        NpgsqlConnection connection,
        CancellationToken cancellationToken)
    {
        await using var existsCommand = connection.CreateCommand();
        existsCommand.CommandText = "SELECT to_regclass('\"__EFMigrationsHistory\"') IS NOT NULL;";
        var historyTableExists = (bool?)await existsCommand.ExecuteScalarAsync(cancellationToken) == true;
        if (!historyTableExists)
        {
            return new HashSet<string>(StringComparer.Ordinal);
        }

        var appliedMigrations = new HashSet<string>(StringComparer.Ordinal);
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT \"MigrationId\" FROM \"__EFMigrationsHistory\";";
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            appliedMigrations.Add(reader.GetString(0));
        }

        return appliedMigrations;
    }

    private static async Task<List<InvalidIndex>> ReadInvalidIndexesAsync(
        NpgsqlConnection connection,
        CancellationToken cancellationToken)
    {
        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT ns.nspname, idx.relname, i.indisvalid, i.indisready
            FROM pg_index AS i
            JOIN pg_class AS idx ON idx.oid = i.indexrelid
            JOIN pg_namespace AS ns ON ns.oid = idx.relnamespace
            WHERE (NOT i.indisvalid OR NOT i.indisready)
              AND ns.nspname NOT IN ('pg_catalog', 'information_schema')
              AND ns.nspname NOT LIKE 'pg_toast%'
            ORDER BY ns.nspname, idx.relname;
            """;

        var invalidIndexes = new List<InvalidIndex>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            invalidIndexes.Add(new InvalidIndex(
                reader.GetString(0),
                reader.GetString(1),
                reader.GetBoolean(2),
                reader.GetBoolean(3)));
        }

        return invalidIndexes;
    }

    private static void ThrowIfInvalidIndexesRemain(IReadOnlyCollection<InvalidIndex> invalidIndexes)
    {
        if (invalidIndexes.Count == 0)
        {
            return;
        }

        var details = string.Join(
            ", ",
            invalidIndexes.Select(index =>
                $"{QuoteIdentifier(index.Schema)}.{QuoteIdentifier(index.Name)}(valid={index.IsValid},ready={index.IsReady})"));
        var remediation = string.Join(
            " ",
            invalidIndexes.Select(index =>
                $"DROP INDEX CONCURRENTLY IF EXISTS {QuoteIdentifier(index.Schema)}.{QuoteIdentifier(index.Name)};"));

        throw new InvalidOperationException(
            $"PostgreSQL contains invalid or unfinished indexes: {details}. "
            + $"Run outside a transaction, then restart so the owning migration recreates the index: {remediation}");
    }

    private static string QuoteIdentifier(string value) => $"\"{value.Replace("\"", "\"\"")}\"";

    private sealed record InvalidIndex(string Schema, string Name, bool IsValid, bool IsReady);
}
