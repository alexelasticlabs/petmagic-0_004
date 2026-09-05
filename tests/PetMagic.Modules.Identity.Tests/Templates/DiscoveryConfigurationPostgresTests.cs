using System.Runtime.CompilerServices;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;

using Npgsql;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class DiscoveryConfigurationPostgresTests
{
    private const string PreviousMigration = "20260729213000_RepairGenerationSchedulerV2ExistingDeployments";

    [DiscoveryPostgresFact]
    public async Task DiscoveryMigration_ShouldApplyToCleanAndExistingDatabaseAndPreserveCatalog()
    {
        await using var database = await TestDatabase.CreateAsync();
        await using var db = database.Context();
        var migrator = db.GetService<IMigrator>();
        await migrator.MigrateAsync();
        Assert.Equal(0, (await db.TemplateDiscoveryPages.AsNoTracking().SingleAsync()).Version);
        Assert.False(db.Database.HasPendingModelChanges());
        await migrator.MigrateAsync(PreviousMigration);
        var categoryId = Guid.NewGuid();
        db.TemplateCategories.Add(new() { Id = categoryId, Name = "Existing", NormalizedName = "EXISTING", CreatedAtUtc = DateTime.UtcNow, UpdatedAtUtc = DateTime.UtcNow });
        await db.SaveChangesAsync();
        await migrator.MigrateAsync();
        Assert.Equal("Existing", (await db.TemplateCategories.AsNoTracking().SingleAsync()).Name);
        Assert.Null((await db.TemplateDiscoveryPages.AsNoTracking().SingleAsync()).PublishedRevisionId);
    }

    [DiscoveryPostgresFact]
    public async Task DiscoveryPublish_ShouldResolvePostgresProjectionAndProtectAtomicConcurrentPublication()
    {
        await using var database = await TestDatabase.CreateAsync();
        await using var setup = database.Context();
        await setup.Database.MigrateAsync();
        var categoryId = Guid.NewGuid();
        var templateId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        setup.TemplateCategories.Add(new() { Id = categoryId, Name = "Funny", NormalizedName = "FUNNY", CreatedAtUtc = now, UpdatedAtUtc = now });
        setup.TemplateItems.Add(new()
        {
            Id = templateId,
            Title = "Public template",
            ShortDescription = "Preview",
            Category = "Funny",
            Tags = "[]",
            TemplateType = TemplateType.Image,
            Status = TemplateStatus.Active,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            Assets = [new() { Id = Guid.NewGuid(), TemplateId = templateId, AssetKind = TemplateAssetKind.Preview,
                Url = "https://cdn.example.com/discovery.jpg", FileName = "discovery.jpg", ContentType = "image/jpeg" }]
        });
        await setup.SaveChangesAsync();
        var actor = Guid.NewGuid();
        var admin = new TemplateDiscoveryAdminService(setup);
        var draft = (await admin.CreateDraftAsync(actor, new(0), default)).Value;
        // Materialize both tracked revisions before either writer saves, forcing a real optimistic conflict.
        await using var left = database.Context();
        await using var right = database.Context();
        await left.TemplateDiscoveryRevisions.SingleAsync(row => row.Id == draft.Id);
        await right.TemplateDiscoveryRevisions.SingleAsync(row => row.Id == draft.Id);
        var leftService = new TemplateDiscoveryAdminService(left);
        var rightService = new TemplateDiscoveryAdminService(right);
        var saves = await Task.WhenAll(
            leftService.SaveDraftAsync(actor, draft.Id, new(1, draft.Document with { AutoplayIntervalMs = 9000 }), default),
            rightService.SaveDraftAsync(actor, draft.Id, new(1, draft.Document with { AutoplayIntervalMs = 11000 }), default));
        Assert.Single(saves, result => result.IsSuccess);
        Assert.Single(saves, result => result.IsFailure && result.Error.Code == "discovery.conflict");
        await using var firstPublisher = database.Context();
        await using var secondPublisher = database.Context();
        var request = new PublishDiscoveryRequest(2, 1, "Concurrent publication");
        var publications = await Task.WhenAll(
            new TemplateDiscoveryAdminService(firstPublisher).PublishAsync(actor, draft.Id, "same-command", request, default),
            new TemplateDiscoveryAdminService(secondPublisher).PublishAsync(actor, draft.Id, "same-command", request, default));
        Assert.All(publications, result => Assert.True(result.IsSuccess));
        await using var check = database.Context();
        Assert.Single(await check.TemplateDiscoveryCommandReceipts.ToArrayAsync());
        Assert.Equal(2, (await check.TemplateDiscoveryPages.SingleAsync()).Version);
        Assert.Single(await check.TemplateRealtimeEvents.Where(row => row.Data!.Contains("discovery_published")).ToArrayAsync());
        Assert.Single(await check.PushOutboxMessages.Where(row => row.Kind == "admin_audit").ToArrayAsync(),
            row => row.PayloadJson.Contains("templates.discovery.published", StringComparison.Ordinal));
        var reader = new TemplateDiscoveryAdminService(check);
        var preview = await reader.PreviewAsync(draft.Id, "ru", default);
        Assert.Equal(templateId, Assert.Single(Assert.Single(preview.Value.Sections).Items).Id);
        var restored = await reader.CreateDraftAsync(actor, new(2, draft.Id), default);
        Assert.Equal(2, restored.Value.Number);
        Assert.Equal(draft.Id, (await reader.GetAsync(default)).Published!.Id);
    }

    public sealed class DiscoveryPostgresFactAttribute : FactAttribute
    {
        public DiscoveryPostgresFactAttribute([CallerFilePath] string? sourceFilePath = null, [CallerLineNumber] int sourceLineNumber = 0)
            : base(sourceFilePath, sourceLineNumber)
        {
            if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING")))
                Skip = "Requires isolated PostgreSQL via PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING.";
        }
    }

    private sealed class TestDatabase(string connectionString, string schema) : IAsyncDisposable
    {
        internal static async Task<TestDatabase> CreateAsync()
        {
            var baseConnection = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING")!;
            var schema = $"discovery_qa_{Guid.NewGuid():N}";
            await using var connection = new NpgsqlConnection(baseConnection);
            await connection.OpenAsync();
            await using var command = new NpgsqlCommand($"CREATE SCHEMA \"{schema}\"", connection);
            await command.ExecuteNonQueryAsync();
            return new(new NpgsqlConnectionStringBuilder(baseConnection) { SearchPath = schema, Pooling = false }.ConnectionString, schema);
        }
        internal TemplatesDbContext Context() => new(new DbContextOptionsBuilder<TemplatesDbContext>().UseNpgsql(connectionString).Options);
        public async ValueTask DisposeAsync()
        {
            await using var connection = new NpgsqlConnection(connectionString);
            await connection.OpenAsync();
            // Only the unique schema created by this test is removed; shared databases are never reset.
            await using var command = new NpgsqlCommand($"DROP SCHEMA \"{schema}\" CASCADE", connection);
            await command.ExecuteNonQueryAsync();
        }
    }
}
