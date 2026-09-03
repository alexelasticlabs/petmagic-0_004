using System.Text.RegularExpressions;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.EntityFrameworkCore.Migrations;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class DatabaseIndexModelTests
{
    private const int PostgresIdentifierMaxLength = 63;

    [Fact]
    public void IdentityDbContext_ShouldExposeHotPathIndexes()
    {
        using var dbContext = new IdentityDbContext(
            new DbContextOptionsBuilder<IdentityDbContext>()
                .UseInMemoryDatabase($"identity-indexes-{Guid.NewGuid():N}")
                .Options);

        AssertHasIndex<AppUser>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<AppUser>(dbContext, ["AccountStatus", "AccountStatusUpdatedAtUtc", "CreatedAtUtc"]);
        AssertHasIndex<AuditEvent>(dbContext, ["SubjectUserId", "OccurredAtUtc"]);
        AssertHasIndex<EmailDispatchJob>(dbContext, ["Status", "NextAttemptAtUtc", "QueuedAtUtc"]);
        AssertHasIndex<EmailDispatchJob>(dbContext, ["Status", "UpdatedAtUtc"]);
        AssertHasIndex<EmailDispatchJob>(dbContext, ["BroadcastId", "Status"]);
        AssertHasIndex<AdminEmailBroadcast>(dbContext, ["CreatedAtUtc", "Id"]);
        AssertHasIndex<AdminEmailBroadcast>(dbContext, ["Status", "CreatedAtUtc"]);
    }

    [Fact]
    public void RefreshSessionAuthenticationProviderIndex_ShouldUsePostgresSafeNameAndRenameMigration()
    {
        using var dbContext = new IdentityDbContext(
            new DbContextOptionsBuilder<IdentityDbContext>()
                .UseNpgsql("Host=localhost;Database=petmagic_migration_discovery;Username=postgres;Password=unused")
                .Options);

        var index = Assert.Single(
            dbContext.Model.FindEntityType(typeof(RefreshTokenSession))!.GetIndexes(),
            candidate => candidate.Properties.Select(property => property.Name).SequenceEqual(
                ["UserId", "AuthenticationProvider", "CreatedAtUtc"]));
        Assert.Equal(
            "IX_refresh_token_sessions_UserId_AuthProvider_CreatedAtUtc",
            index.GetDatabaseName());
        Assert.True(index.GetDatabaseName()!.Length <= PostgresIdentifierMaxLength);

        var migrationId = "20260829211500_RenameRefreshSessionAuthenticationProviderIndex";
        Assert.Contains(migrationId, dbContext.GetService<IMigrationsAssembly>().Migrations.Keys);

        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "Data",
            "Migrations",
            $"{migrationId}.cs"));
        Assert.Contains(
            "IX_refresh_token_sessions_UserId_AuthenticationProvider_Created",
            migration,
            StringComparison.Ordinal);
        Assert.Contains(
            "IX_refresh_token_sessions_UserId_AuthProvider_CreatedAtUtc",
            migration,
            StringComparison.Ordinal);
        Assert.Contains("to_regclass", migration, StringComparison.Ordinal);
        Assert.Contains("ALTER INDEX public.", migration, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminEmailBroadcastMigration_ShouldBeDiscoverableAndBackfillExistingAuditRequests()
    {
        using var dbContext = new IdentityDbContext(
            new DbContextOptionsBuilder<IdentityDbContext>()
                .UseNpgsql("Host=localhost;Database=petmagic_migration_discovery;Username=postgres;Password=unused")
                .Options);

        var migrations = dbContext.GetService<IMigrationsAssembly>().Migrations;
        Assert.Contains("20260727130000_AddAdminEmailBroadcasts", migrations.Keys);

        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "Data",
            "Migrations",
            "20260727130000_AddAdminEmailBroadcasts.cs"));

        Assert.Contains("FROM audit_events", migration, StringComparison.Ordinal);
        Assert.Contains("WHERE \"Action\" = 'admin.bulk_email.queued'", migration, StringComparison.Ordinal);
        Assert.Contains("IX_email_dispatch_jobs_BroadcastId_Status", migration, StringComparison.Ordinal);
        Assert.Contains("FK_email_dispatch_jobs_admin_email_broadcasts_BroadcastId", migration, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyDbContext_ShouldExposeHotPathIndexes()
    {
        using var dbContext = new EconomyDbContext(
            new DbContextOptionsBuilder<EconomyDbContext>()
                .UseInMemoryDatabase($"economy-indexes-{Guid.NewGuid():N}")
                .Options);

        AssertHasIndex<WalletLedgerEntry>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<WalletLedgerEntry>(dbContext, ["Source", "CreatedAtUtc"]);
        AssertHasUniqueIndex<WalletLedgerEntry>(dbContext, ["UserId", "Source", "Reason"]);
        AssertHasUniqueIndex<WalletLedgerEntry>(dbContext, ["UserId", "Reason"]);
        AssertHasIndex<PurchaseOrder>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<PurchaseOrder>(dbContext, ["Status", "CreatedAtUtc"]);
        AssertHasIndex<PurchaseOrder>(dbContext, ["UserId", "PaymentProvider", "CreatedAtUtc"]);
        AssertHasIndex<RedeemCode>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<RedeemCodeRedemption>(dbContext, ["RedeemCodeId", "RedeemedAtUtc"]);
        AssertHasIndex<SavedPaymentMethod>(dbContext, ["UserId", "Provider", "IsActive", "IsDefault", "UpdatedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["UpdatedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["Status", "UpdatedAtUtc"]);
        AssertHasIndex<UserSubscription>(dbContext, ["Provider", "UpdatedAtUtc"]);
        AssertHasIndex<SubscriptionEventLog>(dbContext, ["CreatedAtUtc"]);
        AssertHasIndex<SubscriptionEventLog>(dbContext, ["Provider", "Status", "CreatedAtUtc"]);
        AssertHasIndex<SubscriptionEventLog>(dbContext, ["UserId", "Provider", "CreatedAtUtc"]);
    }

    [Fact]
    public void TemplatesDbContext_ShouldExposeGenerationQueueHotPathIndexes()
    {
        using var dbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseInMemoryDatabase($"templates-indexes-{Guid.NewGuid():N}")
                .Options);

        AssertHasIndex<TemplateGenerationJob>(dbContext, ["Status", "QueuedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["Status", "LockedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["UserId", "Status"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["UserId", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["UserId", "HiddenByUserAtUtc", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["UserId", "Status", "ResultViewedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["Status", "RefundedAtUtc", "RefundLastAttemptedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["Status", "QueueMediaType", "QueueTier", "QueuedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["Status", "QueueMediaType", "StartedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["ChargedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["RefundedAtUtc"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["CreatedAtUtc", "Id"]);
        AssertHasIndex<TemplateGenerationJob>(dbContext, ["UpdatedAtUtc", "Id"]);
        AssertHasUniqueIndex<TemplateGenerationJob>(dbContext, ["UserId", "IdempotencyKey"]);
        AssertHasUniqueIndex<TemplateGenerationJob>(dbContext, ["UserId", "RequestHash"]);
        AssertHasUniqueIndex<TemplateGenerationWatermarkUnlock>(dbContext, ["UserId", "GenerationJobId"]);
        AssertHasUniqueIndex<TemplateAiProviderRequestPermit>(dbContext, ["Provider", "BucketUtc", "PermitNumber"]);
        AssertHasUniqueIndex<TemplateCatalogChange>(dbContext, ["Version"]);
        var generationResultIdentity = Assert.Single(
            dbContext.Model.FindEntityType(typeof(TemplateMediaRecord))!.GetIndexes(),
            index => index.GetDatabaseName() == "UX_tmr_GenerationResult_GenerationId_MediaType");
        Assert.True(generationResultIdentity.IsUnique);
        Assert.Equal(
            [nameof(TemplateMediaRecord.GenerationId), nameof(TemplateMediaRecord.MediaType)],
            generationResultIdentity.Properties.Select(property => property.Name));
        Assert.Equal(
            "\"GenerationId\" IS NOT NULL AND \"SourceType\" = 'generation_result'",
            generationResultIdentity.GetFilter());
        AssertHasIndex<TemplateItem>(dbContext, ["Status", "UpdatedAtUtc", "Id"]);
        AssertHasIndex<TemplateItem>(dbContext, ["Status", "PublishedAtUtc", "Id"]);
        AssertHasIndex<TemplateItem>(dbContext, ["Status", "IsQaOnly", "TemplateType", "IsPremium", "PublishedAtUtc", "Id"]);
        AssertHasIndex<TemplateItem>(dbContext, ["Status", "IsQaOnly", "Category", "PublishedAtUtc", "Id"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["TemplateId", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["GenerationId", "UserId"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["TemplateId", "Rating", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["Status", "Priority", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["Type", "Category", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["UserId", "CreatedAtUtc"]);
        AssertHasUniqueIndex<CreditRefund>(dbContext, ["FeedbackId"]);
        AssertHasUniqueIndex<CreditRefund>(dbContext, ["GenerationId"]);
        AssertHasIndex<CreditRefund>(dbContext, ["UserId", "CreatedAtUtc"]);
        AssertHasIndex<TemplateRealtimeEventRecord>(dbContext, ["CreatedAtUtc", "Id"]);
    }

    [Fact]
    public void GenerationSchedulerQueueFieldsMigration_ShouldUseConcurrentIndexesOutsideTransaction()
    {
        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations",
            "20260630234809_AddGenerationSchedulerQueueFields.cs"));

        Assert.Contains("CREATE INDEX CONCURRENTLY IF NOT EXISTS", migration);
        Assert.Contains("DROP INDEX CONCURRENTLY IF EXISTS", migration);
        Assert.Contains("suppressTransaction: true", migration);
        Assert.DoesNotContain("migrationBuilder.CreateIndex(", migration);
    }

    [Fact]
    public void GenerationBillingReconciliationIndexesMigration_ShouldUseConcurrentIndexesOutsideTransaction()
    {
        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations",
            "20260702234729_AddGenerationBillingReconciliationIndexes.cs"));

        Assert.Contains("CREATE INDEX CONCURRENTLY IF NOT EXISTS", migration);
        Assert.Contains("DROP INDEX CONCURRENTLY IF EXISTS", migration);
        Assert.Contains("suppressTransaction: true", migration);
        Assert.DoesNotContain("migrationBuilder.CreateIndex(", migration);
    }

    [Fact]
    public void GenerationResultMediaIdentityMigration_ShouldBeDiscoverableAndPreflightExistingRows()
    {
        using var dbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseNpgsql("Host=localhost;Database=petmagic_migration_discovery;Username=postgres;Password=unused")
                .Options);
        var migrations = dbContext.GetService<IMigrationsAssembly>().Migrations;
        Assert.Contains("20260729184500_EnforceGenerationResultMediaIdentity", migrations.Keys);
        Assert.Contains("20260729213000_RepairGenerationSchedulerV2ExistingDeployments", migrations.Keys);

        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations",
            "20260729184500_EnforceGenerationResultMediaIdentity.cs"));

        Assert.Contains("SET \"GenerationId\" = \"GenerationJobId\"", migration, StringComparison.Ordinal);
        Assert.Contains("GROUP BY \"GenerationId\", \"MediaType\"", migration, StringComparison.Ordinal);
        Assert.Contains("Generation-result media identity migration found duplicate rows.", migration, StringComparison.Ordinal);
        Assert.Contains("preserve original, watermarked and preview paths", migration, StringComparison.Ordinal);
        Assert.Contains("UX_tmr_GenerationResult_GenerationId_MediaType", migration, StringComparison.Ordinal);
        Assert.Contains("\"GenerationId\" IS NOT NULL AND \"SourceType\" = 'generation_result'", migration, StringComparison.Ordinal);
        Assert.Contains("CREATE UNIQUE INDEX CONCURRENTLY", migration, StringComparison.Ordinal);
        Assert.Contains("DROP INDEX CONCURRENTLY IF EXISTS", migration, StringComparison.Ordinal);
        Assert.Equal(3, Regex.Matches(migration, "suppressTransaction: true", RegexOptions.CultureInvariant).Count);
        Assert.DoesNotContain("migrationBuilder.CreateIndex(", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("migrationBuilder.DropIndex(", migration, StringComparison.Ordinal);
        Assert.DoesNotContain("DELETE FROM templates_media_records", migration, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("DropColumn", migration, StringComparison.Ordinal);
    }

    [Fact]
    public void SupportMessageIdempotencyIndexRenameMigration_ShouldRepairThePostgresTruncatedLegacyName()
    {
        var migration = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            "Data",
            "Migrations",
            "20260725124500_RenameSupportMessageIdempotencyIndex.cs"));

        Assert.Contains("UX_support_messages_ConversationId_SenderUserId_ClientIdempoten", migration);
        Assert.Contains("IX_support_messages_ConversationId_SenderUserId_ClientIdempoten", migration);
        Assert.Contains("UX_support_messages_conversation_sender_idempotency", migration);
        Assert.Contains("to_regclass", migration);
        Assert.Contains("ALTER INDEX public.", migration);
    }

    [Fact]
    public void SupportMessageIdempotencyMigrations_ShouldBeDiscoveredByEfCore()
    {
        using var dbContext = new SupportChatDbContext(
            new DbContextOptionsBuilder<SupportChatDbContext>()
                .UseNpgsql("Host=localhost;Database=petmagic_migration_discovery;Username=postgres;Password=unused")
                .Options);

        var migrations = dbContext.GetService<IMigrationsAssembly>().Migrations;

        Assert.Contains("20260725123000_AddSupportMessageIdempotency", migrations.Keys);
        Assert.Contains("20260725124500_RenameSupportMessageIdempotencyIndex", migrations.Keys);
    }

    [Fact]
    public void HistoricalConcurrentIndexMigrations_ShouldRepairOnlyInvalidIndexesFromPendingOwnerMigration()
    {
        var migrationsRoot = Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "Data",
            "Migrations");
        foreach (var fileName in new[]
        {
            "20260630234809_AddGenerationSchedulerQueueFields.cs",
            "20260701093000_AddAsyncGenerationProviderPipeline.cs",
            "20260702234729_AddGenerationBillingReconciliationIndexes.cs",
            "20260710093545_AddGamificationSyncDeliveryState.cs",
            "20260710094027_AddGamificationShareDeliveryState.cs"
        })
        {
            var migration = File.ReadAllText(Path.Combine(migrationsRoot, fileName));
            Assert.Contains("CREATE INDEX CONCURRENTLY IF NOT EXISTS", migration, StringComparison.Ordinal);
            Assert.Contains("suppressTransaction: true", migration, StringComparison.Ordinal);
        }

        var schedulerHotPathMigration = File.ReadAllText(Path.Combine(
            migrationsRoot,
            "20260729153000_AddGenerationSchedulerHotPathIndexes.cs"));
        Assert.Contains("DROP INDEX CONCURRENTLY IF EXISTS", schedulerHotPathMigration, StringComparison.Ordinal);
        Assert.Contains("CREATE INDEX CONCURRENTLY", schedulerHotPathMigration, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "CREATE INDEX CONCURRENTLY IF NOT EXISTS",
            schedulerHotPathMigration,
            StringComparison.Ordinal);

        var validator = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Startup",
            "PostgreSqlIndexIntegrityValidator.cs"));
        var program = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Program.cs"));

        Assert.Contains("RepairPendingMigrationIndexesAsync", program, StringComparison.Ordinal);
        Assert.True(
            program.IndexOf("RepairPendingMigrationIndexesAsync", StringComparison.Ordinal)
                < program.IndexOf("EnsureTemplatesSeedDataAsync", StringComparison.Ordinal));
        Assert.Contains("appliedMigrations.Contains(ownerMigration)", validator, StringComparison.Ordinal);
        Assert.Contains("DROP INDEX CONCURRENTLY IF EXISTS", validator, StringComparison.Ordinal);
        Assert.Contains("20260630234809_AddGenerationSchedulerQueueFields", validator, StringComparison.Ordinal);
        Assert.Contains("20260701093000_AddAsyncGenerationProviderPipeline", validator, StringComparison.Ordinal);
        Assert.Contains("20260702234729_AddGenerationBillingReconciliationIndexes", validator, StringComparison.Ordinal);
        Assert.Contains("20260710093545_AddGamificationSyncDeliveryState", validator, StringComparison.Ordinal);
        Assert.Contains("20260710094027_AddGamificationShareDeliveryState", validator, StringComparison.Ordinal);
        Assert.Contains("20260729213000_RepairGenerationSchedulerV2ExistingDeployments", validator, StringComparison.Ordinal);
        Assert.Contains("IX_tgj_ImportingMedia_NextAttempt", validator, StringComparison.Ordinal);
    }

    [Fact]
    public void ConcurrentIndexMigrations_ShouldSuppressEfTransactions()
    {
        var migrationsRoot = Path.Combine(FindRepositoryRoot(), "src", "Modules");
        var unsafeMigrations = Directory
            .EnumerateFiles(migrationsRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => path.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .Select(path => new
            {
                Path = path,
                Source = File.ReadAllText(path)
            })
            .Where(migration => migration.Source.Contains("CONCURRENTLY", StringComparison.Ordinal))
            .SelectMany(migration => Regex
                .Matches(migration.Source, "migrationBuilder\\.Sql\\(\\s*\"\"\"(?<sql>.*?)\"\"\"(?<args>.*?)\\);", RegexOptions.Singleline)
                .Select(match => new
                {
                    migration.Path,
                    Sql = match.Groups["sql"].Value,
                    Args = match.Groups["args"].Value
                }))
            .Where(sqlCall =>
                sqlCall.Sql.Contains("CONCURRENTLY", StringComparison.Ordinal)
                && !sqlCall.Args.Contains("suppressTransaction: true", StringComparison.Ordinal))
            .Select(sqlCall =>
                $"{Path.GetRelativePath(FindRepositoryRoot(), sqlCall.Path)} contains a CONCURRENTLY SQL call without suppressTransaction: true")
            .ToArray();

        Assert.Empty(unsafeMigrations);
    }

    [Fact]
    public void ConcurrentIndexMigrations_ShouldKeepConcurrentSqlInRawMigrationCalls()
    {
        var migrationsRoot = Path.Combine(FindRepositoryRoot(), "src", "Modules");
        var unsafeMigrations = Directory
            .EnumerateFiles(migrationsRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => path.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .Select(path => new
            {
                Path = path,
                Source = File.ReadAllText(path)
            })
            .Where(migration => migration.Source.Contains("CONCURRENTLY", StringComparison.Ordinal))
            .Where(migration => !Regex
                .Matches(migration.Source, "migrationBuilder\\.Sql\\(\\s*\"\"\"(?<sql>.*?)\"\"\"(?<args>.*?)\\);", RegexOptions.Singleline)
                .Any(match => match.Groups["sql"].Value.Contains("CONCURRENTLY", StringComparison.Ordinal)))
            .Select(migration =>
                $"{Path.GetRelativePath(FindRepositoryRoot(), migration.Path)} mentions CONCURRENTLY but no raw migrationBuilder.Sql call contains it")
            .ToArray();

        Assert.Empty(unsafeMigrations);
    }

    [Fact]
    public void DbContexts_ShouldNotDeclareIndexNamesLongerThanPostgresLimit()
    {
        using var identityDbContext = new IdentityDbContext(
            new DbContextOptionsBuilder<IdentityDbContext>()
                .UseInMemoryDatabase($"identity-index-names-{Guid.NewGuid():N}")
                .Options);
        using var economyDbContext = new EconomyDbContext(
            new DbContextOptionsBuilder<EconomyDbContext>()
                .UseInMemoryDatabase($"economy-index-names-{Guid.NewGuid():N}")
                .Options);
        using var supportChatDbContext = new SupportChatDbContext(
            new DbContextOptionsBuilder<SupportChatDbContext>()
                .UseInMemoryDatabase($"support-chat-index-names-{Guid.NewGuid():N}")
                .Options);
        using var templatesDbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseInMemoryDatabase($"templates-index-names-{Guid.NewGuid():N}")
                .Options);

        AssertIndexNamesFitPostgresLimit(
            identityDbContext,
            economyDbContext,
            supportChatDbContext,
            templatesDbContext);
    }

    [Fact]
    public void PushOutboxContexts_ShouldUseLockIdAsConcurrencyToken()
    {
        using var economyDbContext = new EconomyDbContext(
            new DbContextOptionsBuilder<EconomyDbContext>()
                .UseInMemoryDatabase($"economy-outbox-lock-{Guid.NewGuid():N}")
                .Options);
        using var supportChatDbContext = new SupportChatDbContext(
            new DbContextOptionsBuilder<SupportChatDbContext>()
                .UseInMemoryDatabase($"support-outbox-lock-{Guid.NewGuid():N}")
                .Options);
        using var templatesDbContext = new TemplatesDbContext(
            new DbContextOptionsBuilder<TemplatesDbContext>()
                .UseInMemoryDatabase($"templates-outbox-lock-{Guid.NewGuid():N}")
                .Options);

        foreach (var dbContext in new DbContext[] { economyDbContext, supportChatDbContext, templatesDbContext })
        {
            var lockId = dbContext.Model.FindEntityType(typeof(PushOutboxMessage))?.FindProperty(nameof(PushOutboxMessage.LockId));
            Assert.NotNull(lockId);
            Assert.True(lockId!.IsConcurrencyToken);
        }
    }

    private static void AssertHasIndex<TEntity>(DbContext dbContext, IReadOnlyList<string> propertyNames)
    {
        var entityType = dbContext.Model.FindEntityType(typeof(TEntity));
        Assert.NotNull(entityType);

        var indexes = entityType!.GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToArray();

        Assert.Contains(indexes, index => index.SequenceEqual(propertyNames));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }

    private static void AssertIndexNamesFitPostgresLimit(params DbContext[] dbContexts)
    {
        var longNames = dbContexts
            .SelectMany(dbContext => dbContext.Model.GetEntityTypes()
                .SelectMany(entityType => entityType.GetIndexes()
                    .Select(index => index.GetDatabaseName())
                    .Where(indexName => !string.IsNullOrWhiteSpace(indexName))
                    .Cast<string>()
                    .Select(indexName => $"{dbContext.GetType().Name}:{entityType.DisplayName()}:{indexName}")))
            .Where(item => item.Split(':').Last().Length > PostgresIdentifierMaxLength)
            .ToArray();

        Assert.Empty(longNames);
    }

    private static void AssertHasUniqueIndex<TEntity>(DbContext dbContext, IReadOnlyList<string> propertyNames)
    {
        var entityType = dbContext.Model.FindEntityType(typeof(TEntity));
        Assert.NotNull(entityType);

        var indexes = entityType!.GetIndexes()
            .Where(index => index.IsUnique)
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToArray();

        Assert.Contains(indexes, index => index.SequenceEqual(propertyNames));
    }
}
