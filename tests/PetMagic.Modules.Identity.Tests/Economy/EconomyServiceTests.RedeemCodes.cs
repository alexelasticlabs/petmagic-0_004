using System.Text.Json;

using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldCreditWalletOncePerUser()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("WELCOME-100", "Launch bonus", RedeemCodeRewardKind.Spark, 100, 10, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var firstApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "welcome-100"),
            CancellationToken.None);

        Assert.True(firstApply.IsSuccess);
        Assert.NotNull(firstApply.Value.WalletOperation);
        Assert.Equal(100, firstApply.Value.WalletOperation!.NewBalance);

        var duplicateApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "WELCOME-100"),
            CancellationToken.None);

        Assert.True(duplicateApply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeAlreadyUsed.Code, duplicateApply.Error.Code);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        var ledger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        var redemption = await dbContext.RedeemCodeRedemptions.SingleAsync(x => x.UserId == userId);

        Assert.Equal(100, wallet.Balance);
        Assert.Equal("redeem_code", ledger.Source);
        Assert.Equal(ledger.Id, redemption.WalletLedgerEntryId);
    }

    [Fact]
    public async Task RedeemCodeMutations_ShouldWriteRedactedAuditTrail()
    {
        await using var dbContext = CreateDbContext();
        const string plainTextCode = "Q7X9";
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);

        var create = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                plainTextCode,
                $"Campaign for {plainTextCode}",
                RedeemCodeRewardKind.Spark,
                25,
                100,
                1,
                true,
                null,
                DateTime.UtcNow.AddDays(7),
                CampaignName: plainTextCode,
                CampaignChannel: plainTextCode,
                MinimumSuccessfulPurchases: 1,
                CreatedBy: plainTextCode),
            CancellationToken.None);

        Assert.True(create.IsSuccess);
        var persisted = await dbContext.RedeemCodes
            .AsNoTracking()
            .SingleAsync(x => x.Id == create.Value.RedeemCodeId);

        var update = await service.UpdateRedeemCodeAsync(
            new UpdateRedeemCodeCommand(
                create.Value.RedeemCodeId,
                $"Updated campaign for {plainTextCode}",
                RedeemCodeRewardKind.Spark,
                30,
                120,
                2,
                false,
                DateTime.UtcNow.AddHours(1),
                DateTime.UtcNow.AddDays(14),
                CampaignName: plainTextCode,
                CampaignChannel: plainTextCode,
                MinimumSuccessfulPurchases: 2,
                CreatedBy: plainTextCode),
            CancellationToken.None);

        Assert.True(update.IsSuccess);
        Assert.Collection(
            auditLog.Entries,
            entry =>
            {
                Assert.Equal("admin.economy.redeem_code.created", entry.Action);
                Assert.Equal("redeem_code", entry.TargetType);
                Assert.Equal(create.Value.RedeemCodeId.ToString("D"), entry.TargetId);
                Assert.Null(entry.OldValue);
                Assert.NotNull(entry.NewValue);
            },
            entry =>
            {
                Assert.Equal("admin.economy.redeem_code.updated", entry.Action);
                Assert.Equal("redeem_code", entry.TargetType);
                Assert.Equal(create.Value.RedeemCodeId.ToString("D"), entry.TargetId);
                Assert.NotEqual(entry.OldValue, entry.NewValue);
            });

        var auditPayload = string.Join(
            '\n',
            auditLog.Entries.SelectMany(entry => new[]
            {
                entry.OldValue,
                entry.NewValue,
                entry.Details,
            }));
        Assert.DoesNotContain(plainTextCode, auditPayload, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(persisted.CodeHash, auditPayload, StringComparison.OrdinalIgnoreCase);

        using var createSnapshot = JsonDocument.Parse(auditLog.Entries[0].NewValue!);
        Assert.False(createSnapshot.RootElement.TryGetProperty("CodePrefix", out _));
        Assert.True(createSnapshot.RootElement.GetProperty("DescriptionConfigured").GetBoolean());
        Assert.True(createSnapshot.RootElement.GetProperty("CampaignNameConfigured").GetBoolean());
        Assert.True(createSnapshot.RootElement.GetProperty("CampaignChannelConfigured").GetBoolean());
        Assert.True(createSnapshot.RootElement.GetProperty("CreatedByConfigured").GetBoolean());

        var outboxMessages = await dbContext.PushOutboxMessages
            .AsNoTracking()
            .OrderBy(message => message.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, outboxMessages.Count);
        Assert.All(outboxMessages, message =>
        {
            Assert.Equal(EconomyAdminAuditOutbox.Kind, message.Kind);
            Assert.Equal(PushOutboxStatus.Sent, message.Status);
            Assert.DoesNotContain(plainTextCode, message.PayloadJson, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain(persisted.CodeHash, message.PayloadJson, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("codePrefix", message.PayloadJson, StringComparison.OrdinalIgnoreCase);
        });
        Assert.All(auditLog.Entries, entry =>
        {
            Assert.NotNull(entry.EventId);
            Assert.NotEqual(Guid.Empty, entry.EventId!.Value);
            Assert.NotNull(entry.OccurredAtUtc);
        });
    }

    [Fact]
    public async Task CreateRedeemCodeAsync_ShouldSucceedAndKeepAuditQueued_WhenImmediateAuditDeliveryFails()
    {
        await using var dbContext = CreateDbContext();
        const string plainTextCode = "ZXCV-ATOMIC-2026";
        var service = CreateService(dbContext, adminAuditLog: new ThrowingAdminAuditLog());

        var result = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                plainTextCode,
                "Atomic audit campaign",
                RedeemCodeRewardKind.Spark,
                50,
                100,
                1,
                true,
                null,
                DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var persistedCode = await dbContext.RedeemCodes
            .AsNoTracking()
            .SingleAsync(code => code.Id == result.Value.RedeemCodeId);
        var queuedAudit = await dbContext.PushOutboxMessages
            .AsNoTracking()
            .SingleAsync();

        Assert.Equal(EconomyAdminAuditOutbox.Kind, queuedAudit.Kind);
        Assert.Equal(PushOutboxStatus.Queued, queuedAudit.Status);
        Assert.Equal(0, queuedAudit.AttemptCount);
        Assert.Null(queuedAudit.SentAtUtc);
        Assert.DoesNotContain(plainTextCode, queuedAudit.PayloadJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(persistedCode.CodeHash, queuedAudit.PayloadJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(persistedCode.CodePrefix, queuedAudit.PayloadJson, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("codePrefix", queuedAudit.PayloadJson, StringComparison.OrdinalIgnoreCase);

        var capturedEntry = JsonSerializer.Deserialize<AdminAuditEntry>(
            queuedAudit.PayloadJson,
            new JsonSerializerOptions(JsonSerializerDefaults.Web));
        Assert.NotNull(capturedEntry);
        Assert.NotNull(capturedEntry.EventId);
        Assert.NotEqual(Guid.Empty, capturedEntry.EventId!.Value);
        Assert.NotNull(capturedEntry.OccurredAtUtc);
    }

    [Fact]
    public async Task CreateRedeemCodeAsync_ShouldRollbackMutation_WhenDurableAuditCannotBeQueued()
    {
        await using var connection = new SqliteConnection("Data Source=:memory:");
        await connection.OpenAsync();
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseSqlite(connection)
            .Options;
        await using var dbContext = new EconomyDbContext(options);
        await dbContext.Database.EnsureCreatedAsync();
        await dbContext.Database.ExecuteSqlRawAsync(
            """
            CREATE TRIGGER reject_economy_admin_audit_outbox
            BEFORE INSERT ON economy_push_outbox
            BEGIN
                SELECT RAISE(ABORT, 'audit outbox unavailable');
            END;
            """);
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);

        await Assert.ThrowsAsync<DbUpdateException>(() => service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                "ATOMIC-ROLLBACK",
                "Atomic rollback campaign",
                RedeemCodeRewardKind.Spark,
                50,
                100,
                1,
                true,
                null,
                DateTime.UtcNow.AddDays(7)),
            CancellationToken.None));

        dbContext.ChangeTracker.Clear();
        Assert.Empty(await dbContext.RedeemCodes.ToListAsync());
        Assert.Empty(await dbContext.PushOutboxMessages.ToListAsync());
        Assert.Empty(auditLog.Entries);
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRejectExhaustedCode()
    {
        await using var dbContext = CreateDbContext();

        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("SINGLE", "Single use", RedeemCodeRewardKind.Spark, 25, 1, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var firstApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(firstUserId, "SINGLE"),
            CancellationToken.None);
        var secondApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(secondUserId, "SINGLE"),
            CancellationToken.None);

        Assert.True(firstApply.IsSuccess);
        Assert.True(secondApply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeExhausted.Code, secondApply.Error.Code);
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRejectInactiveCode()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("ARCHIVED", "Archived promo", RedeemCodeRewardKind.Spark, 40, 10, 1, false, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var apply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "ARCHIVED"),
            CancellationToken.None);

        Assert.True(apply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeInactive.Code, apply.Error.Code);
        Assert.False(await dbContext.Wallets.AnyAsync(x => x.UserId == userId));
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRejectScheduledCode()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("FUTURE", "Future promo", RedeemCodeRewardKind.Spark, 40, 10, 1, true, DateTime.UtcNow.AddDays(1), DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var apply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "FUTURE"),
            CancellationToken.None);

        Assert.True(apply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeInactive.Code, apply.Error.Code);
        Assert.False(await dbContext.Wallets.AnyAsync(x => x.UserId == userId));
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRejectExpiredCode()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("EXPIRED", "Expired promo", RedeemCodeRewardKind.Spark, 40, 10, 1, true, DateTime.UtcNow.AddDays(-10), DateTime.UtcNow.AddDays(-1)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var apply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "EXPIRED"),
            CancellationToken.None);

        Assert.True(apply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeExpired.Code, apply.Error.Code);
        Assert.False(await dbContext.Wallets.AnyAsync(x => x.UserId == userId));
    }

    [Fact]
    public async Task UpdateRedeemCodeAsync_ShouldRejectLimitBelowRedeemedCountAndAllowArchive()
    {
        await using var dbContext = CreateDbContext();

        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("LIMITED", "Limited promo", RedeemCodeRewardKind.Spark, 30, 2, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var apply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(firstUserId, "LIMITED"),
            CancellationToken.None);

        Assert.True(apply.IsSuccess);

        var invalidUpdate = await service.UpdateRedeemCodeAsync(
            new UpdateRedeemCodeCommand(codeResult.Value.RedeemCodeId, "Limited promo", RedeemCodeRewardKind.Spark, 30, 0, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(invalidUpdate.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeExhausted.Code, invalidUpdate.Error.Code);

        var archive = await service.UpdateRedeemCodeAsync(
            new UpdateRedeemCodeCommand(codeResult.Value.RedeemCodeId, "Archived promo", RedeemCodeRewardKind.Spark, 30, 2, 1, false, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(archive.IsSuccess);
        Assert.False(archive.Value.IsActive);
        Assert.Equal("Archived promo", archive.Value.Description);

        var secondApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(secondUserId, "LIMITED"),
            CancellationToken.None);

        Assert.True(secondApply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeInactive.Code, secondApply.Error.Code);
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRespectPerUserLimit()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("DOUBLE", "Two per user", RedeemCodeRewardKind.Spark, 15, 20, 2, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var firstApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(userId, "DOUBLE"), CancellationToken.None);
        var secondApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(userId, "DOUBLE"), CancellationToken.None);
        var thirdApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(userId, "DOUBLE"), CancellationToken.None);

        Assert.True(firstApply.IsSuccess);
        Assert.True(secondApply.IsSuccess);
        Assert.True(thirdApply.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeUserLimitReached.Code, thirdApply.Error.Code);
    }

    [Fact]
    public async Task ApplyRedeemCodeAsync_ShouldRequireMinimumSuccessfulPurchases()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                "LOYAL-50",
                "Loyal users promo",
                RedeemCodeRewardKind.Spark,
                50,
                10,
                1,
                true,
                null,
                DateTime.UtcNow.AddDays(7),
                MinimumSuccessfulPurchases: 1),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var firstAttempt = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "LOYAL-50"),
            CancellationToken.None);

        Assert.True(firstAttempt.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodePurchaseRequirementNotMet.Code, firstAttempt.Error.Code);

        var packId = AddStarterPack(dbContext);
        var verifiedPurchase = await CreateAndVerifyStorePurchaseAsync(
            dbContext,
            service,
            userId,
            packId);

        Assert.Equal(PurchaseOrderStatus.Succeeded, verifiedPurchase.Status);

        var secondAttempt = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(userId, "LOYAL-50"),
            CancellationToken.None);

        Assert.True(secondAttempt.IsSuccess);
    }

    [Fact]
    public async Task GetAdminRedeemCodeActivationsAsync_ShouldSupportPaginationAndUserFilter()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        var thirdUserId = Guid.NewGuid();

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("FEED", "Feed campaign", RedeemCodeRewardKind.Spark, 20, 10, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var firstApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(firstUserId, "FEED"), CancellationToken.None);
        var secondApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(secondUserId, "FEED"), CancellationToken.None);
        var thirdApply = await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(thirdUserId, "FEED"), CancellationToken.None);

        Assert.True(firstApply.IsSuccess);
        Assert.True(secondApply.IsSuccess);
        Assert.True(thirdApply.IsSuccess);

        var firstPage = await service.GetAdminRedeemCodeActivationsAsync(codeResult.Value.RedeemCodeId, 0, 2, null, CancellationToken.None);
        var secondPage = await service.GetAdminRedeemCodeActivationsAsync(codeResult.Value.RedeemCodeId, 2, 2, null, CancellationToken.None);
        var filtered = await service.GetAdminRedeemCodeActivationsAsync(codeResult.Value.RedeemCodeId, 0, 10, secondUserId, CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        Assert.Equal(2, firstPage.Value.Items.Count);
        Assert.True(firstPage.Value.HasMore);

        Assert.True(secondPage.IsSuccess);
        Assert.Single(secondPage.Value.Items);
        Assert.False(secondPage.Value.HasMore);

        Assert.True(filtered.IsSuccess);
        var filteredItem = Assert.Single(filtered.Value.Items);
        Assert.Equal(secondUserId, filteredItem.UserId);
        Assert.False(filtered.Value.HasMore);
    }

    [Fact]
    public async Task ListAdminRedeemCodesAsync_ShouldReturnAggregatesWithBoundedRedemptionPreview()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        var thirdUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        var codeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("FEED-BIG", "Feed campaign", RedeemCodeRewardKind.Spark, 20, 20, 3, true, null, now.AddDays(7)),
            CancellationToken.None);

        Assert.True(codeResult.IsSuccess);

        var applies = new[]
        {
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(firstUserId, "FEED-BIG"), CancellationToken.None),
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(firstUserId, "FEED-BIG"), CancellationToken.None),
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(firstUserId, "FEED-BIG"), CancellationToken.None),
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(secondUserId, "FEED-BIG"), CancellationToken.None),
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(secondUserId, "FEED-BIG"), CancellationToken.None),
            await service.ApplyRedeemCodeAsync(new ApplyRedeemCodeCommand(thirdUserId, "FEED-BIG"), CancellationToken.None),
        };

        Assert.All(applies, apply => Assert.True(apply.IsSuccess));

        var redemptions = await dbContext.RedeemCodeRedemptions
            .Where(x => x.RedeemCodeId == codeResult.Value.RedeemCodeId)
            .OrderBy(x => x.RedeemedAtUtc)
            .ThenBy(x => x.Id)
            .ToListAsync();

        redemptions[0].RedeemedAtUtc = now.AddDays(-10);
        redemptions[1].RedeemedAtUtc = now.AddDays(-8);
        redemptions[2].RedeemedAtUtc = now.AddDays(-6);
        redemptions[3].RedeemedAtUtc = now.AddDays(-4);
        redemptions[4].RedeemedAtUtc = now.AddDays(-2);
        redemptions[5].RedeemedAtUtc = now.AddHours(-1);
        await dbContext.SaveChangesAsync();

        var list = await service.ListAdminRedeemCodesAsync(
            new AdminRedeemCodeListQuery(0, 20),
            CancellationToken.None);

        Assert.True(list.IsSuccess);
        var code = Assert.Single(list.Value.Items, x => x.RedeemCodeId == codeResult.Value.RedeemCodeId);

        Assert.Equal(4, code.UsesLast7d);
        Assert.Equal(80, code.GrantedLast7d);
        Assert.Equal(3, code.MaxRedeemedBySingleUser);
        Assert.Equal(5, code.Redemptions.Count);
        Assert.Equal(redemptions.Max(x => x.RedeemedAtUtc), code.LastRedeemedAtUtc);
        Assert.DoesNotContain(code.Redemptions, x => x.RedeemedAtUtc == now.AddDays(-10));
    }

    [Fact]
    public async Task ListAdminRedeemCodesAsync_ShouldFilterAndPageOnBackend()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var now = DateTime.UtcNow;

        var activeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("LAUNCH-ACTIVE", "Launch campaign", RedeemCodeRewardKind.Spark, 25, 100, 1, true, null, now.AddDays(7)),
            CancellationToken.None);
        var pausedResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("LAUNCH-PAUSED", "Launch campaign paused", RedeemCodeRewardKind.Spark, 25, 100, 1, false, null, now.AddDays(7)),
            CancellationToken.None);
        var otherResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("OTHER-ACTIVE", "Other campaign", RedeemCodeRewardKind.Spark, 50, 100, 1, true, null, now.AddDays(7)),
            CancellationToken.None);

        Assert.True(activeResult.IsSuccess);
        Assert.True(pausedResult.IsSuccess);
        Assert.True(otherResult.IsSuccess);

        var firstPage = await service.ListAdminRedeemCodesAsync(
            new AdminRedeemCodeListQuery(0, 1, Search: "launch", Status: "active", RewardKind: "spark", Sort: "code"),
            CancellationToken.None);
        var secondPage = await service.ListAdminRedeemCodesAsync(
            new AdminRedeemCodeListQuery(1, 1, Search: "launch", Status: "active", RewardKind: "spark", Sort: "code"),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess);
        var firstItem = Assert.Single(firstPage.Value.Items);
        Assert.Equal(activeResult.Value.RedeemCodeId, firstItem.RedeemCodeId);
        Assert.Equal(1, firstPage.Value.TotalCount);
        Assert.False(firstPage.Value.HasMore);

        Assert.True(secondPage.IsSuccess);
        Assert.Empty(secondPage.Value.Items);
        Assert.Equal(1, secondPage.Value.TotalCount);
        Assert.False(secondPage.Value.HasMore);
    }

    [Fact]
    public async Task ListAdminRedeemCodesAsync_ShouldApplyComputedStatusFiltersInDatabase()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var now = DateTime.UtcNow;

        var archivedResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                "STATUS-ARCHIVED",
                "Archived campaign",
                RedeemCodeRewardKind.Spark,
                25,
                100,
                1,
                false,
                now.AddDays(-1),
                now.AddDays(-1).AddSeconds(30)),
            CancellationToken.None);
        var expiredResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand(
                "STATUS-EXPIRED",
                "Expired campaign",
                RedeemCodeRewardKind.Spark,
                25,
                100,
                1,
                true,
                now.AddDays(-8),
                now.AddDays(-1)),
            CancellationToken.None);

        Assert.True(archivedResult.IsSuccess);
        Assert.True(expiredResult.IsSuccess);

        var archived = await service.ListAdminRedeemCodesAsync(
            new AdminRedeemCodeListQuery(Status: "archived", Sort: "code"),
            CancellationToken.None);
        var expired = await service.ListAdminRedeemCodesAsync(
            new AdminRedeemCodeListQuery(Status: "expired", Sort: "code"),
            CancellationToken.None);

        Assert.True(archived.IsSuccess);
        var archivedItem = Assert.Single(archived.Value.Items);
        Assert.Equal(archivedResult.Value.RedeemCodeId, archivedItem.RedeemCodeId);
        Assert.Equal(1, archived.Value.TotalCount);

        Assert.True(expired.IsSuccess);
        var expiredItem = Assert.Single(expired.Value.Items);
        Assert.Equal(expiredResult.Value.RedeemCodeId, expiredItem.RedeemCodeId);
        Assert.Equal(1, expired.Value.TotalCount);
    }

    [Fact]
    public async Task GetAdminRedeemCodeMetricsAsync_ShouldReturnBackendAggregatesForFilteredCodes()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);
        var now = DateTime.UtcNow;
        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();

        var activeResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("LAUNCH-METRICS", "Launch metrics", RedeemCodeRewardKind.Spark, 25, 100, 1, true, null, now.AddDays(7)),
            CancellationToken.None);
        var pausedResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("LAUNCH-METRICS-PAUSED", "Launch metrics paused", RedeemCodeRewardKind.Spark, 40, 100, 1, false, null, now.AddDays(7)),
            CancellationToken.None);
        var otherResult = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("OTHER-METRICS", "Other metrics", RedeemCodeRewardKind.Spark, 100, 100, 1, true, null, now.AddDays(7)),
            CancellationToken.None);

        Assert.True(activeResult.IsSuccess);
        Assert.True(pausedResult.IsSuccess);
        Assert.True(otherResult.IsSuccess);

        var firstApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(firstUserId, "LAUNCH-METRICS"),
            CancellationToken.None);
        var secondApply = await service.ApplyRedeemCodeAsync(
            new ApplyRedeemCodeCommand(secondUserId, "LAUNCH-METRICS"),
            CancellationToken.None);

        Assert.True(firstApply.IsSuccess);
        Assert.True(secondApply.IsSuccess);

        var oldRedemption = await dbContext.RedeemCodeRedemptions
            .Where(x => x.RedeemCodeId == activeResult.Value.RedeemCodeId)
            .OrderBy(x => x.RedeemedAtUtc)
            .FirstAsync();
        oldRedemption.RedeemedAtUtc = now.AddDays(-8);
        await dbContext.SaveChangesAsync();

        var allLaunchMetrics = await service.GetAdminRedeemCodeMetricsAsync(
            new AdminRedeemCodeListQuery(Search: "launch", RewardKind: "spark"),
            CancellationToken.None);
        var activeLaunchMetrics = await service.GetAdminRedeemCodeMetricsAsync(
            new AdminRedeemCodeListQuery(Search: "launch", Status: "active", RewardKind: "spark"),
            CancellationToken.None);

        Assert.True(allLaunchMetrics.IsSuccess);
        Assert.Equal(2, allLaunchMetrics.Value.TotalCodes);
        Assert.Equal(1, allLaunchMetrics.Value.ActiveCodes);
        Assert.Equal(2, allLaunchMetrics.Value.TotalUses);
        Assert.Equal(50, allLaunchMetrics.Value.TotalGranted);
        Assert.Equal(2, allLaunchMetrics.Value.CreatedLast7d);
        Assert.Equal(1, allLaunchMetrics.Value.ActiveTouchedLast7d);
        Assert.Equal(1, allLaunchMetrics.Value.UsesLast7d);
        Assert.Equal(25, allLaunchMetrics.Value.GrantedLast7d);

        Assert.True(activeLaunchMetrics.IsSuccess);
        Assert.Equal(1, activeLaunchMetrics.Value.TotalCodes);
        Assert.Equal(1, activeLaunchMetrics.Value.ActiveCodes);
        Assert.Equal(2, activeLaunchMetrics.Value.TotalUses);
        Assert.Equal(50, activeLaunchMetrics.Value.TotalGranted);
    }

    [Fact]
    public async Task CreateRedeemCodeAsync_ShouldRejectUnsupportedRewardKind()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);

        var result = await service.CreateRedeemCodeAsync(
            new CreateRedeemCodeCommand("PREMIUM7", "Premium week", "premium_days", 7, 10, 1, true, null, DateTime.UtcNow.AddDays(7)),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.RedeemCodeRewardUnsupported.Code, result.Error.Code);
    }

    private sealed class ThrowingAdminAuditLog : IAdminAuditLog
    {
        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken) =>
            throw new InvalidOperationException("Simulated central audit outage.");
    }
}
