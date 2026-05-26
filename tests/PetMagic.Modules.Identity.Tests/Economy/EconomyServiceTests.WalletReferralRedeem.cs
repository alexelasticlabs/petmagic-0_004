using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{

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
