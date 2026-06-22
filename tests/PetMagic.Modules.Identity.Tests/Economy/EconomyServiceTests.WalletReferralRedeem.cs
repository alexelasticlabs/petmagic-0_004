using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;

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
    public async Task ConfirmPackPurchase_ShouldCreditWalletOnce()
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

        var confirmResult = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(userId, createResult.Value.OrderId),
            CancellationToken.None);

        Assert.True(confirmResult.IsSuccess);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(120, wallet.Balance);

        var secondConfirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(userId, createResult.Value.OrderId),
            CancellationToken.None);

        Assert.True(secondConfirm.IsFailure);
        Assert.Equal(EconomyErrors.PurchaseAlreadyProcessed.Code, secondConfirm.Error.Code);

        var walletAfterSecond = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(120, walletAfterSecond.Balance);
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

        var purchase = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(refereeId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);
        Assert.True(purchase.IsSuccess);

        var confirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(refereeId, purchase.Value.OrderId),
            CancellationToken.None);
        Assert.True(confirm.IsSuccess);

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
    public async Task ConfirmPackPurchaseAsync_ShouldSettlePendingReferralBonusOnce()
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

        var purchase = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(refereeId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);
        Assert.True(purchase.IsSuccess);

        var firstConfirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(refereeId, purchase.Value.OrderId),
            CancellationToken.None);
        var secondConfirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(refereeId, purchase.Value.OrderId),
            CancellationToken.None);

        Assert.True(firstConfirm.IsSuccess);
        Assert.True(secondConfirm.IsFailure);

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
    public async Task RefundAdminPurchaseAsync_ShouldMarkSucceededStripePurchaseAsRefunded()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        var orderId = Guid.NewGuid();
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
            ConfirmedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).RefundAdminPurchaseAsync(
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
        var purchase = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        Assert.True(purchase.IsSuccess);

        var confirm = await service.ConfirmPackPurchaseAsync(
            new ConfirmPackPurchaseCommand(userId, purchase.Value.OrderId),
            CancellationToken.None);

        Assert.True(confirm.IsSuccess);

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
}
