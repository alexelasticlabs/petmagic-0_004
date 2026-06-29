using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
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
    public void StripeCheckoutSessionVerification_ShouldRequireCurrentOrderIdentityAmountAndCurrency()
    {
        var order = CreatePendingStripeOrder(priceAmount: 9.99m, currencyCode: "USD");
        var validSession = new Stripe.Checkout.Session
        {
            ClientReferenceId = order.Id.ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            AmountTotal = 999,
            Currency = "usd",
        };

        var wrongOrderSession = new Stripe.Checkout.Session
        {
            ClientReferenceId = Guid.NewGuid().ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = Guid.NewGuid().ToString("D") },
            AmountTotal = 999,
            Currency = "usd",
        };

        var wrongAmountSession = new Stripe.Checkout.Session
        {
            ClientReferenceId = order.Id.ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            AmountTotal = 100,
            Currency = "usd",
        };

        var wrongCurrencySession = new Stripe.Checkout.Session
        {
            ClientReferenceId = order.Id.ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            AmountTotal = 999,
            Currency = "eur",
        };

        Assert.True(EconomyService.IsStripeCheckoutSessionForOrder(validSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongOrderSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongAmountSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongCurrencySession, order));
    }

    [Fact]
    public void StripePaymentIntentVerification_ShouldRequireCurrentOrderIdentityAmountAndCurrency()
    {
        var order = CreatePendingStripeOrder(priceAmount: 4.99m, currencyCode: "USD");
        var validPaymentIntent = new Stripe.PaymentIntent
        {
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            Amount = 499,
            Currency = "usd",
        };

        var wrongOrderPaymentIntent = new Stripe.PaymentIntent
        {
            Metadata = new Dictionary<string, string> { ["order_id"] = Guid.NewGuid().ToString("D") },
            Amount = 499,
            Currency = "usd",
        };

        var wrongAmountPaymentIntent = new Stripe.PaymentIntent
        {
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            Amount = 999,
            Currency = "usd",
        };

        var wrongCurrencyPaymentIntent = new Stripe.PaymentIntent
        {
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            Amount = 499,
            Currency = "eur",
        };

        Assert.True(EconomyService.IsStripePaymentIntentForOrder(validPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongOrderPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongAmountPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongCurrencyPaymentIntent, order));
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldActivateAfterBackendValidation()
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

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        var grantEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId)
            .ToListAsync();
        var hasWallet = await dbContext.Wallets.AnyAsync(x => x.UserId == userId);

        Assert.True(first.Value.IsActive);
        Assert.Equal("Active", first.Value.Status);
        Assert.True(second.Value.IsActive);
        Assert.Equal("Active", second.Value.Status);
        Assert.True(hasWallet);
        Assert.Equal("monthly", subscription.PlanId);
        Assert.Equal(777, subscription.MonthlyTokenLimit);
        Assert.Equal("Active", subscription.Status);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Single(grantEntries);
        Assert.Equal(2, identityService.SetPremiumStatusCalls.Count);
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldRejectSubscriptionOwnedByAnotherUser()
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
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var first = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                Guid.NewGuid(),
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "gp-premium-token-owned-by-first-user",
                null,
                "gp-premium-order-owned-by-first-user",
                null),
            CancellationToken.None);

        var second = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                Guid.NewGuid(),
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "gp-premium-token-owned-by-first-user",
                null,
                "gp-premium-order-owned-by-first-user",
                null),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, second.Error.Code);
        Assert.Single(await dbContext.UserSubscriptions.ToListAsync());
        Assert.Single(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task ValidateGooglePlayBillingAsync_ShouldGrantTokenPackOnce()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack100",
            DisplayName = "Pack 100",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var first = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                userId,
                "gp-token-pack-1",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        var second = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                userId,
                "gp-token-pack-1",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal("TokenPack", first.Value.ProductType);
        Assert.True(first.Value.TokensGranted);
        Assert.False(second.Value.TokensGranted);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        var ledgerEntries = await dbContext.WalletLedgerEntries.Where(x => x.UserId == userId).ToListAsync();
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);

        Assert.Equal("succeeded", order.Status);
        Assert.Equal("gp-token-pack-1", order.ExternalPaymentId);
        Assert.Equal(120, wallet.Balance);
        Assert.Single(ledgerEntries);
        Assert.Equal(120, ledgerEntries[0].Delta);
    }

    [Fact]
    public async Task ListPacksAsync_ShouldBuildStoreProductIdsFromCanonicalPackCode()
    {
        await using var dbContext = CreateDbContext();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack100",
            DisplayName = "Pack 100",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var result = await service.ListPacksAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);

        var pack = Assert.Single(result.Value, x => x.Code == "pack100");
        Assert.Equal("com.petmagic.app.tokens.google.pack100", pack.GooglePlayProductId);
        Assert.Equal("com.petmagic.app.tokens.apple.pack100", pack.AppStoreProductId);
    }

    [Fact]
    public async Task StoreTokenPackResponses_ShouldNotExposePurchaseTokenOrTransactionId()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack100",
            DisplayName = "Pack 100",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var validation = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                userId,
                "gp-sensitive-purchase-token-1",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        Assert.True(validation.IsSuccess);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);
        Assert.Equal("gp-sensitive-purchase-token-1", order.ExternalPaymentId);
        Assert.Equal("gp-sensitive-purchase-token-1", ledgerEntry.SourceTransactionId);

        var purchaseResponse = await service.GetPurchaseAsync(userId, order.Id, CancellationToken.None);
        var purchaseHistory = await service.GetPurchaseHistoryAsync(userId, 0, 10, CancellationToken.None);
        var userLedger = await service.GetWalletLedgerAsync(userId, 0, 10, CancellationToken.None);
        var adminLedger = await service.GetAdminWalletLedgerAsync(0, 10, null, userId, CancellationToken.None);

        Assert.True(purchaseResponse.IsSuccess);
        Assert.Null(purchaseResponse.Value.ExternalPaymentId);
        Assert.True(purchaseHistory.IsSuccess);
        Assert.Single(purchaseHistory.Value.Items);
        Assert.Null(purchaseHistory.Value.Items[0].ExternalPaymentId);
        Assert.True(userLedger.IsSuccess);
        Assert.Single(userLedger.Value.Items);
        Assert.Null(userLedger.Value.Items[0].SourceTransactionId);
        Assert.True(adminLedger.IsSuccess);
        Assert.Single(adminLedger.Value.Items);
        Assert.Null(adminLedger.Value.Items[0].SourceTransactionId);
    }

    [Fact]
    public async Task ValidateGooglePlayBillingAsync_ShouldRejectWrongPackageName()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var result = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                Guid.NewGuid(),
                "gp-token-pack-1",
                "com.petmagic.app.tokens.google.pack100",
                "com.attacker.app"),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayBillingAsync_ShouldRejectTokenPackOwnedByAnotherUser()
    {
        await using var dbContext = CreateDbContext();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack100",
            DisplayName = "Pack 100",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var firstUserId = Guid.NewGuid();
        var first = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                firstUserId,
                "gp-token-owned-by-first-user",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        var second = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                Guid.NewGuid(),
                "gp-token-owned-by-first-user",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, second.Error.Code);
        Assert.Single(await dbContext.PurchaseOrders.ToListAsync());
        Assert.Single(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task ValidateAppleAppStoreBillingAsync_ShouldGrantTokenPackOnce()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack200",
            DisplayName = "Pack 200",
            CurrencyCode = "USD",
            PriceAmount = 6.99m,
            GrantedSpark = 180,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 2
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var signedTransactionInfo = BuildAppStoreSignedTransactionInfo(
            productId: "com.petmagic.app.tokens.apple.pack200",
            transactionId: "apple-txn-pack-1");

        var first = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(userId, signedTransactionInfo),
            CancellationToken.None);
        var second = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(userId, signedTransactionInfo),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal("TokenPack", first.Value.ProductType);
        Assert.True(first.Value.TokensGranted);
        Assert.False(second.Value.TokensGranted);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        var ledgerEntries = await dbContext.WalletLedgerEntries.Where(x => x.UserId == userId).ToListAsync();

        Assert.Equal("succeeded", order.Status);
        Assert.Equal("apple-txn-pack-1", order.ExternalPaymentId);
        Assert.Single(ledgerEntries);
        Assert.Equal("app_store", ledgerEntries[0].SourceProvider);
        Assert.Equal("apple-txn-pack-1", ledgerEntries[0].SourceTransactionId);
    }

    [Fact]
    public async Task ValidateAppleAppStoreBillingAsync_ShouldRejectRevokedTransaction()
    {
        await using var dbContext = CreateDbContext();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = Guid.NewGuid(),
            Code = "pack200",
            DisplayName = "Pack 200",
            CurrencyCode = "USD",
            PriceAmount = 6.99m,
            GrantedSpark = 180,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 2
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);
        var signedTransactionInfo = BuildAppStoreSignedTransactionInfo(
            productId: "com.petmagic.app.tokens.apple.pack200",
            transactionId: "apple-txn-revoked-1",
            revokedAtUtc: DateTime.UtcNow);

        var result = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(Guid.NewGuid(), signedTransactionInfo),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, result.Error.Code);
        Assert.Empty(await dbContext.PurchaseOrders.ToListAsync());
        Assert.Empty(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task ValidateAppleAppStoreBillingAsync_ShouldRejectWrongBundleId()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var signedTransactionInfo = BuildAppStoreSignedTransactionInfo(
            productId: "com.petmagic.app.tokens.apple.pack200",
            transactionId: "apple-txn-wrong-bundle-1",
            bundleId: "com.attacker.app");

        var result = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(Guid.NewGuid(), signedTransactionInfo),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateAppleAppStoreBillingAsync_ShouldRejectInvalidSignedTransactionInfo()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(
            dbContext,
            storeWebhookSecurityValidator: new FakeStoreWebhookSecurityValidator(Result.Failure(EconomyErrors.InvalidStoreWebhookSignature)));

        var signedTransactionInfo = BuildAppStoreSignedTransactionInfo(
            productId: "com.petmagic.app.tokens.apple.pack200",
            transactionId: "apple-txn-invalid-signature-1");

        var result = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(Guid.NewGuid(), signedTransactionInfo),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
        Assert.Empty(await dbContext.PurchaseOrders.ToListAsync());
        Assert.Empty(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task ValidateAppleAppStoreBillingAsync_ShouldRejectWrongEnvironment()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);
        var signedTransactionInfo = BuildAppStoreSignedTransactionInfo(
            productId: "com.petmagic.app.tokens.apple.pack200",
            transactionId: "apple-txn-wrong-environment-1",
            environment: "sandbox");

        var result = await service.ValidateAppleAppStoreBillingAsync(
            new ValidateAppleAppStoreBillingCommand(Guid.NewGuid(), signedTransactionInfo),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, result.Error.Code);
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

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId);

        Assert.Equal(40, wallet.Balance);
        Assert.Equal("yearly", subscription.PlanId);
        Assert.Equal(2222, subscription.MonthlyTokenLimit);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Single(identityService.SetPremiumStatusCalls);
    }

    [Fact]
    public async Task GetAdminSubscriptionsAsync_ShouldFilterByProviderStatusAndSearch()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.SubscriptionPlans.AddRange(
            new SubscriptionPlan
            {
                Id = "monthly",
                Name = "PetMagic Premium Monthly",
                BillingPeriod = "monthly",
                PriceAmount = 14.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 500,
                IsRecommended = true,
                IsActive = true,
                DisplayOrder = 1,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
            },
            new SubscriptionPlan
            {
                Id = "yearly",
                Name = "PetMagic Premium Yearly",
                BillingPeriod = "yearly",
                PriceAmount = 99.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 700,
                IsRecommended = false,
                IsActive = true,
                DisplayOrder = 2,
                CreatedAtUtc = now,
                UpdatedAtUtc = now,
            });
        dbContext.UserSubscriptions.AddRange(
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "monthly",
                Status = "Active",
                ExternalSubscriptionId = "sub_secret_should_not_be_searched",
                CurrentPeriodStartUtc = now.AddDays(-3),
                CurrentPeriodEndUtc = now.AddDays(27),
                MonthlyTokenLimit = 500,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-3),
                UpdatedAtUtc = now,
            },
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                Provider = "google_play",
                PurchaseChannel = "in_app",
                Region = "US",
                PlanId = "yearly",
                Status = "Active",
                CurrentPeriodStartUtc = now.AddDays(-7),
                CurrentPeriodEndUtc = now.AddDays(358),
                MonthlyTokenLimit = 700,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-7),
                UpdatedAtUtc = now.AddMinutes(-1),
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminSubscriptionsAsync(
            0,
            10,
            "active",
            "stripe",
            "monthly",
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(userId, item.UserId);
        Assert.Equal("stripe", item.Provider);
        Assert.Equal("monthly", item.PlanId);
        Assert.Equal("PetMagic Premium Monthly", item.PlanName);
    }

    [Fact]
    public async Task GetAdminSubscriptionEventsAsync_ShouldFilterCanonicalStatusesFromAdminQuery()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var subscriptionId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.SubscriptionEventLogs.AddRange(
            new SubscriptionEventLog
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                UserSubscriptionId = subscriptionId,
                Provider = "stripe",
                EventType = "customer.subscription.updated",
                Status = "Active",
                ExternalEventId = "evt_active",
                ExternalSubscriptionId = "sub_active",
                CreatedAtUtc = now,
                ProcessedAtUtc = now,
            },
            new SubscriptionEventLog
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                UserSubscriptionId = Guid.NewGuid(),
                Provider = "stripe",
                EventType = "customer.subscription.deleted",
                Status = "Expired",
                ExternalEventId = "evt_expired",
                ExternalSubscriptionId = "sub_expired",
                CreatedAtUtc = now.AddMinutes(-1),
                ProcessedAtUtc = now.AddMinutes(-1),
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetAdminSubscriptionEventsAsync(
            0,
            10,
            "stripe",
            "active",
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.Equal(userId, item.UserId);
        Assert.Equal(subscriptionId, item.UserSubscriptionId);
        Assert.Equal("Active", item.Status);
        Assert.Equal("evt_active", item.ExternalEventId);
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

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "app_store");
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        Assert.Equal("Canceled", subscription.Status);
        Assert.True(subscription.CancelAtPeriodEnd);
        Assert.Equal("txn-app-2", subscription.ExternalTransactionId);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Equal(40, wallet.Balance);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.Provider == "app_store");
        Assert.NotNull(eventLog.PayloadJson);
        Assert.Contains("DID_CHANGE_RENEWAL_STATUS", eventLog.PayloadJson);
        Assert.Contains("com.petmagic.custom.monthly.apple", eventLog.PayloadJson);
        Assert.DoesNotContain(signedPayload, eventLog.PayloadJson);
        Assert.DoesNotContain(signedTransactionInfo, eventLog.PayloadJson);
        Assert.DoesNotContain("signedTransactionInfo", eventLog.PayloadJson);
        Assert.DoesNotContain("txn-app-2", eventLog.PayloadJson);
    }

    [Fact]
    public async Task HandleAppStoreServerNotificationAsync_ShouldExpireSubscriptionOnRefund()
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
            ExternalSubscriptionId = "orig-app-refund-1",
            ExternalTransactionId = "txn-app-refund-1",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws($"{{\"productId\":\"com.petmagic.custom.monthly.apple\",\"originalTransactionId\":\"orig-app-refund-1\",\"transactionId\":\"txn-app-refund-2\",\"expiresDate\":\"{new DateTimeOffset(expiresAtUtc).ToUnixTimeMilliseconds()}\"}}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-refund-notification-1\",\"notificationType\":\"REFUND\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\"}}}}");

        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);

        var result = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "app_store");
        Assert.Equal("Expired", subscription.Status);
        Assert.NotNull(subscription.ExpiredAtUtc);
        Assert.Equal("txn-app-refund-2", subscription.ExternalTransactionId);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task HandleAppStoreServerNotificationAsync_ShouldExpireSubscriptionOnRevoke()
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
            ExternalSubscriptionId = "orig-app-revoke-1",
            ExternalTransactionId = "txn-app-revoke-1",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws($"{{\"productId\":\"com.petmagic.custom.monthly.apple\",\"originalTransactionId\":\"orig-app-revoke-1\",\"transactionId\":\"txn-app-revoke-2\",\"expiresDate\":\"{new DateTimeOffset(expiresAtUtc).ToUnixTimeMilliseconds()}\"}}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-revoke-notification-1\",\"notificationType\":\"REVOKE\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\"}}}}");

        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);

        var result = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "app_store");
        Assert.Equal("Expired", subscription.Status);
        Assert.NotNull(subscription.ExpiredAtUtc);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
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

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        Assert.Equal("Canceled", subscription.Status);
        Assert.True(subscription.CancelAtPeriodEnd);
        Assert.Equal("gp-token-1", subscription.ExternalTransactionId);
        Assert.Equal("order-1", subscription.ExternalSubscriptionId);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Equal(40, wallet.Balance);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.Provider == "google_play");
        Assert.NotNull(eventLog.PayloadJson);
        Assert.Contains("\"NotificationType\":3", eventLog.PayloadJson);
        Assert.Contains("com.petmagic.custom.monthly.google", eventLog.PayloadJson);
        Assert.DoesNotContain(messageData, eventLog.PayloadJson);
        Assert.DoesNotContain("purchaseToken", eventLog.PayloadJson);
        Assert.DoesNotContain("gp-token-1", eventLog.PayloadJson);
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldRenewExistingSubscription()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var previousExpiryUtc = now.AddDays(1);
        var renewedExpiryUtc = now.AddDays(31);

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
            ExternalSubscriptionId = "order-renewal-1",
            ExternalTransactionId = "gp-renewal-token-1",
            CurrentPeriodStartUtc = now.AddDays(-29),
            CurrentPeriodEndUtc = previousExpiryUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"subscriptionNotification\":{\"notificationType\":2,\"purchaseToken\":\"gp-renewal-token-1\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = renewedExpiryUtc,
            Status = "SUBSCRIPTION_STATE_ACTIVE",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-renewal-message-1"),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        Assert.Equal("Active", subscription.Status);
        Assert.False(subscription.CancelAtPeriodEnd);
        Assert.Equal(renewedExpiryUtc, subscription.CurrentPeriodEndUtc);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldExpireExistingSubscription()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var expiredAtUtc = now.AddDays(-1);

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
            ExternalSubscriptionId = "order-expired-1",
            ExternalTransactionId = "gp-expired-token-1",
            CurrentPeriodStartUtc = now.AddDays(-31),
            CurrentPeriodEndUtc = expiredAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"subscriptionNotification\":{\"notificationType\":13,\"purchaseToken\":\"gp-expired-token-1\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = expiredAtUtc,
            Status = "SUBSCRIPTION_STATE_EXPIRED",
            IsActive = false,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-expired-message-1"),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        Assert.Equal("Expired", subscription.Status);
        Assert.NotNull(subscription.ExpiredAtUtc);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldSettleOneTimeProductOrder()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "pack100",
            DisplayName = "Pack 100",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 1
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PackId = packId,
            PaymentProvider = "google_play",
            Status = "Pending",
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "gp-one-time-token-1",
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"oneTimeProductNotification\":{\"notificationType\":1,\"purchaseToken\":\"gp-one-time-token-1\",\"sku\":\"com.petmagic.app.tokens.google.pack100\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var service = CreateService(dbContext);
        var result = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-one-time-message-1"),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.False(result.Value.Processed);
        Assert.Equal("ignored_not_found", result.Value.Status);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        Assert.Equal("Pending", order.Status);

        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task HandleAppStoreServerNotificationAsync_ShouldSettleOneTimeProductOrder()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "pack200",
            DisplayName = "Pack 200",
            CurrencyCode = "USD",
            PriceAmount = 6.99m,
            GrantedSpark = 180,
            BonusSpark = 20,
            IsActive = true,
            SortOrder = 2
        });
        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PackId = packId,
            PaymentProvider = "app_store",
            Status = "Pending",
            PriceAmount = 6.99m,
            CurrencyCode = "USD",
            SparkToGrant = 200,
            ExternalPaymentId = "txn-app-one-time-1",
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws("{\"productId\":\"com.petmagic.app.tokens.apple.pack200\",\"originalTransactionId\":\"orig-app-one-time\",\"transactionId\":\"txn-app-one-time-1\"}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-one-time-notification-1\",\"notificationType\":\"ONE_TIME_CHARGE\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\"}}}}");

        var service = CreateService(dbContext);
        var result = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.Processed);
        Assert.Equal("ignored_not_found", result.Value.Status);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        Assert.Equal("Pending", order.Status);

        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());
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
    public async Task CreatePaymentProviderConfigurationAsync_ShouldFail_WhenLegacyStripeDisclosureTextProvided()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var create = await service.CreatePaymentProviderConfigurationAsync(
            new CreatePaymentProviderConfigurationCommand(
                "stripe",
                "ios",
                "*",
                true,
                true,
                true,
                true,
                true,
                "0.0.0",
                true,
                10,
                "Stripe Alt Billing",
                null,
                null,
                "Continue to Stripe checkout to finish payment.",
                "test",
                "This route uses external checkout." ),
            CancellationToken.None);

        Assert.True(create.IsFailure);
        Assert.Equal(EconomyErrors.PaymentProviderDisclosureInvalid.Code, create.Error.Code);
        Assert.Equal(1, await dbContext.PaymentProviderConfigurations.CountAsync());
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
}
