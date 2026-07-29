using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task GetWalletAsync_ShouldGrantPremiumWeeklyTokensPerElapsedSubscriptionWeeks()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var subscriptionStartUtc = now.AddDays(-15);

        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            CurrentPeriodStartUtc = subscriptionStartUtc,
            CurrentPeriodEndUtc = now.AddDays(15),
            MonthlyTokenLimit = 500,
            CreatedAtUtc = subscriptionStartUtc,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var walletResult = await service.GetWalletAsync(userId, false, CancellationToken.None);

        Assert.True(walletResult.IsSuccess);
        Assert.Equal(80, walletResult.Value.Balance);
        Assert.NotNull(walletResult.Value.NextWeeklyGrantAtUtc);
        Assert.Equal(
            subscriptionStartUtc.AddDays(21).Date,
            walletResult.Value.NextWeeklyGrantAtUtc!.Value.Date);

        var weeklyEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PremiumSubscriptionWeeklyGrant)
            .ToListAsync();

        Assert.Equal(2, weeklyEntries.Count);
        Assert.All(weeklyEntries, entry => Assert.Equal(40, entry.Delta));
    }

    [Fact]
    public async Task GetWalletAsync_ShouldNotDuplicatePremiumWeeklyGrantWithinSameInterval()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var subscriptionStartUtc = now.AddDays(-8);

        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            CurrentPeriodStartUtc = subscriptionStartUtc,
            CurrentPeriodEndUtc = now.AddDays(20),
            MonthlyTokenLimit = 500,
            CreatedAtUtc = subscriptionStartUtc,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var first = await service.GetWalletAsync(userId, false, CancellationToken.None);
        var second = await service.GetWalletAsync(userId, false, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(40, first.Value.Balance);
        Assert.Equal(40, second.Value.Balance);

        var weeklyEntriesCount = await dbContext.WalletLedgerEntries
            .CountAsync(x => x.UserId == userId && x.Source == WalletLedgerSource.PremiumSubscriptionWeeklyGrant);

        Assert.Equal(1, weeklyEntriesCount);
    }

    [Fact]
    public async Task GetWalletAsync_ShouldNotDuplicatePremiumWeeklyGrantAcrossDuplicateActiveSubscriptions()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var subscriptionStartUtc = now.AddDays(-15);
        var originalSubscriptionId = Guid.NewGuid();

        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 80,
            UpdatedAtUtc = now.AddMinutes(-1)
        });
        dbContext.UserSubscriptions.AddRange(
            new UserSubscription
            {
                Id = originalSubscriptionId,
                UserId = userId,
                Provider = "google_play",
                PurchaseChannel = "in_app",
                Region = "US",
                PlanId = "monthly",
                Status = "Active",
                ExternalSubscriptionId = "gp_active",
                CurrentPeriodStartUtc = subscriptionStartUtc,
                CurrentPeriodEndUtc = now.AddDays(15),
                MonthlyTokenLimit = 500,
                CreatedAtUtc = subscriptionStartUtc,
                UpdatedAtUtc = now.AddMinutes(-10),
            },
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "monthly",
                Status = "Active",
                ExternalSubscriptionId = "sub_duplicate",
                CurrentPeriodStartUtc = subscriptionStartUtc,
                CurrentPeriodEndUtc = now.AddDays(15),
                MonthlyTokenLimit = 500,
                CreatedAtUtc = subscriptionStartUtc,
                UpdatedAtUtc = now,
            });
        dbContext.WalletLedgerEntries.AddRange(
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Delta = 40,
                BalanceAfter = 40,
                Source = WalletLedgerSource.PremiumSubscriptionWeeklyGrant,
                Reason = $"premium_weekly:{originalSubscriptionId:D}:1",
                CreatedAtUtc = now.AddDays(-8),
            },
            new WalletLedgerEntry
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Delta = 40,
                BalanceAfter = 80,
                Source = WalletLedgerSource.PremiumSubscriptionWeeklyGrant,
                Reason = $"premium_weekly:{originalSubscriptionId:D}:2",
                CreatedAtUtc = now.AddDays(-1),
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetWalletAsync(userId, false, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(80, result.Value.Balance);
        Assert.Equal(2, await dbContext.WalletLedgerEntries
            .CountAsync(x => x.UserId == userId && x.Source == WalletLedgerSource.PremiumSubscriptionWeeklyGrant));
    }

    [Fact]
    public async Task CreditAsync_ShouldIncreaseWalletAndAppendLedgerEntry()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var result = await service.CreditAsync(
            new CreditBalanceCommand(userId, 60, "generation_refund", "template_generation:test"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(60, result.Value.NewBalance);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        var ledger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);

        Assert.Equal(60, wallet.Balance);
        Assert.Equal(60, ledger.Delta);
        Assert.Equal("generation_refund", ledger.Source);
        Assert.Equal("template_generation:test", ledger.Reason);
        Assert.Equal(WalletTokenKind.RefundAdjustment, ledger.TokenKind);
        Assert.Equal("credit", ledger.OperationKind);

        var bucket = await dbContext.WalletTokenBuckets.SingleAsync(x => x.UserId == userId);
        Assert.Equal(WalletTokenKind.RefundAdjustment, bucket.Kind);
        Assert.Equal(60, bucket.InitialAmount);
        Assert.Equal(60, bucket.RemainingAmount);
        Assert.Equal(ledger.Id, bucket.SourceLedgerEntryId);
    }

    [Fact]
    public async Task SpendAsync_ShouldConsumeNonPurchasedBucketsBeforePurchasedBuckets()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        await service.CreditAsync(
            new CreditBalanceCommand(userId, 100, WalletLedgerSource.PackPurchase, "purchase:one", "purchase:one"),
            CancellationToken.None);
        await service.CreditAsync(
            new CreditBalanceCommand(userId, 30, WalletLedgerSource.RedeemCode, "promo:one", "promo:one"),
            CancellationToken.None);

        var spend = await service.SpendAsync(
            new SpendBalanceCommand(userId, 40, "template_generation:spend-one", WalletLedgerSource.GenerationSpend),
            CancellationToken.None);

        Assert.True(spend.IsSuccess);
        Assert.Equal(90, spend.Value.NewBalance);

        var buckets = await dbContext.WalletTokenBuckets
            .Where(x => x.UserId == userId)
            .ToDictionaryAsync(x => x.Kind);
        Assert.Equal(0, buckets[WalletTokenKind.Promo].RemainingAmount);
        Assert.Equal(90, buckets[WalletTokenKind.Purchased].RemainingAmount);

        var spendLedger = await dbContext.WalletLedgerEntries.SingleAsync(x => x.Source == WalletLedgerSource.GenerationSpend);
        Assert.Equal(WalletTokenKind.MixedSpend, spendLedger.TokenKind);
        Assert.Contains(WalletTokenKind.Promo, spendLedger.BucketDeltasJson);
        Assert.Contains(WalletTokenKind.Purchased, spendLedger.BucketDeltasJson);
    }

    [Fact]
    public async Task PurchaseRefund_ShouldConsumePurchasedBucketsBeforeBonusBuckets()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        await service.CreditAsync(
            new CreditBalanceCommand(userId, 100, WalletLedgerSource.PackPurchase, "purchase:refund-source", "purchase:refund-source"),
            CancellationToken.None);
        await service.CreditAsync(
            new CreditBalanceCommand(userId, 50, WalletLedgerSource.AdReward, "ad:bonus", "ad:bonus"),
            CancellationToken.None);

        var debit = await service.SpendAsync(
            new SpendBalanceCommand(userId, 80, "purchase_refund:refund-source", WalletLedgerSource.PurchaseRefund),
            CancellationToken.None);

        Assert.True(debit.IsSuccess);
        var purchasedBucket = await dbContext.WalletTokenBuckets.SingleAsync(x => x.Kind == WalletTokenKind.Purchased);
        var bonusBucket = await dbContext.WalletTokenBuckets.SingleAsync(x => x.Kind == WalletTokenKind.Bonus);
        Assert.Equal(20, purchasedBucket.RemainingAmount);
        Assert.Equal(50, bonusBucket.RemainingAmount);
    }

    [Fact]
    public async Task SpendAsync_ShouldCreateLegacyBucketProjectionForExistingWalletBalance()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 20,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).SpendAsync(
            new SpendBalanceCommand(userId, 5, "template_generation:legacy-spend"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var legacyBucket = await dbContext.WalletTokenBuckets.SingleAsync(x => x.UserId == userId);
        Assert.Equal(WalletTokenKind.Legacy, legacyBucket.Kind);
        Assert.Equal(15, legacyBucket.RemainingAmount);
    }

    [Fact]
    public async Task CreditAsync_ShouldBeIdempotentForGenerationRefundReason()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var idempotencyKey = $"generation_refund:{generationId:N}";
        var service = CreateService(dbContext);
        var command = new CreditBalanceCommand(
            userId,
            60,
            WalletLedgerSource.GenerationRefund,
            $"template_generation:{generationId:N}",
            idempotencyKey);

        var first = await service.CreditAsync(command, CancellationToken.None);
        var second = await service.CreditAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(60, first.Value.Delta);
        Assert.Equal(60, first.Value.NewBalance);
        Assert.Equal(60, second.Value.NewBalance);
        Assert.Equal(0, second.Value.Delta);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.GenerationRefund)
            .ToArrayAsync();

        Assert.Equal(60, wallet.Balance);
        var ledgerEntry = Assert.Single(ledgerEntries);
        Assert.Equal(60, ledgerEntry.Delta);
        Assert.Equal(idempotencyKey, ledgerEntry.Reason);
    }

    [Fact]
    public async Task CreditAsync_ShouldHonorPreviousGenerationRefundIdempotencyKey()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var feedbackId = Guid.NewGuid();
        var legacyKey = $"feedback_refund:{feedbackId:N}";
        var currentKey = $"generation_refund:{generationId:N}";
        var service = CreateService(dbContext);

        var historicalCredit = await service.CreditAsync(
            new CreditBalanceCommand(
                userId,
                60,
                WalletLedgerSource.GenerationRefund,
                "historical admin refund",
                legacyKey),
            CancellationToken.None);
        var recoveredCurrentCredit = await service.CreditAsync(
            new CreditBalanceCommand(
                userId,
                60,
                WalletLedgerSource.GenerationRefund,
                "current admin refund",
                currentKey,
                PreviousIdempotencyKeys: [legacyKey]),
            CancellationToken.None);

        Assert.True(historicalCredit.IsSuccess);
        Assert.True(recoveredCurrentCredit.IsSuccess);
        Assert.Equal(60, historicalCredit.Value.Delta);
        Assert.Equal(0, recoveredCurrentCredit.Value.Delta);
        Assert.Equal(60, recoveredCurrentCredit.Value.NewBalance);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal(60, wallet.Balance);
        Assert.Equal(legacyKey, ledgerEntry.Reason);
    }

    [Fact]
    public async Task GenerationRefund_ShouldNoOp_WhenRetriedAfterJobStatusSaveFailure()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        var service = CreateService(dbContext);
        var billing = new EconomyTemplateGenerationBilling(service);

        var first = await billing.RefundAsync(userId, generationId, 60, CancellationToken.None);
        var retryAfterJobSaveFailure = await billing.RefundAsync(userId, generationId, 60, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(retryAfterJobSaveFailure.IsSuccess);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.GenerationRefund)
            .ToArrayAsync();

        Assert.Equal(60, wallet.Balance);
        var ledgerEntry = Assert.Single(ledgerEntries);
        Assert.Equal(60, ledgerEntry.Delta);
        Assert.Equal($"generation_refund:{generationId:N}", ledgerEntry.Reason);
    }

    [Fact]
    public async Task GenerationCharge_ShouldNoOp_WhenRetriedAfterJobStatusSaveFailure()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var generationId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 100,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(dbContext);
        var billing = new EconomyTemplateGenerationBilling(service);

        var first = await billing.ChargeAsync(userId, generationId, 60, CancellationToken.None);
        var retryAfterJobSaveFailure = await billing.ChargeAsync(
            userId,
            generationId,
            60,
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(retryAfterJobSaveFailure.IsSuccess);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.GenerationSpend)
            .ToArrayAsync();

        Assert.Equal(40, wallet.Balance);
        var ledgerEntry = Assert.Single(ledgerEntries);
        Assert.Equal(-60, ledgerEntry.Delta);
        Assert.Equal($"template_generation:{generationId:N}", ledgerEntry.Reason);
        Assert.Equal("internal", ledgerEntry.SourceProvider);
        Assert.NotNull(ledgerEntry.SourceTransactionId);
    }

    [Fact]
    public async Task SpendAsync_ShouldBeIdempotentForWatermarkUnlockReason()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 3,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();
        var service = CreateService(dbContext);

        var command = new SpendBalanceCommand(
            userId,
            1,
            "template_watermark_unlock:abc123",
            WalletLedgerSource.WatermarkUnlock);
        var first = await service.SpendAsync(command, CancellationToken.None);
        var second = await service.SpendAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(2, first.Value.NewBalance);
        Assert.Equal(2, second.Value.NewBalance);
        Assert.Equal(0, second.Value.Delta);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.WatermarkUnlock)
            .ToArrayAsync();
        Assert.Equal(2, wallet.Balance);
        var ledgerEntry = Assert.Single(ledgerEntries);
        Assert.Equal(-1, ledgerEntry.Delta);
        Assert.Equal(command.Reason, ledgerEntry.Reason);
    }

    [Fact]
    public async Task CreditAsync_ShouldBeIdempotentForGenericIdempotencyKey()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        var command = new CreditBalanceCommand(
            userId,
            75,
            WalletLedgerSource.AdminGrant,
            "support:manual-credit",
            "admin-credit-ticket-1");

        var first = await service.CreditAsync(command, CancellationToken.None);
        var duplicate = await service.CreditAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal(75, first.Value.NewBalance);
        Assert.Equal(75, duplicate.Value.NewBalance);
        Assert.Equal(0, duplicate.Value.Delta);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);

        Assert.Equal(75, wallet.Balance);
        Assert.Equal(75, ledgerEntry.Delta);
        Assert.Equal(WalletLedgerSource.AdminGrant, ledgerEntry.Source);
        Assert.Equal("admin-credit-ticket-1", ledgerEntry.Reason);
        Assert.Equal("internal", ledgerEntry.SourceProvider);
        Assert.StartsWith("wallet:", ledgerEntry.SourceTransactionId, StringComparison.Ordinal);
    }

    [Fact]
    public async Task CreditAsync_ShouldPreserveHumanLedgerReasonWhenIdempotencyKeyIsProvided()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        var command = new CreditBalanceCommand(
            userId,
            75,
            WalletLedgerSource.AdminGrant,
            "support:manual-credit",
            "wallet-adjustment:credit-1",
            LedgerReason: "Customer support compensation",
            IdempotencyScope: "admin_user_wallet");

        var first = await service.CreditAsync(command, CancellationToken.None);
        var duplicate = await service.CreditAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal(75, first.Value.NewBalance);
        Assert.Equal(0, duplicate.Value.Delta);

        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal("Customer support compensation", ledgerEntry.Reason);
        Assert.Equal("internal", ledgerEntry.SourceProvider);
        Assert.StartsWith("wallet:", ledgerEntry.SourceTransactionId, StringComparison.Ordinal);
    }

    [Fact]
    public async Task SpendAsync_ShouldBeIdempotentForGenericIdempotencyKey()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 100,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var command = new SpendBalanceCommand(
            userId,
            25,
            "Customer support correction",
            WalletLedgerSource.AdminDebit,
            "wallet-adjustment:debit-1",
            IdempotencyScope: "admin_user_wallet");

        var first = await service.SpendAsync(command, CancellationToken.None);
        var duplicate = await service.SpendAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal(75, first.Value.NewBalance);
        Assert.Equal(75, duplicate.Value.NewBalance);
        Assert.Equal(0, duplicate.Value.Delta);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal(75, wallet.Balance);
        Assert.Equal(-25, ledgerEntry.Delta);
        Assert.Equal("Customer support correction", ledgerEntry.Reason);
        Assert.Equal("internal", ledgerEntry.SourceProvider);
        Assert.StartsWith("wallet:", ledgerEntry.SourceTransactionId, StringComparison.Ordinal);
    }

    [Fact]
    public async Task WalletAdjustmentScope_ShouldNotApplyDifferentOperationsWithTheSameIdempotencyKey()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        const string idempotencyKey = "wallet-adjustment:single-operation";

        var credit = await service.CreditAsync(
            new CreditBalanceCommand(
                userId,
                80,
                WalletLedgerSource.AdminGrant,
                "Customer support compensation",
                idempotencyKey,
                LedgerReason: "Customer support compensation",
                IdempotencyScope: "admin_user_wallet"),
            CancellationToken.None);
        var conflictingDebit = await service.SpendAsync(
            new SpendBalanceCommand(
                userId,
                30,
                "Customer support correction",
                WalletLedgerSource.AdminDebit,
                idempotencyKey,
                IdempotencyScope: "admin_user_wallet"),
            CancellationToken.None);

        Assert.True(credit.IsSuccess);
        Assert.True(conflictingDebit.IsSuccess);
        Assert.Equal(80, credit.Value.NewBalance);
        Assert.Equal(80, conflictingDebit.Value.NewBalance);
        Assert.Equal(0, conflictingDebit.Value.Delta);

        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .ToListAsync();
        Assert.Single(ledgerEntries);
        Assert.Equal(WalletLedgerSource.AdminGrant, ledgerEntries[0].Source);
    }

    [Fact]
    public async Task CreditAsync_ShouldRejectInvalidWalletReasonsWithoutPersistingLedger()
    {
        await using var dbContext = CreateDbContext();

        var service = CreateService(dbContext);

        var blankReason = await service.CreditAsync(
            new CreditBalanceCommand(Guid.NewGuid(), 75, WalletLedgerSource.AdminGrant, "   "),
            CancellationToken.None);
        var oversizedReason = await service.CreditAsync(
            new CreditBalanceCommand(Guid.NewGuid(), 75, WalletLedgerSource.AdminGrant, new string('r', 121)),
            CancellationToken.None);

        Assert.True(blankReason.IsFailure);
        Assert.Equal(EconomyErrors.InvalidWalletReason.Code, blankReason.Error.Code);
        Assert.True(oversizedReason.IsFailure);
        Assert.Equal(EconomyErrors.InvalidWalletReason.Code, oversizedReason.Error.Code);
        Assert.Empty(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task SpendAsync_ShouldBeIdempotentForGenerationSpendReason()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 100,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var command = new SpendBalanceCommand(userId, 60, "template_generation:job-1");

        var first = await service.SpendAsync(command, CancellationToken.None);
        var duplicate = await service.SpendAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(duplicate.IsSuccess);
        Assert.Equal(40, first.Value.NewBalance);
        Assert.Equal(40, duplicate.Value.NewBalance);
        Assert.Equal(0, duplicate.Value.Delta);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);

        Assert.Equal(40, wallet.Balance);
        Assert.Equal(-60, ledgerEntry.Delta);
        Assert.Equal(WalletLedgerSource.GenerationSpend, ledgerEntry.Source);
    }

    [Fact]
    public async Task WalletMutations_ShouldPreserveLedgerConsistencyAcrossCreditAndSpendRace()
    {
        await using var anchorConnection = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();

        await using (var seedContext = CreateSqliteDbContext(anchorConnection.ConnectionString))
        {
            seedContext.Wallets.Add(new Wallet
            {
                UserId = userId,
                Balance = 50,
                UpdatedAtUtc = DateTime.UtcNow
            });
            await seedContext.SaveChangesAsync();
        }

        var creditTask = Task.Run(async () =>
        {
            await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
            var result = await CreateService(dbContext).CreditAsync(
                new CreditBalanceCommand(userId, 30, WalletLedgerSource.AdminGrant, "race:credit", "race-credit-1"),
                CancellationToken.None);
            Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
        });
        var spendTask = Task.Run(async () =>
        {
            await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
            var result = await CreateService(dbContext).SpendAsync(
                new SpendBalanceCommand(userId, 40, "template_generation:race-spend"),
                CancellationToken.None);
            Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
        });

        await Task.WhenAll(creditTask, spendTask);

        await using var verifyContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
        var wallet = await verifyContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await verifyContext.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .OrderBy(x => x.CreatedAtUtc)
            .ToArrayAsync();

        Assert.Equal(40, wallet.Balance);
        Assert.Equal(2, ledgerEntries.Length);
        Assert.Equal(wallet.Balance, ledgerEntries.Last().BalanceAfter);
        Assert.Equal(40, 50 + ledgerEntries.Sum(x => x.Delta));
    }

    [Fact]
    public async Task WalletMutations_ShouldPreserveParallelCredits()
    {
        await using var anchorConnection = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();

        var tasks = Enumerable.Range(0, 2)
            .Select(index => Task.Run(async () =>
            {
                await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
                var result = await CreateService(dbContext).CreditAsync(
                    new CreditBalanceCommand(
                        userId,
                        25,
                        WalletLedgerSource.AdminGrant,
                        $"parallel-credit:{index}",
                        $"parallel-credit:{index}"),
                    CancellationToken.None);
                Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
            }))
            .ToArray();

        await Task.WhenAll(tasks);

        await using var verifyContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
        var wallet = await verifyContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await verifyContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.AdminGrant)
            .ToArrayAsync();

        Assert.Equal(50, wallet.Balance);
        Assert.Equal(2, ledgerEntries.Length);
        Assert.Equal(50, ledgerEntries.Sum(x => x.Delta));
    }

    [Fact]
    public async Task WalletMutations_ShouldPreserveParallelSpends()
    {
        await using var anchorConnection = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();

        await using (var seedContext = CreateSqliteDbContext(anchorConnection.ConnectionString))
        {
            seedContext.Wallets.Add(new Wallet
            {
                UserId = userId,
                Balance = 50,
                UpdatedAtUtc = DateTime.UtcNow
            });
            await seedContext.SaveChangesAsync();
        }

        var tasks = Enumerable.Range(0, 2)
            .Select(index => Task.Run(async () =>
            {
                await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
                var result = await CreateService(dbContext).SpendAsync(
                    new SpendBalanceCommand(userId, 20, $"template_generation:parallel-spend-{index}"),
                    CancellationToken.None);
                Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
            }))
            .ToArray();

        await Task.WhenAll(tasks);

        await using var verifyContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
        var wallet = await verifyContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await verifyContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.GenerationSpend)
            .ToArrayAsync();

        Assert.Equal(10, wallet.Balance);
        Assert.Equal(2, ledgerEntries.Length);
        Assert.Equal(-40, ledgerEntries.Sum(x => x.Delta));
    }

    [Fact]
    public async Task WalletMutations_ShouldPreserveAdminGrantAndPurchaseConfirmationTogether()
    {
        await using var anchorConnection = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();
        PurchaseCheckoutResponse checkout;

        await using (var setupContext = CreateSqliteDbContext(anchorConnection.ConnectionString))
        {
            var packId = AddStarterPack(setupContext);
            var createResult = await CreateService(setupContext).CreatePackPurchaseAsync(
                new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
                CancellationToken.None);
            Assert.True(createResult.IsSuccess, createResult.IsFailure ? createResult.Error.Code : string.Empty);
            checkout = createResult.Value;
        }

        var eventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{checkout.ExternalPaymentId}\",\"object\":\"checkout.session\",\"status\":\"complete\",\"payment_status\":\"paid\",\"metadata\":{{\"order_id\":\"{checkout.OrderId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var adminGrantTask = Task.Run(async () =>
        {
            await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
            var result = await CreateService(dbContext).CreditAsync(
                new CreditBalanceCommand(userId, 25, WalletLedgerSource.AdminGrant, "support:parallel-grant", "support:parallel-grant"),
                CancellationToken.None);
            Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
        });
        var purchaseConfirmationTask = Task.Run(async () =>
        {
            await using var dbContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
            var result = await CreateService(dbContext).HandleStripeWebhookAsync(
                new StripeWebhookCommand(payload, signature),
                CancellationToken.None);
            Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
        });

        await Task.WhenAll(adminGrantTask, purchaseConfirmationTask);

        await using var verifyContext = CreateSqliteDbContext(anchorConnection.ConnectionString);
        var wallet = await verifyContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await verifyContext.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .ToArrayAsync();

        Assert.Equal(145, wallet.Balance);
        Assert.Contains(ledgerEntries, x => x.Source == WalletLedgerSource.AdminGrant && x.Delta == 25);
        Assert.Contains(ledgerEntries, x => x.Source == WalletLedgerSource.PackPurchase && x.Delta == 120);
    }

    [Fact]
    public async Task GenerationRefundAndNewSpend_ShouldRemainConsistentWhenAppliedTogether()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 60,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var refund = await service.CreditAsync(
            new CreditBalanceCommand(
                userId,
                60,
                WalletLedgerSource.GenerationRefund,
                "template_generation:failed-job",
                "generation_refund:failed-job"),
            CancellationToken.None);
        var newSpend = await service.SpendAsync(
            new SpendBalanceCommand(userId, 60, "template_generation:new-job"),
            CancellationToken.None);

        Assert.True(refund.IsSuccess);
        Assert.True(newSpend.IsSuccess);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .ToArrayAsync();

        Assert.Equal(60, wallet.Balance);
        Assert.Equal(2, ledgerEntries.Length);
        Assert.Equal(0, ledgerEntries.Sum(x => x.Delta));
    }

    [Fact]
    public async Task GetRewardsSummaryAsync_ShouldCreateStableReferralCode()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var first = await service.GetRewardsSummaryAsync(userId, CancellationToken.None);
        var second = await service.GetRewardsSummaryAsync(userId, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(first.Value.ReferralCode, second.Value.ReferralCode);
        Assert.StartsWith("PM", first.Value.ReferralCode, StringComparison.Ordinal);
        Assert.Equal("none", first.Value.ReferralStatus);
        Assert.Equal(15, first.Value.ReferralBonusSpark);
    }

    [Fact]
    public async Task ApplyReferralCodeAsync_ShouldRejectSelfReferralAndDuplicateActivation()
    {
        await using var dbContext = CreateDbContext();

        var referrerId = Guid.NewGuid();
        var refereeId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var referrerRewards = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        Assert.True(referrerRewards.IsSuccess);

        var selfReferral = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(referrerId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(selfReferral.IsFailure);
        Assert.Equal(EconomyErrors.ReferralSelfReferral.Code, selfReferral.Error.Code);

        var firstActivation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);
        var duplicateActivation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(firstActivation.IsSuccess);
        Assert.True(duplicateActivation.IsFailure);
        Assert.Equal(EconomyErrors.ReferralAlreadyLinked.Code, duplicateActivation.Error.Code);
    }

    [Fact]
    public async Task ApplyReferralCodeAsync_ShouldRejectUsersAfterFirstPaidPurchase()
    {
        await using var dbContext = CreateDbContext();

        var referrerId = Guid.NewGuid();
        var refereeId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var service = CreateService(dbContext);

        var verifiedPurchase = await CreateAndVerifyStorePurchaseAsync(
            dbContext,
            service,
            refereeId,
            packId);
        Assert.Equal(PurchaseOrderStatus.Succeeded, verifiedPurchase.Status);

        var referrerRewards = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        var activation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(activation.IsFailure);
        Assert.Equal(EconomyErrors.ReferralPaidUserIneligible.Code, activation.Error.Code);
    }

    [Fact]
    public async Task ApplyReferralCodeAsync_ShouldAllowPendingSubscriptionWithoutPaidPurchase()
    {
        await using var dbContext = CreateDbContext();

        var referrerId = Guid.NewGuid();
        var refereeId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = refereeId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Pending",
            ExternalSubscriptionId = null,
            CurrentPeriodStartUtc = null,
            CurrentPeriodEndUtc = null,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var referrerRewards = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        var activation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(activation.IsSuccess);
        Assert.Equal(ReferralAttributionStatus.Pending, activation.Value.Status);
    }

    [Fact]
    public async Task ApplyReferralCodeAsync_ShouldRejectUsersWithPastDueSubscriptionBeforePeriodEnd()
    {
        await using var dbContext = CreateDbContext();

        var referrerId = Guid.NewGuid();
        var refereeId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = refereeId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "PastDue",
            ExternalSubscriptionId = "sub_past_due",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = now.AddDays(5),
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now.AddDays(-10),
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var referrerRewards = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        var activation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(activation.IsFailure);
        Assert.Equal(EconomyErrors.ReferralPaidUserIneligible.Code, activation.Error.Code);
    }

    [Fact]
    public async Task VerifiedStorePurchase_ShouldSettlePendingReferralBonusOnce()
    {
        await using var dbContext = CreateDbContext();

        var referrerId = Guid.NewGuid();
        var refereeId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var service = CreateService(dbContext);

        var referrerRewards = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        var activation = await service.ApplyReferralCodeAsync(
            new ApplyReferralCodeCommand(refereeId, referrerRewards.Value.ReferralCode),
            CancellationToken.None);

        Assert.True(activation.IsSuccess);

        await service.ClaimAdRewardAsync(new ClaimAdRewardCommand(refereeId), CancellationToken.None);
        Assert.False(await dbContext.WalletLedgerEntries.AnyAsync(x => x.Source == WalletLedgerSource.ReferralBonus));

        var verifiedPurchase = await CreateAndVerifyStorePurchaseAsync(
            dbContext,
            service,
            refereeId,
            packId);

        Assert.Equal(PurchaseOrderStatus.Succeeded, verifiedPurchase.Status);

        var referrerWallet = await dbContext.Wallets.SingleAsync(x => x.UserId == referrerId);
        var refereeWallet = await dbContext.Wallets.SingleAsync(x => x.UserId == refereeId);
        var referralEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.Source == WalletLedgerSource.ReferralBonus)
            .ToListAsync();
        var attribution = await dbContext.ReferralAttributions.SingleAsync(x => x.RefereeUserId == refereeId);

        Assert.Equal(15, referrerWallet.Balance);
        Assert.Equal(150, refereeWallet.Balance);
        Assert.Equal(2, referralEntries.Count);
        Assert.Equal(ReferralAttributionStatus.Rewarded, attribution.Status);
        Assert.NotNull(attribution.QualifiedAtUtc);

        var summary = await service.GetRewardsSummaryAsync(referrerId, CancellationToken.None);
        Assert.True(summary.IsSuccess);
        Assert.Equal(15, summary.Value.TotalReferralBonusEarned);
        Assert.Equal(1, summary.Value.RewardedReferredUsersCount);
    }

    [Fact]
    public async Task GetWalletLedgerAsync_ShouldReturnRecentUserEntries()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var otherUserId = Guid.NewGuid();
        var service = CreateService(dbContext);

        await service.CreditAsync(new CreditBalanceCommand(userId, 90, "admin_grant", "support:credit"), CancellationToken.None);
        await service.SpendAsync(new SpendBalanceCommand(userId, 30, "template_generation:test"), CancellationToken.None);
        await service.CreditAsync(new CreditBalanceCommand(otherUserId, 200, "admin_grant", "support:other"), CancellationToken.None);

        var result = await service.GetWalletLedgerAsync(userId, 0, 10, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Items.Count);
        Assert.All(result.Value.Items, item => Assert.Equal(userId, item.UserId));
        Assert.Equal(-30, result.Value.Items[0].Delta);
        Assert.False(result.Value.HasMore);
    }

    [Fact]
    public async Task GetPurchaseHistoryAsync_ShouldReturnUserPurchasesWithPackMetadata()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });

        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var history = await service.GetPurchaseHistoryAsync(userId, 0, 10, CancellationToken.None);

        Assert.True(history.IsSuccess);
        var purchase = Assert.Single(history.Value.Items);
        Assert.Equal(createResult.Value.OrderId, purchase.OrderId);
        Assert.Equal("starter", purchase.PackCode);
        Assert.Equal("Starter PawSpark", purchase.PackDisplayName);
        Assert.Equal(120, purchase.SparkToGrant);
        Assert.Null(purchase.ExternalPaymentId);
    }

    [Fact]
    public async Task GetAdminPurchaseHistoryAsync_ShouldFilterByUserId()
    {
        await using var dbContext = CreateDbContext();

        var firstUserId = Guid.NewGuid();
        var secondUserId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });

        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(firstUserId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);
        await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(secondUserId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        var allPurchases = await service.GetAdminPurchaseHistoryAsync(0, 10, null, null, null, null, CancellationToken.None);
        var filteredPurchases = await service.GetAdminPurchaseHistoryAsync(0, 10, null, null, null, firstUserId, CancellationToken.None);

        Assert.True(allPurchases.IsSuccess);
        Assert.True(filteredPurchases.IsSuccess);
        Assert.Equal(2, allPurchases.Value.Items.Count);
        var filtered = Assert.Single(filteredPurchases.Value.Items);
        Assert.Equal(firstUserId, filtered.UserId);
    }

    [Fact]
    public async Task GetAdminPurchaseHistoryAsync_ShouldFilterByProviderAndSearch()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        dbContext.PurchaseOrders.AddRange(
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                PackId = packId,
                PaymentProvider = "stripe",
                Status = "succeeded",
                PriceAmount = 4.99m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                ExternalPaymentId = "pi_secret_should_not_be_needed",
                CreatedAtUtc = now.AddMinutes(-1),
                ConfirmedAtUtc = now
            },
            new PurchaseOrder
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PackId = packId,
                PaymentProvider = "app_store",
                Status = "succeeded",
                PriceAmount = 4.99m,
                CurrencyCode = "USD",
                SparkToGrant = 120,
                CreatedAtUtc = now.AddMinutes(-2),
                ConfirmedAtUtc = now.AddMinutes(-2)
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminPurchaseHistoryAsync(
            0,
            10,
            "succeeded",
            "stripe",
            "starter",
            null,
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(userId, item.UserId);
        Assert.Equal("stripe", item.PaymentProvider);
        Assert.Equal("starter", item.PackCode);
        Assert.Null(item.ExternalPaymentId);
        Assert.True(item.CanRefund);
    }

    [Fact]
    public async Task RefundAdminPurchaseAsync_ShouldMarkSucceededStripePurchaseAsRefundedAndRevokeGrantedTokens()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow;
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 120,
            BalanceAfter = 120,
            Source = WalletLedgerSource.PackPurchase,
            Reason = $"purchase:{orderId:D}",
            SourceProvider = "stripe",
            SourceTransactionId = "pi_refundable",
            CreatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_refundable",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var auditLog = new RecordingAdminAuditLog();
        var result = await CreateService(dbContext, adminAuditLog: auditLog).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "support refund"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.Refunded, result.Value.Status);
        Assert.Null(result.Value.ExternalPaymentId);
        Assert.False(result.Value.CanRefund);
        Assert.Equal(PurchaseOrderStatus.Refunded, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(0, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());

        var refundLedger = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .SingleAsync();
        Assert.Equal(-120, refundLedger.Delta);
        Assert.Equal(0, refundLedger.BalanceAfter);
        Assert.Equal($"purchase_refund:{orderId:D}", refundLedger.Reason);
        Assert.Equal("internal", refundLedger.SourceProvider);
        Assert.Equal($"refund-reservation:{orderId:D}", refundLedger.SourceTransactionId);
        var auditEntry = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.payment.refunded", auditEntry.Action);
        Assert.DoesNotContain($"re_{orderId:N}", auditEntry.Details, StringComparison.Ordinal);
        Assert.Contains("Provider refund recorded.", auditEntry.Details, StringComparison.Ordinal);
    }

    [Fact]
    public async Task RefundAdminPurchaseAsync_ShouldCreateManualReviewWithoutCallingStripe_WhenTokensWereSpent()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow;
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 0,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 120,
            BalanceAfter = 120,
            Source = WalletLedgerSource.PackPurchase,
            Reason = $"purchase:{orderId:D}",
            SourceProvider = "stripe",
            SourceTransactionId = "pi_spent",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-2)
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = -120,
            BalanceAfter = 0,
            Source = WalletLedgerSource.GenerationSpend,
            Reason = "template_generation:spent-before-refund",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1)
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_spent",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-5),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var gateway = new FakePaymentGateway();
        var auditLog = new RecordingAdminAuditLog();
        var result = await CreateService(dbContext, gateway: gateway, adminAuditLog: auditLog).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "spent tokens"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.RefundRequiresManualReview, result.Value.Status);
        Assert.Equal("requires_manual_review", result.Value.RefundStatus);
        Assert.False(result.Value.CanRefund);
        Assert.Empty(gateway.RefundRequests);
        Assert.Equal(0, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());
        Assert.False(await dbContext.WalletLedgerEntries
            .AnyAsync(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund));

        var auditEntry = Assert.Single(auditLog.Entries);
        Assert.Equal("admin.payment.refund_manual_review_required", auditEntry.Action);
        Assert.Equal(PurchaseOrderStatus.Succeeded, auditEntry.OldValue);
        Assert.Equal(PurchaseOrderStatus.RefundRequiresManualReview, auditEntry.NewValue);
    }

    [Fact]
    public async Task RefundAdminPurchaseAsync_ShouldLeaveRefundPendingForRetry_WhenStripeCallFailsAfterLocalReservation()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow;
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_retry",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-5),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var gateway = new FakePaymentGateway
        {
            RefundResult = Result.Failure<PaymentRefundResponse>(EconomyErrors.PaymentGatewayFailed)
        };
        var auditLog = new RecordingAdminAuditLog();
        var failed = await CreateService(dbContext, gateway: gateway, adminAuditLog: auditLog).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "temporary gateway failure"),
            CancellationToken.None);

        Assert.True(failed.IsFailure);
        Assert.Equal(EconomyErrors.PaymentGatewayFailed.Code, failed.Error.Code);
        Assert.Single(gateway.RefundRequests);
        Assert.Equal(PurchaseOrderStatus.RefundPending, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(0, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());
        Assert.Single(await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .ToListAsync());

        gateway.RefundResult = null;
        var retried = await CreateService(dbContext, gateway: gateway, adminAuditLog: auditLog).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "retry"),
            CancellationToken.None);

        Assert.True(retried.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.Refunded, retried.Value.Status);
        Assert.Equal(2, gateway.RefundRequests.Count);
        Assert.Single(await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .ToListAsync());
    }

    [Fact]
    public async Task RefundAdminPurchaseAsync_ShouldBeIdempotentForAlreadyRefundedPurchase()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 0,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = -120,
            BalanceAfter = 0,
            Source = WalletLedgerSource.PurchaseRefund,
            Reason = $"purchase_refund:{orderId:D}",
            SourceProvider = "stripe",
            SourceTransactionId = $"re_{orderId:N}",
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Refunded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_refundable",
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-5),
            ConfirmedAtUtc = DateTime.UtcNow.AddMinutes(-4)
        });
        await dbContext.SaveChangesAsync();

        var gateway = new FakePaymentGateway();
        var result = await CreateService(dbContext, gateway: gateway).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "duplicate refund"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.Refunded, result.Value.Status);
        Assert.Empty(gateway.RefundRequests);
        Assert.Equal(1, await dbContext.WalletLedgerEntries
            .CountAsync(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund));
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldReconcileRefundedPurchaseFromRefundWebhook()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 120,
            BalanceAfter = 120,
            Source = WalletLedgerSource.PackPurchase,
            Reason = $"purchase:{orderId:D}",
            SourceProvider = "stripe",
            SourceTransactionId = "pi_refundable",
            CreatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_refundable",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var eventId = $"evt_{Guid.NewGuid():N}";
        var refundId = $"re_{orderId:N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"refund.created\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{refundId}\",\"object\":\"refund\",\"status\":\"succeeded\",\"amount\":499,\"currency\":\"usd\",\"metadata\":{{\"order_id\":\"{orderId:D}\",\"reason\":\"support refund\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var result = await CreateService(dbContext).HandleStripeWebhookAsync(
            new StripeWebhookCommand(payload, signature),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.Processed);
        Assert.Equal(PurchaseOrderStatus.Refunded, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(0, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());

        var refundLedger = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .SingleAsync();
        Assert.Equal(-120, refundLedger.Delta);
        Assert.Equal(refundId, refundLedger.SourceTransactionId);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldRequireManualReviewForPartialRefundWithoutClawback()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_partial_refund",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var eventId = $"evt_{Guid.NewGuid():N}";
        var refundId = $"re_{orderId:N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"refund.created\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{refundId}\",\"object\":\"refund\",\"status\":\"succeeded\",\"amount\":200,\"currency\":\"usd\",\"metadata\":{{\"order_id\":\"{orderId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var result = await CreateService(dbContext).HandleStripeWebhookAsync(
            new StripeWebhookCommand(payload, signature),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.RefundRequiresManualReview, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(120, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());
        Assert.Empty(await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .ToListAsync());
        Assert.Single(await dbContext.EconomyIncidents
            .Where(x => x.PurchaseOrderId == orderId && x.Type == "RefundRequiresManualReview")
            .ToListAsync());
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldCreateManualReview_WhenExternalRefundArrivesAfterTokensWereSpent()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 0,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_external_refund_spent",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var eventId = $"evt_{Guid.NewGuid():N}";
        var refundId = $"re_{orderId:N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"refund.created\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{refundId}\",\"object\":\"refund\",\"status\":\"succeeded\",\"amount\":499,\"currency\":\"usd\",\"metadata\":{{\"order_id\":\"{orderId:D}\",\"reason\":\"dashboard refund\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var result = await CreateService(dbContext).HandleStripeWebhookAsync(
            new StripeWebhookCommand(payload, signature),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.Processed);
        Assert.Equal(PurchaseOrderStatus.RefundRequiresManualReview, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Empty(await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .ToListAsync());
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldBeIdempotentForDuplicateRefundWebhook()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_duplicate_refund",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var eventId = $"evt_{Guid.NewGuid():N}";
        var refundId = $"re_{orderId:N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"refund.created\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{refundId}\",\"object\":\"refund\",\"status\":\"succeeded\",\"amount\":499,\"currency\":\"usd\",\"metadata\":{{\"order_id\":\"{orderId:D}\",\"reason\":\"duplicate refund\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");
        var service = CreateService(dbContext);

        var first = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);
        var duplicate = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(duplicate.IsSuccess);
        Assert.True(first.Value.Processed);
        Assert.False(duplicate.Value.Processed);
        Assert.Equal(PurchaseOrderStatus.Refunded, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Single(await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .ToListAsync());
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldReconcileRefundedPurchaseFromRefundWebhookPaymentIntentFallback()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        var confirmedAtUtc = DateTime.UtcNow.AddMinutes(-5);
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = confirmedAtUtc
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 120,
            BalanceAfter = 120,
            Source = WalletLedgerSource.PackPurchase,
            Reason = $"purchase:{orderId:D}",
            SourceProvider = "stripe",
            SourceTransactionId = "pi_refundable_fallback",
            CreatedAtUtc = confirmedAtUtc
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_refundable_fallback",
            CreatedAtUtc = confirmedAtUtc.AddMinutes(-1),
            ConfirmedAtUtc = confirmedAtUtc
        });
        await dbContext.SaveChangesAsync();

        var eventId = $"evt_{Guid.NewGuid():N}";
        var refundId = $"re_{orderId:N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"refund.created\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{refundId}\",\"object\":\"refund\",\"status\":\"succeeded\",\"amount\":499,\"currency\":\"usd\",\"payment_intent\":\"pi_refundable_fallback\",\"metadata\":{{\"reason\":\"support refund\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var result = await CreateService(dbContext).HandleStripeWebhookAsync(
            new StripeWebhookCommand(payload, signature),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.Processed);
        Assert.Equal(PurchaseOrderStatus.Refunded, await dbContext.PurchaseOrders
            .Where(x => x.Id == orderId)
            .Select(x => x.Status)
            .SingleAsync());
        Assert.Equal(0, await dbContext.Wallets
            .Where(x => x.UserId == userId)
            .Select(x => x.Balance)
            .SingleAsync());

        var refundLedger = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PurchaseRefund)
            .SingleAsync();
        Assert.Equal(-120, refundLedger.Delta);
        Assert.Equal(refundId, refundLedger.SourceTransactionId);
    }

    [Fact]
    public async Task RefundAdminPurchaseAsync_ShouldRejectPendingPurchase()
    {
        await using var dbContext = CreateDbContext();

        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = orderId,
            UserId = Guid.NewGuid(),
            PackId = packId,
            PaymentProvider = "stripe",
            Status = PurchaseOrderStatus.Pending,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "pi_pending",
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).RefundAdminPurchaseAsync(
            new AdminRefundPurchaseCommand(orderId, "not refundable"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal("economy.purchase_not_refundable", result.Error.Code);
    }

    [Fact]
    public async Task CreatePackPurchaseAsync_ShouldRejectStripe_WhenProviderConfigUnavailable()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "ios", "1.0.0", "US", "en-US"),
            CancellationToken.None);

        Assert.True(createResult.IsFailure);
        Assert.Equal(EconomyErrors.PaymentProviderUnavailable.Code, createResult.Error.Code);
    }

    [Fact]
    public async Task CreatePackPurchaseAsync_ShouldUseHostedStripeCheckoutOnMobile()
    {
        await using var dbContext = CreateDbContext();

        dbContext.PaymentProviderConfigurations.Add(new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            Platform = "ios",
            Region = "US",
            IsEnabled = true,
            IsRecommended = true,
            IsSelectedByDefault = true,
            RequiresExternalWarning = false,
            RequiresStoreDisclosure = false,
            AllowedFromAppVersion = "0.0.0",
            ExternalCheckoutAllowed = true,
            BonusTokensPercent = 0,
            Mode = "test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });

        var packId = AddStarterPack(dbContext);
        var gateway = new FakePaymentGateway();
        var service = CreateService(dbContext, gateway: gateway);

        var result = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(Guid.NewGuid(), packId, "USD", "stripe", "ios", "1.0.0", "US", "en-US"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Contains("checkout.stripe.com", result.Value.CheckoutUrl, StringComparison.Ordinal);
        Assert.Null(result.Value.PaymentIntentClientSecret);
        Assert.NotNull(gateway.LastPaymentCreateRequest);
        Assert.False(gateway.LastPaymentCreateRequest!.UsePaymentSheet);
    }

    [Fact]
    public async Task ListPremiumPlansAsync_ShouldReturnConfiguredPlans()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.ListPremiumPlansAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(2, result.Value.Count);
        Assert.DoesNotContain(result.Value, plan => plan.PlanCode == "weekly");
        Assert.Contains(result.Value, plan => plan.PlanCode == "yearly" && plan.IsPopular);
        Assert.All(result.Value, plan =>
        {
            Assert.False(string.IsNullOrWhiteSpace(plan.GooglePlayProductId));
            Assert.False(string.IsNullOrWhiteSpace(plan.AppStoreProductId));
        });
    }

    [Fact]
    public async Task CreatePremiumCheckoutAsync_ShouldCreateStripeCustomerAndCheckout()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var result = await service.CreatePremiumCheckoutAsync(
            new CreatePremiumCheckoutCommand(userId, "yearly", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("stripe", result.Value.PaymentProvider);
        Assert.Contains("checkout.stripe.com", result.Value.CheckoutUrl, StringComparison.Ordinal);

        var customer = await dbContext.PaymentCustomers.SingleAsync(x => x.UserId == userId);
        Assert.Equal("stripe", customer.Provider);
    }

    [Fact]
    public async Task CreatePremiumCheckoutAsync_ShouldUseHostedStripeCheckoutOnMobile()
    {
        await using var dbContext = CreateDbContext();

        dbContext.PaymentProviderConfigurations.Add(new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            Platform = "ios",
            Region = "US",
            IsEnabled = true,
            IsRecommended = true,
            IsSelectedByDefault = true,
            RequiresExternalWarning = false,
            RequiresStoreDisclosure = false,
            AllowedFromAppVersion = "0.0.0",
            ExternalCheckoutAllowed = true,
            BonusTokensPercent = 0,
            Mode = "test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var gateway = new FakePaymentGateway();
        var service = CreateService(dbContext, gateway: gateway);

        var result = await service.CreatePremiumCheckoutAsync(
            new CreatePremiumCheckoutCommand(Guid.NewGuid(), "yearly", "stripe", "ios", "1.0.0", "US", "en-US"),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? result.Error.Code : string.Empty);
        Assert.Contains("checkout.stripe.com", result.Value.CheckoutUrl, StringComparison.Ordinal);
        Assert.Null(result.Value.PaymentIntentClientSecret);
        Assert.NotNull(gateway.LastSubscriptionCheckoutRequest);
        Assert.False(gateway.LastSubscriptionCheckoutRequest!.UsePaymentSheet);
    }

    [Fact]
    public async Task CreatePremiumCheckoutAsync_ShouldUseDatabasePlanConfiguration_WhenAvailable()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Annual Pro",
            BillingPeriod = "yearly",
            PriceAmount = 129.99m,
            CurrencyCode = "EUR",
            MonthlyTokenLimit = 2400,
            IsRecommended = true,
            IsActive = true,
            AppleProductId = "com.petmagic.custom.yearly.apple",
            GoogleProductId = "com.petmagic.custom.yearly.google",
            DisplayOrder = 2,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var gateway = new FakePaymentGateway();
        var service = CreateService(dbContext, gateway: gateway);

        var result = await service.CreatePremiumCheckoutAsync(
            new CreatePremiumCheckoutCommand(Guid.NewGuid(), "yearly", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(gateway.LastSubscriptionCheckoutRequest);
        Assert.Equal("PetMagic Premium Annual Pro", gateway.LastSubscriptionCheckoutRequest!.ProductName);
        Assert.Equal(129.99m, gateway.LastSubscriptionCheckoutRequest.PriceAmount);
        Assert.Equal("EUR", gateway.LastSubscriptionCheckoutRequest.CurrencyCode);
        Assert.Equal("year", gateway.LastSubscriptionCheckoutRequest.BillingInterval);
    }

}
