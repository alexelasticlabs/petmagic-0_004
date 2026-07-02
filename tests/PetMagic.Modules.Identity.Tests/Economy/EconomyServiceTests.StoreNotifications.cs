using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
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
        Assert.Null(subscription.ExternalCustomerId);
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
    public async Task HandleAppStoreServerNotificationAsync_ShouldIgnoreDuplicateDelivery()
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
            ExternalSubscriptionId = "orig-app-duplicate-1",
            ExternalTransactionId = "txn-app-duplicate-1",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws($"{{\"productId\":\"com.petmagic.custom.monthly.apple\",\"originalTransactionId\":\"orig-app-duplicate-1\",\"transactionId\":\"txn-app-duplicate-2\",\"expiresDate\":\"{new DateTimeOffset(expiresAtUtc).ToUnixTimeMilliseconds()}\"}}");
        var signedRenewalInfo = CreateUnsignedJws("{\"autoRenewStatus\":0}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-duplicate-notification-1\",\"notificationType\":\"DID_CHANGE_RENEWAL_STATUS\",\"subtype\":\"AUTO_RENEW_DISABLED\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\",\"signedRenewalInfo\":\"{signedRenewalInfo}\"}}}}");

        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);

        var firstResult = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);
        var secondResult = await service.HandleAppStoreServerNotificationAsync(
            new AppStoreServerNotificationCommand(signedPayload),
            CancellationToken.None);

        Assert.True(firstResult.IsSuccess);
        Assert.True(secondResult.IsSuccess);
        Assert.True(firstResult.Value.Processed);
        Assert.False(secondResult.Value.Processed);
        Assert.Equal("ignored_duplicate", secondResult.Value.Status);
        Assert.Single(identityService.SetPremiumStatusCalls);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "app_store");
        Assert.Equal(40, wallet.Balance);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Equal("txn-app-duplicate-2", subscription.ExternalTransactionId);
        Assert.Single(await dbContext.ProcessedWebhookEvents.Where(x => x.Provider == "app_store" && x.EventId == "app-duplicate-notification-1").ToListAsync());
        Assert.Single(await dbContext.SubscriptionEventLogs.Where(x => x.Provider == "app_store").ToListAsync());
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
        Assert.Null(subscription.ExternalCustomerId);
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
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldNotExposePurchaseToken_WhenMessageIdIsMissing()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var expiresAtUtc = now.AddDays(14);
        const string purchaseToken = "gp-token-without-message-id-1";

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
            ExternalSubscriptionId = "order-without-message-id-1",
            ExternalTransactionId = purchaseToken,
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = $"{{\"subscriptionNotification\":{{\"notificationType\":3,\"purchaseToken\":\"{purchaseToken}\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}}}";
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
            new GooglePlayDeveloperNotificationCommand(messageData, null),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.StartsWith("googleplay:sub:3:", result.Value.EventId, StringComparison.Ordinal);
        Assert.DoesNotContain(purchaseToken, result.Value.EventId, StringComparison.Ordinal);

        var processedEvent = await dbContext.ProcessedWebhookEvents.SingleAsync(x => x.Provider == "google_play");
        Assert.Equal(result.Value.EventId, processedEvent.EventId);
        Assert.DoesNotContain(purchaseToken, processedEvent.EventId, StringComparison.Ordinal);

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.Provider == "google_play");
        Assert.DoesNotContain(purchaseToken, eventLog.ExternalEventId, StringComparison.Ordinal);
        Assert.DoesNotContain(purchaseToken, eventLog.PayloadJson, StringComparison.Ordinal);
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldIgnoreDuplicateDelivery()
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
            ExternalSubscriptionId = "order-duplicate-1",
            ExternalTransactionId = "gp-duplicate-token-1",
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = expiresAtUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"subscriptionNotification\":{\"notificationType\":3,\"purchaseToken\":\"gp-duplicate-token-1\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = expiresAtUtc,
            Status = "SUBSCRIPTION_STATE_ACTIVE",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var firstResult = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-duplicate-message-1"),
            CancellationToken.None);
        var secondResult = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-duplicate-message-1"),
            CancellationToken.None);

        Assert.True(firstResult.IsSuccess);
        Assert.True(secondResult.IsSuccess);
        Assert.True(firstResult.Value.Processed);
        Assert.False(secondResult.Value.Processed);
        Assert.Equal("ignored_duplicate", secondResult.Value.Status);
        Assert.Single(identityService.SetPremiumStatusCalls);

        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        Assert.Equal(40, wallet.Balance);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Equal("gp-duplicate-token-1", subscription.ExternalTransactionId);
        Assert.Single(await dbContext.ProcessedWebhookEvents.Where(x => x.Provider == "google_play" && x.EventId == "google-duplicate-message-1").ToListAsync());
        Assert.Single(await dbContext.SubscriptionEventLogs.Where(x => x.Provider == "google_play").ToListAsync());
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
    public async Task HandleAppStoreServerNotificationAsync_ShouldExpireWhenActiveNotificationOmitsExpiry()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var existingExpiryUtc = now.AddDays(20);

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
            ExternalSubscriptionId = "orig-app-missing-expiry-1",
            ExternalTransactionId = "txn-app-missing-expiry-1",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = existingExpiryUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var signedTransactionInfo = CreateUnsignedJws("{\"productId\":\"com.petmagic.custom.monthly.apple\",\"originalTransactionId\":\"orig-app-missing-expiry-1\",\"transactionId\":\"txn-app-missing-expiry-2\"}");
        var signedPayload = CreateUnsignedJws($"{{\"notificationUUID\":\"app-missing-expiry-notification-1\",\"notificationType\":\"DID_RENEW\",\"data\":{{\"signedTransactionInfo\":\"{signedTransactionInfo}\"}}}}");

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
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task HandleGooglePlayDeveloperNotificationAsync_ShouldExpireWhenVerifierOmitsExpiry()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var existingExpiryUtc = now.AddDays(14);

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
            ExternalSubscriptionId = "order-missing-expiry-1",
            ExternalTransactionId = "gp-missing-expiry-token-1",
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = existingExpiryUtc,
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 500,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var messageJson = "{\"subscriptionNotification\":{\"notificationType\":2,\"purchaseToken\":\"gp-missing-expiry-token-1\",\"subscriptionId\":\"com.petmagic.custom.monthly.google\"}}";
        var messageData = Convert.ToBase64String(Encoding.UTF8.GetBytes(messageJson));

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = null,
            Status = "SUBSCRIPTION_STATE_ACTIVE",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.HandleGooglePlayDeveloperNotificationAsync(
            new GooglePlayDeveloperNotificationCommand(messageData, "google-missing-expiry-message-1"),
            CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "google_play");
        Assert.Equal("Expired", subscription.Status);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());
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


}

