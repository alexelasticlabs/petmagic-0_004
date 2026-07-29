using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using Npgsql;

using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationMediaIdentityMigrationPostgresTests
{
    private const string PreviousMigration = "20260729153000_AddGenerationSchedulerHotPathIndexes";
    private const string IdentityIndex = "UX_tmr_GenerationResult_GenerationId_MediaType";

    [Fact]
    public async Task Migration_ShouldApplyToCleanAndExistingSchemasWithoutSplittingArtifacts()
    {
        var baseConnectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(baseConnectionString))
        {
            return;
        }

        var cleanSchema = $"tmr_clean_{Guid.NewGuid():N}";
        var existingSchema = $"tmr_existing_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, cleanSchema);
        await CreateSchemaAsync(baseConnectionString, existingSchema);

        try
        {
            await using (var cleanContext = CreateContext(baseConnectionString, cleanSchema))
            {
                var migrator = cleanContext.GetService<IMigrator>();
                await migrator.MigrateAsync();
                Assert.True(await IndexExistsAsync(baseConnectionString, cleanSchema, IdentityIndex));

                await migrator.MigrateAsync(PreviousMigration);
                Assert.False(await IndexExistsAsync(baseConnectionString, cleanSchema, IdentityIndex));

                await migrator.MigrateAsync();
                Assert.True(await IndexExistsAsync(baseConnectionString, cleanSchema, IdentityIndex));
            }

            var generationId = Guid.NewGuid();
            var generationResultId = Guid.NewGuid();
            var sourceUploadId = Guid.NewGuid();
            await using (var existingContext = CreateContext(baseConnectionString, existingSchema))
            {
                var migrator = existingContext.GetService<IMigrator>();
                await migrator.MigrateAsync(PreviousMigration);
                await existingContext.Database.ExecuteSqlInterpolatedAsync($$"""
                    INSERT INTO templates_media_records (
                        "Id", "Url", "FileName", "ContentType", "Role", "LifecycleState",
                        "UploadedAtUtc", "StoragePath", "WatermarkedStoragePath", "PreviewUrl",
                        "WatermarkedPreviewUrl", "MediaType", "SourceType", "GenerationId", "IsDeleted")
                    VALUES (
                        {{generationResultId}}, 'https://existing.example/result.webp', 'result.webp',
                        'image/webp', 6, 3, {{DateTime.UtcNow}}, 'generations/result.webp',
                        'generations/result-watermarked.webp', 'generations/result-preview.webp',
                        'generations/result-watermarked-preview.webp', 'image', 'generation_result',
                        {{generationId}}, FALSE),
                    (
                        {{sourceUploadId}}, 'https://existing.example/source.webp', 'source.webp',
                        'image/webp', 3, 3, {{DateTime.UtcNow}}, 'uploads/source.webp',
                        NULL, NULL, NULL, 'image', 'user_upload', {{generationId}}, FALSE);
                    """);

                await migrator.MigrateAsync();
            }

            Assert.True(await IndexExistsAsync(baseConnectionString, existingSchema, IdentityIndex));
            await using (var verificationContext = CreateContext(baseConnectionString, existingSchema))
            {
                var existing = await verificationContext.TemplateMediaRecords
                    .AsNoTracking()
                    .SingleAsync(record => record.Id == generationResultId);
                Assert.Equal("generations/result.webp", existing.StoragePath);
                Assert.Equal("generations/result-watermarked.webp", existing.WatermarkedStoragePath);
                Assert.Equal("generations/result-preview.webp", existing.PreviewUrl);
                Assert.Equal("generations/result-watermarked-preview.webp", existing.WatermarkedPreviewUrl);
                Assert.Equal(2, await verificationContext.TemplateMediaRecords
                    .CountAsync(record => record.GenerationId == generationId));
            }
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, cleanSchema);
            await DropSchemaAsync(baseConnectionString, existingSchema);
        }
    }

    [Fact]
    public async Task Migration_ShouldRejectLegacyGenerationResultDuplicatesBeforeCreatingIndex()
    {
        var baseConnectionString = Environment.GetEnvironmentVariable(
            "PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(baseConnectionString))
        {
            return;
        }

        var schema = $"tmr_duplicate_{Guid.NewGuid():N}";
        await CreateSchemaAsync(baseConnectionString, schema);
        try
        {
            var generationId = Guid.NewGuid();
            await using (var existingContext = CreateContext(baseConnectionString, schema))
            {
                var migrator = existingContext.GetService<IMigrator>();
                await migrator.MigrateAsync(PreviousMigration);
                await existingContext.Database.ExecuteSqlInterpolatedAsync($$"""
                    INSERT INTO templates_media_records (
                        "Id", "Url", "FileName", "ContentType", "Role", "LifecycleState",
                        "UploadedAtUtc", "StoragePath", "MediaType", "SourceType", "GenerationId",
                        "IsDeleted")
                    VALUES (
                        {{Guid.NewGuid()}}, 'https://duplicate.example/first.webp', 'first.webp',
                        'image/webp', 6, 3, {{DateTime.UtcNow}}, 'generations/first.webp',
                        'image', 'generation_result', {{generationId}}, FALSE),
                    (
                        {{Guid.NewGuid()}}, 'https://duplicate.example/second.webp', 'second.webp',
                        'image/webp', 6, 3, {{DateTime.UtcNow}}, 'generations/second.webp',
                        'image', 'generation_result', {{generationId}}, FALSE);
                    """);

                var migrationFailure = await Assert.ThrowsAnyAsync<Exception>(
                    () => migrator.MigrateAsync());
                var postgresFailure = FindPostgresException(migrationFailure);
                Assert.NotNull(postgresFailure);
                Assert.Contains("duplicate rows", postgresFailure!.MessageText, StringComparison.OrdinalIgnoreCase);
                Assert.Contains("Reconcile duplicate templates_media_records", postgresFailure.Hint);
            }

            Assert.False(await IndexExistsAsync(baseConnectionString, schema, IdentityIndex));
            await using var verificationContext = CreateContext(baseConnectionString, schema);
            Assert.Equal(2, await verificationContext.TemplateMediaRecords
                .CountAsync(record => record.GenerationId == generationId));
        }
        finally
        {
            await DropSchemaAsync(baseConnectionString, schema);
        }
    }

    private static TemplatesDbContext CreateContext(string baseConnectionString, string schema)
    {
        var connectionString = new NpgsqlConnectionStringBuilder(baseConnectionString)
        {
            SearchPath = schema
        }.ConnectionString;
        return new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql(connectionString)
                .Options);
    }

    private static async Task<bool> IndexExistsAsync(
        string baseConnectionString,
        string schema,
        string indexName)
    {
        await using var connection = new NpgsqlConnection(baseConnectionString);
        await connection.OpenAsync();
        await using var command = new NpgsqlCommand(
            "SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = $1 AND indexname = $2)",
            connection);
        command.Parameters.AddWithValue(schema);
        command.Parameters.AddWithValue(indexName);
        return (bool)(await command.ExecuteScalarAsync())!;
    }

    private static PostgresException? FindPostgresException(Exception exception)
    {
        for (var current = exception; current is not null; current = current.InnerException)
        {
            if (current is PostgresException postgresException)
            {
                return postgresException;
            }
        }

        return null;
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
