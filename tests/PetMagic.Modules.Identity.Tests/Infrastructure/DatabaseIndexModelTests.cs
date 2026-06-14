using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;

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
        AssertHasUniqueIndex<TemplateGenerationJob>(dbContext, ["UserId", "IdempotencyKey"]);
        AssertHasUniqueIndex<TemplateGenerationJob>(dbContext, ["UserId", "RequestHash"]);
        AssertHasUniqueIndex<TemplateGenerationWatermarkUnlock>(dbContext, ["UserId", "GenerationJobId"]);
        AssertHasUniqueIndex<TemplateAiProviderRequestPermit>(dbContext, ["Provider", "BucketUtc", "PermitNumber"]);
        AssertHasUniqueIndex<TemplateCatalogChange>(dbContext, ["Version"]);
        AssertHasIndex<TemplateItem>(dbContext, ["Status", "UpdatedAtUtc", "Id"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["TemplateId", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["GenerationId", "UserId"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["TemplateId", "Rating", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["Status", "Priority", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["Type", "Category", "CreatedAtUtc"]);
        AssertHasIndex<TemplateGenerationFeedback>(dbContext, ["UserId", "CreatedAtUtc"]);
        AssertHasUniqueIndex<CreditRefund>(dbContext, ["FeedbackId"]);
        AssertHasUniqueIndex<CreditRefund>(dbContext, ["GenerationId"]);
        AssertHasIndex<CreditRefund>(dbContext, ["UserId", "CreatedAtUtc"]);
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

    private static void AssertHasIndex<TEntity>(DbContext dbContext, IReadOnlyList<string> propertyNames)
    {
        var entityType = dbContext.Model.FindEntityType(typeof(TEntity));
        Assert.NotNull(entityType);

        var indexes = entityType!.GetIndexes()
            .Select(index => index.Properties.Select(property => property.Name).ToArray())
            .ToArray();

        Assert.Contains(indexes, index => index.SequenceEqual(propertyNames));
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
