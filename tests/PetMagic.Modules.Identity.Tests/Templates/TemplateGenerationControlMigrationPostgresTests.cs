using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using Npgsql;

using PetMagic.Host.Api.Startup;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

[Collection(TemplateGenerationLocalConcurrencyCollection.Name)]
public sealed class TemplateGenerationControlMigrationPostgresTests
{
    private const string PreviousMigration = "20260727153000_AddTemplateModerationLeases";
    private const string FoundationMigration = "20260728231704_AddGenerationControlFoundation";
    private const string HotPathMigration = "20260729153000_AddGenerationSchedulerHotPathIndexes";
    private const string IdentityMigration = "20260729184500_EnforceGenerationResultMediaIdentity";
    private const string RepairMigration = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments";
    private const string LegacyPolicyId = "f4d755ca-bf45-4ab7-92bf-b7a7ef6844c1";

    private static readonly IReadOnlyDictionary<string, string> HotPathIndexes =
        new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["IX_tgj_ImportingMedia_NextAttempt"] = "templates_generation_jobs",
            ["IX_tgpa_Completed_Stage_ProviderCompletedAtUtc"] = "templates_generation_provider_attempts",
            ["IX_tgj_Completed_MediaType_ImportCompletedAtUtc"] = "templates_generation_jobs",
            ["IX_tgj_UserId_QueueTier_LastAttemptAtUtc"] = "templates_generation_jobs",
            ["IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc"] = "templates_provider_webhook_inbox"
        };

    [Fact]
    public async Task FoundationMigration_ShouldPreserveLegacyV1PolicyAndPauseState()
    {
        var baseConnectionString = ResolvePostgresConnectionString();
        if (baseConnectionString is null)
        {
            return;
        }

        var schema = $"generation_v1_upgrade_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            await using var context = CreateContext(baseConnectionString, schema);
            var migrator = context.GetService<IMigrator>();
            await migrator.MigrateAsync(PreviousMigration);

            var updatedByAdminId = Guid.NewGuid();
            var updatedAtUtc = DateTime.UtcNow.AddMinutes(-10);
            await SeedLegacyPolicyAsync(context, updatedByAdminId, updatedAtUtc);

            await migrator.MigrateAsync(FoundationMigration);
            context.ChangeTracker.Clear();

            var policy = await context.TemplateGenerationControlPolicies.AsNoTracking().SingleAsync();
            Assert.Equal(7, policy.Revision);
            Assert.False(policy.AdmissionEnabled);
            Assert.Equal(40, policy.ConfirmedFalConcurrencyLimit);
            Assert.Equal(2, policy.ReservedHeadroom);
            Assert.Equal(32, policy.ApplicationHardCeiling);
            Assert.Equal(32, policy.BaseGlobalMaxConcurrentGenerations);
            Assert.Equal(12, policy.BaseImageReservedConcurrentGenerations);
            Assert.Equal(12, policy.BaseImageProtectedConcurrentGenerations);
            Assert.Equal(28, policy.BaseImageMaxConcurrentGenerations);
            Assert.Equal(8, policy.BaseVideoReservedConcurrentGenerations);
            Assert.Equal(16, policy.BaseVideoMaxConcurrentGenerations);
            Assert.Equal(6, policy.BaseVideoBorrowMaxConcurrentGenerations);
            Assert.Equal(1, policy.BaseVideoPreprocessingMaxConcurrentGenerations);
            Assert.Equal(updatedByAdminId, policy.UpdatedByAdminUserId);
            Assert.Equal("operator paused v1 admission", policy.LastReason);
            Assert.True(await RelationExistsAsync(baseConnectionString, schema, "templates_generation_runtime_settings"));
            Assert.Equal(1, await CountRowsAsync(baseConnectionString, schema, "templates_generation_runtime_settings"));

            await migrator.MigrateAsync();
            context.ChangeTracker.Clear();
            var finalPolicy = await context.TemplateGenerationControlPolicies.AsNoTracking().SingleAsync();
            Assert.Equal(7, finalPolicy.Revision);
            Assert.False(finalPolicy.AdmissionEnabled);
            Assert.Equal("operator paused v1 admission", finalPolicy.LastReason);
            Assert.True(await MigrationIsAppliedAsync(baseConnectionString, schema, RepairMigration));
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    [Fact]
    public async Task RepairMigration_ShouldUpgradeExistingDatabaseWithOldMigrationsAlreadyApplied()
    {
        var baseConnectionString = ResolvePostgresConnectionString();
        if (baseConnectionString is null)
        {
            return;
        }

        var schema = $"generation_index_retry_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            var scopedConnectionString = ScopeConnectionString(baseConnectionString, schema);
            await using var context = CreateContext(baseConnectionString, schema);
            var migrator = context.GetService<IMigrator>();
            await migrator.MigrateAsync(IdentityMigration);
            Assert.True(await MigrationIsAppliedAsync(baseConnectionString, schema, FoundationMigration));
            Assert.True(await MigrationIsAppliedAsync(baseConnectionString, schema, HotPathMigration));
            Assert.True(await MigrationIsAppliedAsync(baseConnectionString, schema, IdentityMigration));
            Assert.False(await MigrationIsAppliedAsync(baseConnectionString, schema, RepairMigration));

            var updatedByAdminId = Guid.NewGuid();
            var updatedAtUtc = DateTime.UtcNow.AddMinutes(-10);
            await SeedLegacyPolicyAsync(context, updatedByAdminId, updatedAtUtc);

            await context.Database.ExecuteSqlRawAsync(
                "CREATE TABLE retry_probe (value integer NOT NULL); "
                + "INSERT INTO retry_probe (value) VALUES (1), (1);");
            await context.Database.ExecuteSqlRawAsync(
                "DROP INDEX IF EXISTS \"IX_tgj_ImportingMedia_NextAttempt\"; "
                + "DROP INDEX IF EXISTS \"IX_tgpa_Completed_Stage_ProviderCompletedAtUtc\"; "
                + "DROP INDEX IF EXISTS \"IX_tgj_Completed_MediaType_ImportCompletedAtUtc\"; "
                + "DROP INDEX IF EXISTS \"IX_tgj_UserId_QueueTier_LastAttemptAtUtc\"; "
                + "DROP INDEX IF EXISTS \"IX_tpwbi_Processing_LockedAtUtc_NextAttemptAtUtc\";");

            await using (var connection = new NpgsqlConnection(scopedConnectionString))
            {
                await connection.OpenAsync();
                await using var interruptedBuild = new NpgsqlCommand(
                    "CREATE UNIQUE INDEX CONCURRENTLY \"IX_tgj_ImportingMedia_NextAttempt\" ON retry_probe (value);",
                    connection);
                await Assert.ThrowsAsync<PostgresException>(() => interruptedBuild.ExecuteNonQueryAsync());
            }

            var invalidBeforeRepair = await ReadIndexStateAsync(
                baseConnectionString,
                schema,
                "IX_tgj_ImportingMedia_NextAttempt");
            Assert.NotNull(invalidBeforeRepair);
            Assert.False(invalidBeforeRepair!.Value.IsValid);

            await PostgreSqlIndexIntegrityValidator.RepairPendingMigrationIndexesAsync(scopedConnectionString);
            Assert.Null(await ReadIndexStateAsync(
                baseConnectionString,
                schema,
                "IX_tgj_ImportingMedia_NextAttempt"));

            await context.Database.ExecuteSqlRawAsync(
                "CREATE INDEX \"IX_tgj_Completed_MediaType_ImportCompletedAtUtc\" ON retry_probe (value);");

            await migrator.MigrateAsync(RepairMigration);
            await migrator.MigrateAsync(RepairMigration);

            context.ChangeTracker.Clear();
            var policy = await context.TemplateGenerationControlPolicies.AsNoTracking().SingleAsync();
            Assert.Equal(7, policy.Revision);
            Assert.False(policy.AdmissionEnabled);
            Assert.Equal(40, policy.ConfirmedFalConcurrencyLimit);
            Assert.Equal(32, policy.ApplicationHardCeiling);
            Assert.Equal(updatedByAdminId, policy.UpdatedByAdminUserId);
            Assert.Equal("operator paused v1 admission", policy.LastReason);
            Assert.True(await RelationExistsAsync(baseConnectionString, schema, "templates_generation_runtime_settings"));

            foreach (var (indexName, expectedTable) in HotPathIndexes)
            {
                var index = await ReadIndexStateAsync(baseConnectionString, schema, indexName);
                Assert.NotNull(index);
                Assert.True(index!.Value.IsValid, indexName);
                Assert.True(index.Value.IsReady, indexName);
                Assert.Equal(expectedTable, index.Value.TableName);
            }

            Assert.True(await MigrationIsAppliedAsync(baseConnectionString, schema, RepairMigration));
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    [Fact]
    public async Task RepairMigration_ShouldNotOverwriteRuntimePolicyChangedAfterBootstrap()
    {
        var baseConnectionString = ResolvePostgresConnectionString();
        if (baseConnectionString is null)
        {
            return;
        }

        var schema = $"generation_policy_guard_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            await using var context = CreateContext(baseConnectionString, schema);
            var migrator = context.GetService<IMigrator>();
            await migrator.MigrateAsync(IdentityMigration);
            await SeedLegacyPolicyAsync(context, Guid.NewGuid(), DateTime.UtcNow.AddMinutes(-10));

            var runtimeAdminId = Guid.NewGuid();
            var runtimeUpdatedAtUtc = DateTime.UtcNow.AddMinutes(-1);
            await context.TemplateGenerationControlPolicies.ExecuteUpdateAsync(setters => setters
                .SetProperty(policy => policy.Revision, 9)
                .SetProperty(policy => policy.AdmissionEnabled, true)
                .SetProperty(policy => policy.ConfirmedFalConcurrencyLimit, 20)
                .SetProperty(policy => policy.ConfirmedAtUtc, runtimeUpdatedAtUtc)
                .SetProperty(policy => policy.UpdatedAtUtc, runtimeUpdatedAtUtc)
                .SetProperty(policy => policy.UpdatedByAdminUserId, runtimeAdminId)
                .SetProperty(policy => policy.LastReason, "runtime admin capacity review"));

            await migrator.MigrateAsync(RepairMigration);
            context.ChangeTracker.Clear();

            var policy = await context.TemplateGenerationControlPolicies.AsNoTracking().SingleAsync();
            Assert.Equal(9, policy.Revision);
            Assert.True(policy.AdmissionEnabled);
            Assert.Equal(20, policy.ConfirmedFalConcurrencyLimit);
            Assert.Equal(runtimeAdminId, policy.UpdatedByAdminUserId);
            Assert.Equal("runtime admin capacity review", policy.LastReason);
            Assert.True(await RelationExistsAsync(baseConnectionString, schema, "templates_generation_runtime_settings"));
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    private static async Task SeedLegacyPolicyAsync(
        TemplatesDbContext context,
        Guid updatedByAdminId,
        DateTime updatedAtUtc)
    {
        await context.Database.ExecuteSqlInterpolatedAsync($$"""
            CREATE TABLE templates_generation_runtime_settings (
                "Id" uuid PRIMARY KEY,
                "Version" bigint NOT NULL,
                "NewClaimsPaused" boolean NOT NULL,
                "FalConfiguredConcurrency" integer NOT NULL,
                "FalReservedConcurrency" integer NOT NULL,
                "GlobalMaxConcurrent" integer NOT NULL,
                "ImageProtectedConcurrent" integer NOT NULL,
                "ImageMaxConcurrent" integer NOT NULL,
                "VideoGuaranteedConcurrent" integer NOT NULL,
                "VideoMaxConcurrent" integer NOT NULL,
                "VideoBorrowMaxConcurrent" integer NOT NULL,
                "UpdatedAtUtc" timestamp with time zone NOT NULL,
                "UpdatedByAdminId" uuid NULL,
                "LastChangeReason" text NULL
            );

            INSERT INTO templates_generation_runtime_settings (
                "Id", "Version", "NewClaimsPaused", "FalConfiguredConcurrency",
                "FalReservedConcurrency", "GlobalMaxConcurrent", "ImageProtectedConcurrent",
                "ImageMaxConcurrent", "VideoGuaranteedConcurrent", "VideoMaxConcurrent",
                "VideoBorrowMaxConcurrent", "UpdatedAtUtc", "UpdatedByAdminId", "LastChangeReason")
            VALUES (
                {{Guid.Parse(LegacyPolicyId)}}, 7, TRUE, 40, 2, 32, 12, 28, 8, 16, 6,
                {{updatedAtUtc}}, {{updatedByAdminId}}, 'operator paused v1 admission');
            """);
    }

    private static TemplatesDbContext CreateContext(string baseConnectionString, string schema) =>
        new(new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseNpgsql(ScopeConnectionString(baseConnectionString, schema))
            .Options);

    private static string ScopeConnectionString(string baseConnectionString, string schema) =>
        new NpgsqlConnectionStringBuilder(baseConnectionString)
        {
            SearchPath = schema
        }.ConnectionString;

    private static string? ResolvePostgresConnectionString()
    {
        var connectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        return string.IsNullOrWhiteSpace(connectionString) ? null : connectionString;
    }

    private static async Task<(bool IsValid, bool IsReady, string TableName)?> ReadIndexStateAsync(
        string baseConnectionString,
        string schema,
        string indexName)
    {
        await using var connection = new NpgsqlConnection(baseConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            """
            SELECT i.indisvalid, i.indisready, table_rel.relname
            FROM pg_index AS i
            JOIN pg_class AS index_rel ON index_rel.oid = i.indexrelid
            JOIN pg_class AS table_rel ON table_rel.oid = i.indrelid
            JOIN pg_namespace AS ns ON ns.oid = index_rel.relnamespace
            WHERE ns.nspname = $1 AND index_rel.relname = $2;
            """,
            connection);
        command.Parameters.AddWithValue(schema);
        command.Parameters.AddWithValue(indexName);
        await using var reader = await command.ExecuteReaderAsync();
        return await reader.ReadAsync()
            ? (reader.GetBoolean(0), reader.GetBoolean(1), reader.GetString(2))
            : null;
    }

    private static async Task<bool> MigrationIsAppliedAsync(
        string baseConnectionString,
        string schema,
        string migrationId)
    {
        await using var connection = new NpgsqlConnection(ScopeConnectionString(baseConnectionString, schema));
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            "SELECT EXISTS (SELECT 1 FROM \"__EFMigrationsHistory\" WHERE \"MigrationId\" = $1);",
            connection);
        command.Parameters.AddWithValue(migrationId);
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    private static async Task<bool> RelationExistsAsync(
        string baseConnectionString,
        string schema,
        string relationName)
    {
        await using var connection = new NpgsqlConnection(baseConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand("SELECT to_regclass($1) IS NOT NULL;", connection);
        command.Parameters.AddWithValue($"{schema}.{relationName}");
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    private static async Task<long> CountRowsAsync(
        string baseConnectionString,
        string schema,
        string tableName)
    {
        await using var connection = new NpgsqlConnection(baseConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            $"SELECT COUNT(*) FROM \"{schema}\".\"{tableName}\";",
            connection);
        return (long)(await command.ExecuteScalarAsync())!;
    }

    private static async Task CreateSchemaAsync(string connectionString, string schema)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"CREATE SCHEMA \"{schema}\"", connection);
        await command.ExecuteNonQueryAsync();
    }

    private static async Task DropSchemaAsync(string connectionString, string schema)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand($"DROP SCHEMA IF EXISTS \"{schema}\" CASCADE", connection);
        await command.ExecuteNonQueryAsync();
    }
}
