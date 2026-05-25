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

public sealed class EconomyServiceTests
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

    [Fact]
    public async Task HandleStripeWebhook_ShouldBeIdempotent()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "creator",
            DisplayName = "Creator PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 9.99m,
            GrantedSpark = 200,
            BonusSpark = 50,
            IsActive = true,
            SortOrder = 2
        });

        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "web", "1.0.0", "*", "en"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var eventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{createResult.Value.ExternalPaymentId}\",\"object\":\"checkout.session\",\"metadata\":{{\"order_id\":\"{createResult.Value.OrderId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var first = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);
        var second = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.True(first.Value.Processed);
        Assert.False(second.Value.Processed);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(250, wallet.Balance);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldPersistSavedPaymentMethodFromSetupSession()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);

        var setupResult = await service.CreatePaymentMethodSetupAsync(
            new CreatePaymentMethodSetupCommand(userId, "stripe"),
            CancellationToken.None);

        Assert.True(setupResult.IsSuccess);

        var eventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var setupIntentId = $"seti_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{setupResult.Value.ExternalSetupId}\",\"object\":\"checkout.session\",\"setup_intent\":\"{setupIntentId}\",\"metadata\":{{\"purpose\":\"payment_method_setup\",\"user_id\":\"{userId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var webhookResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);
        var methods = await service.ListPaymentMethodsAsync(userId, CancellationToken.None);

        Assert.True(webhookResult.IsSuccess);
        Assert.True(methods.IsSuccess);
        var method = Assert.Single(methods.Value);
        Assert.Equal("visa", method.Brand);
        Assert.Equal("4242", method.Last4);
        Assert.True(method.IsDefault);
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldUseDatabasePlanAndGrantTokensOnlyOncePerPeriod()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "monthly",
            Name = "PetMagic Premium Monthly Plus",
            BillingPeriod = "monthly",
            PriceAmount = 19.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 777,
            IsRecommended = false,
            IsActive = true,
            AppleProductId = "com.petmagic.custom.monthly.apple",
            GoogleProductId = "com.petmagic.custom.monthly.google",
            DisplayOrder = 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc),
            Status = "active",
            IsActive = true,
        };
        var userId = Guid.NewGuid();
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var first = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                userId,
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "server-payload",
                null,
                "purchase-1",
                null),
            CancellationToken.None);

        var second = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                userId,
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "server-payload",
                null,
                "purchase-1",
                null),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId);
        var grantEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == "premium_subscription_grant")
            .ToListAsync();

        Assert.Equal(777, wallet.Balance);
        Assert.Equal("monthly", subscription.PlanId);
        Assert.Equal(777, subscription.MonthlyTokenLimit);
        Assert.Equal(777, subscription.MonthlyTokensGranted);
        Assert.Single(grantEntries);
        Assert.Equal(2, identityService.SetPremiumStatusCalls.Count);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldUseDatabasePlanConfiguration_ForSubscriptionGrant()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Ultra Yearly",
            BillingPeriod = "yearly",
            PriceAmount = 149.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 2222,
            IsRecommended = true,
            IsActive = true,
            AppleProductId = "com.petmagic.ultra.yearly.apple",
            GoogleProductId = "com.petmagic.ultra.yearly.google",
            DisplayOrder = 2,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var userId = Guid.NewGuid();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var periodStart = new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)).ToUnixTimeSeconds();
        var periodEnd = new DateTimeOffset(new DateTime(2027, 1, 1, 0, 0, 0, DateTimeKind.Utc)).ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"cs_sub_test\",\"object\":\"checkout.session\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"yearly\"}},\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsSuccess);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId);

        Assert.Equal(2222, wallet.Balance);
        Assert.Equal("yearly", subscription.PlanId);
        Assert.Equal(2222, subscription.MonthlyTokenLimit);
        Assert.Single(identityService.SetPremiumStatusCalls);
    }

    [Fact]
    public async Task HandleAppStoreServerNotificationAsync_ShouldUpdateExistingSubscription()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var expiresAtUtc = now.AddDays(20);

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "monthly",
            Name = "PetMagic Premium Monthly",
            BillingPeriod = "monthly",
            PriceAmount = 14.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 500,
            IsRecommended = false,
            IsActive = true,
            AppleProductId = "com.petmagic.custom.monthly.apple",
            GoogleProductId = "com.petmagic.custom.monthly.google",
            DisplayOrder = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "app_store",
            PurchaseChannel = "in_app",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            ExternalSubscriptionId = "orig-app-1",
            ExternalTransactionId = "txn-app-1",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws($"{{\"productId\":\"com.petmagic.custom.monthly.apple\",\"originalTransactionId\":\"orig-app-1\",\"transactionId\":\"txn-app-2\",\"expiresDate\":\"{new DateTimeOffset(expiresAtUtc).ToUnixTimeMilliseconds()}\"}}");
        var signedRenewalInfo = CreateUnsignedJws("{\"autoRenewStatus\":0}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-notification-1\",\"notificationType\":\"DID_CHANGE_RENEWAL_STATUS\",\"subtype\":\"AUTO_RENEW_DISABLED\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\",\"signedRenewalInfo\":\"{signedRenewalInfo}\"}}}}");

        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);

        var result = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "app_store");
        Assert.Equal("Canceled", subscription.Status);
        Assert.True(subscription.CancelAtPeriodEnd);
        Assert.Equal("txn-app-2", subscription.ExternalTransactionId);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldUpdateExistingSubscription()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var expiresAtUtc = now.AddDays(14);

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "monthly",
            Name = "PetMagic Premium Monthly",
            BillingPeriod = "monthly",
            PriceAmount = 14.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 500,
            IsRecommended = false,
            IsActive = true,
            AppleProductId = "com.petmagic.custom.monthly.apple",
            GoogleProductId = "com.petmagic.custom.monthly.google",
            DisplayOrder = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "google_play",
            PurchaseChannel = "in_app",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            ExternalSubscriptionId = "order-1",
            ExternalTransactionId = "gp-token-1",
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"subscriptionNotification\":{\"notificationType\":3,\"purchaseToken\":\"gp-token-1\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = expiresAtUtc,
            Status = "SUBSCRIPTION_STATE_ACTIVE",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-message-1"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        Assert.Equal("Canceled", subscription.Status);
        Assert.True(subscription.CancelAtPeriodEnd);
        Assert.Equal("gp-token-1", subscription.ExternalTransactionId);
        Assert.Equal("order-1", subscription.ExternalSubscriptionId);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task CreatePackPurchase_WithSavedPaymentMethod_ShouldChargeAndCreditWallet()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        var paymentMethodId = Guid.NewGuid();

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
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_test",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.SavedPaymentMethods.Add(new SavedPaymentMethod
        {
            Id = paymentMethodId,
            UserId = userId,
            Provider = "stripe",
            ExternalPaymentMethodId = "pm_card_visa",
            Brand = "visa",
            Last4 = "4242",
            ExpMonth = 12,
            ExpYear = 2030,
            IsDefault = true,
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var purchase = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "stripe", "web", "1.0.0", "*", "en", paymentMethodId),
            CancellationToken.None);

        Assert.True(purchase.IsSuccess);
        Assert.Equal("succeeded", purchase.Value.Status);
        Assert.Equal(paymentMethodId, (await dbContext.PurchaseOrders.SingleAsync()).SavedPaymentMethodId);

        var wallet = await dbContext.Wallets.FirstAsync(x => x.UserId == userId);
        Assert.Equal(120, wallet.Balance);
    }

    [Fact]
    public async Task CreatePaymentProviderConfigurationAsync_ShouldCreateNormalizedRoute()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.CreatePaymentProviderConfigurationAsync(
            new CreatePaymentProviderConfigurationCommand(
                "Stripe",
                "Android",
                "us",
                true,
                false,
                false,
                true,
                false,
                "1.2.3",
                false,
                5,
                "Stripe Alt Billing",
                null,
                null,
                null,
                "TEST",
                null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("stripe", result.Value.Provider);
        Assert.Equal("android", result.Value.Platform);
        Assert.Equal("US", result.Value.Region);
        Assert.Equal("test", result.Value.Mode);
    }

    [Fact]
    public async Task CreatePaymentProviderConfigurationAsync_ShouldFailOnDuplicateRoute()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.CreatePaymentProviderConfigurationAsync(
            new CreatePaymentProviderConfigurationCommand(
                "stripe",
                "web",
                "*",
                true,
                true,
                true,
                false,
                false,
                "0.0.0",
                true,
                0,
                null,
                null,
                null,
                null,
                "test",
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PaymentProviderConfigurationAlreadyExists.Code, result.Error.Code);
    }

    [Fact]
    public async Task ClonePaymentProviderConfigurationAsync_ShouldCopySourceWithNewRegion()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var source = await dbContext.PaymentProviderConfigurations.AsNoTracking().SingleAsync();

        var result = await service.ClonePaymentProviderConfigurationAsync(
            new ClonePaymentProviderConfigurationCommand(source.Id, "EU"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("EU", result.Value.Region);
        Assert.Equal(source.Provider, result.Value.Provider);
        Assert.Equal(source.Platform, result.Value.Platform);
    }

    [Fact]
    public async Task DeletePaymentProviderConfigurationAsync_ShouldRemoveConfiguration()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var source = await dbContext.PaymentProviderConfigurations.AsNoTracking().SingleAsync();

        var create = await service.CreatePaymentProviderConfigurationAsync(
            new CreatePaymentProviderConfigurationCommand(
                source.Provider,
                source.Platform,
                "US",
                source.IsEnabled,
                source.IsRecommended,
                source.IsSelectedByDefault,
                source.RequiresExternalWarning,
                source.RequiresStoreDisclosure,
                source.AllowedFromAppVersion,
                source.ExternalCheckoutAllowed,
                source.BonusTokensPercent,
                source.DisplayLabel,
                source.DisplaySubtitle,
                source.WarningTitle,
                source.WarningMessage,
                source.Mode,
                source.Notes),
            CancellationToken.None);

        Assert.True(create.IsSuccess);

        var delete = await service.DeletePaymentProviderConfigurationAsync(
            new DeletePaymentProviderConfigurationCommand(create.Value.ConfigurationId),
            CancellationToken.None);

        Assert.True(delete.IsSuccess);
        Assert.False(await dbContext.PaymentProviderConfigurations.AnyAsync(x => x.Id == create.Value.ConfigurationId));
    }

    [Fact]
    public async Task TestPaymentProviderConfigurationMatchAsync_ShouldReturnAllowedDecision()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.TestPaymentProviderConfigurationMatchAsync(
            new TestPaymentProviderConfigurationMatchQuery("stripe", "web", "US", "1.0.0"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.MatchFound);
        Assert.True(result.Value.AllowedForCheckout);
        Assert.Equal("allowed", result.Value.DecisionCode);
        Assert.NotNull(result.Value.MatchedConfiguration);
    }

    private static EconomyService CreateService(
        EconomyDbContext dbContext,
        FakePaymentGateway? gateway = null,
        FakeStoreSubscriptionVerifier? storeVerifier = null,
        IIdentityService? identityService = null)
    {
        var options = Options.Create(new EconomyOptions
        {
            WeeklyFreeSpark = 100,
            WeeklyPremiumSpark = 250,
            AdRewardSpark = 15,
            AdRewardDailyLimit = 5,
            ReferralBonusSpark = 15,
            StripeSecretKey = "test_stripe_secret_key",
            StripeWebhookSecret = "test_webhook_secret",
            StripeCheckoutSuccessUrl = "http://localhost:3000/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = "http://localhost:3000/payments/cancel"
        });

        return new EconomyService(
            dbContext,
            gateway ?? new FakePaymentGateway(),
            storeVerifier ?? new FakeStoreSubscriptionVerifier(),
            options,
            identityService);
    }

    private static EconomyDbContext CreateDbContext()
    {
        var dbOptions = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"economy-tests-{Guid.NewGuid():N}")
            .Options;

        var dbContext = new EconomyDbContext(dbOptions);
        dbContext.PaymentProviderConfigurations.Add(new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = "stripe",
            Platform = "web",
            Region = "*",
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
        dbContext.SaveChanges();

        return dbContext;
    }

    private static Guid AddStarterPack(EconomyDbContext dbContext)
    {
        var packId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = $"starter-{Guid.NewGuid():N}",
            DisplayName = "Starter PawSpark",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        dbContext.SaveChanges();
        return packId;
    }

    private static string BuildStripeSignature(string payload, string secret)
    {
        var timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString();
        var toSign = $"{timestamp}.{payload}";
        var signature = ComputeHmacSha256Hex(toSign, secret);
        return $"t={timestamp},v1={signature}";
    }

    private static string ComputeHmacSha256Hex(string payload, string secret)
    {
        var keyBytes = Encoding.UTF8.GetBytes(secret);
        var payloadBytes = Encoding.UTF8.GetBytes(payload);
        using var hmac = new HMACSHA256(keyBytes);
        return Convert.ToHexString(hmac.ComputeHash(payloadBytes)).ToLowerInvariant();
    }

    private static string CreateUnsignedJws(string json)
    {
        return $"{Base64UrlEncode("{\"alg\":\"none\",\"typ\":\"JWT\"}")}.{Base64UrlEncode(json)}.signature";
    }

    private static string Base64UrlEncode(string value)
    {
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private sealed class FakePaymentGateway : IPaymentGateway
    {
        public SubscriptionCheckoutCreateRequest? LastSubscriptionCheckoutRequest { get; private set; }

        public Task<Result<PaymentCreateResponse>> CreatePaymentAsync(PaymentCreateRequest request, CancellationToken cancellationToken)
        {
            var sessionId = $"cs_test_{request.OrderId:N}";
            var url = $"https://checkout.stripe.com/pay/{sessionId}";
            return Task.FromResult(Result.Success(new PaymentCreateResponse(sessionId, url)));
        }

        public Task<Result<SubscriptionCheckoutCreateResponse>> CreateSubscriptionCheckoutAsync(
            SubscriptionCheckoutCreateRequest request,
            CancellationToken cancellationToken)
        {
            LastSubscriptionCheckoutRequest = request;
            var sessionId = $"cs_sub_{request.UserId:N}_{request.PlanCode}";
            var url = $"https://checkout.stripe.com/pay/{sessionId}";
            return Task.FromResult(Result.Success(new SubscriptionCheckoutCreateResponse(sessionId, url)));
        }

        public Task<Result<PaymentCustomerCreateResponse>> CreateCustomerAsync(PaymentCustomerCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCustomerCreateResponse($"cus_{request.UserId:N}")));
        }

        public Task<Result<BillingPortalCreateResponse>> CreateBillingPortalSessionAsync(
            BillingPortalCreateRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new BillingPortalCreateResponse("https://billing.stripe.com/session/test")));
        }

        public Task<Result<PaymentMethodSetupCreateResponse>> CreatePaymentMethodSetupAsync(PaymentMethodSetupCreateRequest request, CancellationToken cancellationToken)
        {
            var sessionId = $"cs_setup_{request.UserId:N}";
            return Task.FromResult(Result.Success(new PaymentMethodSetupCreateResponse(sessionId, $"https://checkout.stripe.com/setup/{sessionId}")));
        }

        public Task<Result<PaymentMethodDetailsResponse>> ResolveSetupIntentPaymentMethodAsync(PaymentMethodResolveRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentMethodDetailsResponse($"pm_{request.ExternalSetupId}", "visa", "4242", 12, 2030)));
        }

        public Task<Result> DetachPaymentMethodAsync(PaymentMethodDetachRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success());
        }

        public Task<Result<PaymentCreateResponse>> CreatePaymentWithSavedMethodAsync(PaymentSavedMethodCreateRequest request, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new PaymentCreateResponse($"pi_{request.OrderId:N}", string.Empty)));
        }
    }

    private sealed class FakeStoreSubscriptionVerifier : IStoreSubscriptionVerifier
    {
        public bool IsActive { get; init; } = true;

        public DateTime ExpiresAtUtc { get; init; } = DateTime.UtcNow.AddDays(30);

        public string Status { get; init; } = "active";

        public Task<Result<StoreSubscriptionVerificationResponse>> VerifyAsync(
            StoreSubscriptionVerificationRequest request,
            CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new StoreSubscriptionVerificationResponse(IsActive, ExpiresAtUtc, Status, request.PurchaseId)));
        }
    }

    private sealed class FakeIdentityService : IIdentityService
    {
        private static readonly LegalAcceptanceStatusResponse DefaultLegalAcceptance = new(
            true,
            "2026-05-20",
            DateTime.UtcNow,
            true,
            "2026-05-20",
            DateTime.UtcNow,
            "2026-05-20",
            "2026-05-20",
            false);

        public List<SetPremiumStatusCommand> SetPremiumStatusCalls { get; } = [];

        public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken) => NotSupported<LegalDocumentsResponse>();
        public Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> GetLinkedAccountsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> LinkExternalLoginAsync(Guid userId, ExternalLoginCallbackCommand command, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<IReadOnlyList<LinkedAccountResponse>>> UnlinkExternalLoginAsync(Guid userId, string provider, CancellationToken cancellationToken) => NotSupported<IReadOnlyList<LinkedAccountResponse>>();
        public Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken) => NotSupported<TokenPairResponse>();
        public Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
        {
            return Task.FromResult(Result.Success(new UserProfileResponse(
                userId,
                "premium@petmagic.app",
                "Premium User",
                false,
                true,
                true,
                false,
                false,
                DefaultLegalAcceptance,
                ["user"],
                null)));
        }

        public Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken) => NotSupported<UserProfileResponse>();
        public Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken) => NotSupported<IReadOnlyList<UserListItemResponse>>();
        public Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserDetailResponse>();
        public Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken) => NotSupported<AdminUserAnalyticsResponse>();
        public Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken) => NotSupported<AdminUserWalletOperationResponse>();
        public Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken) => NotSupported();
        public Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken) => NotSupported();

        public Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
        {
            SetPremiumStatusCalls.Add(command);
            return Task.FromResult(Result.Success());
        }

        public Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken) => NotSupported();

        private static Task<Result> NotSupported() => Task.FromException<Result>(new NotSupportedException());
        private static Task<Result<T>> NotSupported<T>() => Task.FromException<Result<T>>(new NotSupportedException());
    }
}
