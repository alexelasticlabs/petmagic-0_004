using System.Text;

using Microsoft.EntityFrameworkCore;

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
}
