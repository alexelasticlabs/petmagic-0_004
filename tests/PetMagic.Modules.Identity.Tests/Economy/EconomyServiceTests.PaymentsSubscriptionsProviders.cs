using System.Text;

using System.Reflection;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task GetPaywallConfigAsync_ShouldLocalizeLegalTextsAndFallbackToEnglish()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var russian = await service.GetPaywallConfigAsync(
            new GetPaywallConfigQuery("android", "1.0.0", "RU", "ru-RU"),
            CancellationToken.None);
        var unsupported = await service.GetPaywallConfigAsync(
            new GetPaywallConfigQuery("android", "1.0.0", "US", "uk-UA"),
            CancellationToken.None);

        Assert.True(russian.IsSuccess);
        Assert.True(unsupported.IsSuccess);
        Assert.StartsWith("Оплата подписок", russian.Value.LegalTexts.StoreNotice);
        Assert.StartsWith("Payments for in-app subscriptions", unsupported.Value.LegalTexts.StoreNotice);
    }

    [Fact]
    public void VerifyStripeSignatureFallback_ShouldAcceptFreshTimestamp()
    {
        const string payload = "{\"id\":\"evt_test\",\"object\":\"event\"}";
        const string secret = "test_webhook_secret";

        var signature = BuildStripeSignature(payload, secret);

        Assert.True(EconomyWebhookParser.VerifyStripeSignatureFallback(payload, signature, secret));
    }

    [Fact]
    public void VerifyStripeSignatureFallback_ShouldRejectStaleTimestamp()
    {
        const string payload = "{\"id\":\"evt_test\",\"object\":\"event\"}";
        const string secret = "test_webhook_secret";
        var staleTimestamp = DateTimeOffset.UtcNow.AddMinutes(-10).ToUnixTimeSeconds().ToString();
        var staleSignature = $"t={staleTimestamp},v1={ComputeHmacSha256Hex($"{staleTimestamp}.{payload}", secret)}";

        Assert.False(EconomyWebhookParser.VerifyStripeSignatureFallback(payload, staleSignature, secret));
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
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{createResult.Value.ExternalPaymentId}\",\"object\":\"checkout.session\",\"status\":\"complete\",\"payment_status\":\"paid\",\"metadata\":{{\"order_id\":\"{createResult.Value.OrderId:D}\"}}}}}}}}";
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
        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);

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
        Assert.Empty(identityService.SetPremiumStatusCalls);
    }

    [Fact]
    public async Task GetPurchaseAsync_ShouldNotExposeStripeExternalPaymentId()
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
        Assert.False(string.IsNullOrWhiteSpace(createResult.Value.ExternalPaymentId));

        var purchase = await service.GetPurchaseAsync(userId, createResult.Value.OrderId, CancellationToken.None);

        Assert.True(purchase.IsSuccess);
        Assert.Null(purchase.Value.ExternalPaymentId);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldRejectPaymentMethodRebindingAcrossUsers()
    {
        await using var dbContext = CreateDbContext();

        var existingUserId = Guid.NewGuid();
        var newUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.SavedPaymentMethods.Add(new SavedPaymentMethod
        {
            Id = Guid.NewGuid(),
            UserId = existingUserId,
            Provider = "stripe",
            ExternalPaymentMethodId = "pm_shared_setup_intent",
            Brand = "visa",
            Last4 = "4242",
            ExpMonth = 12,
            ExpYear = 2030,
            IsDefault = true,
            IsActive = true,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);
        var setupResult = await service.CreatePaymentMethodSetupAsync(
            new CreatePaymentMethodSetupCommand(newUserId, "stripe"),
            CancellationToken.None);

        Assert.True(setupResult.IsSuccess);

        var eventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{setupResult.Value.ExternalSetupId}\",\"object\":\"checkout.session\",\"setup_intent\":\"shared_setup_intent\",\"metadata\":{{\"purpose\":\"payment_method_setup\",\"user_id\":\"{newUserId:D}\"}}}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var webhookResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(webhookResult.IsFailure);
        Assert.Equal(EconomyErrors.PaymentMethodOwnershipConflict.Code, webhookResult.Error.Code);

        var methods = await dbContext.SavedPaymentMethods
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync();
        var method = Assert.Single(methods);
        Assert.Equal(existingUserId, method.UserId);
        Assert.Equal("pm_shared_setup_intent", method.ExternalPaymentMethodId);
        Assert.Empty(await dbContext.SavedPaymentMethods.Where(x => x.UserId == newUserId).ToListAsync());
        Assert.Empty(identityService.SetPremiumStatusCalls);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldNotConfirmPackPurchaseUntilCheckoutSessionPaymentStatusIsPaid()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "creator-unpaid",
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

        var unpaidEventId = $"evt_{Guid.NewGuid():N}";
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var unpaidPayload = $"{{\"id\":\"{unpaidEventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"{createResult.Value.ExternalPaymentId}\",\"object\":\"checkout.session\",\"status\":\"complete\",\"payment_status\":\"unpaid\",\"metadata\":{{\"order_id\":\"{createResult.Value.OrderId:D}\"}}}}}}}}";
        var unpaidSignature = BuildStripeSignature(unpaidPayload, "test_webhook_secret");

        var unpaidResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(unpaidPayload, unpaidSignature), CancellationToken.None);

        Assert.True(unpaidResult.IsSuccess);
        Assert.True(unpaidResult.Value.Processed);
        var pendingOrder = await dbContext.PurchaseOrders.SingleAsync(x => x.Id == createResult.Value.OrderId);
        Assert.Equal(PurchaseOrderStatus.Pending, pendingOrder.Status);
        Assert.Empty(await dbContext.Wallets.ToListAsync());

        var paymentIntentEventId = $"evt_{Guid.NewGuid():N}";
        var paymentIntentPayload = $"{{\"id\":\"{paymentIntentEventId}\",\"object\":\"event\",\"type\":\"payment_intent.succeeded\",\"created\":{created + 1},\"data\":{{\"object\":{{\"id\":\"pi_later_success\",\"object\":\"payment_intent\",\"status\":\"succeeded\",\"metadata\":{{\"order_id\":\"{createResult.Value.OrderId:D}\"}}}}}}}}";
        var paymentIntentSignature = BuildStripeSignature(paymentIntentPayload, "test_webhook_secret");

        var paymentIntentResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(paymentIntentPayload, paymentIntentSignature), CancellationToken.None);

        Assert.True(paymentIntentResult.IsSuccess);
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        Assert.Equal(250, wallet.Balance);
        var succeededOrder = await dbContext.PurchaseOrders.SingleAsync(x => x.Id == createResult.Value.OrderId);
        Assert.Equal(PurchaseOrderStatus.Succeeded, succeededOrder.Status);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldNotGrantPremiumForInvalidSubscriptionPlanContext()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var identityService = new FakeIdentityService();
        var service = CreateService(dbContext, identityService: identityService);
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var periodStart = DateTimeOffset.UtcNow.AddDays(-1).ToUnixTimeSeconds();
        var periodEnd = DateTimeOffset.UtcNow.AddDays(29).ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"cs_invalid_plan\",\"object\":\"checkout.session\",\"customer\":\"cus_invalid\",\"subscription\":\"sub_invalid\",\"status\":\"complete\",\"payment_status\":\"paid\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"unknown_plan\"}},\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumPlanNotFound.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(await dbContext.UserSubscriptions.ToListAsync());
        Assert.Empty(await dbContext.Wallets.ToListAsync());
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldRejectSubscriptionOwnershipConflictBeforeUpdatingIdentity()
    {
        await using var dbContext = CreateDbContext();

        var existingUserId = Guid.NewGuid();
        var conflictingCustomerUserId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var periodStartUtc = now.AddDays(-5);
        var periodEndUtc = now.AddDays(25);

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
            StripePriceId = "price_yearly",
            DisplayOrder = 2,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = existingUserId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            Status = "Pending",
            ExternalSubscriptionId = "sub_conflict",
            CurrentPeriodStartUtc = periodStartUtc,
            CurrentPeriodEndUtc = periodEndUtc,
            MonthlyTokenLimit = 2222,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = conflictingCustomerUserId,
            Provider = "stripe",
            ExternalCustomerId = "cus_conflict",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var periodStart = new DateTimeOffset(periodStartUtc).ToUnixTimeSeconds();
        var periodEnd = new DateTimeOffset(periodEndUtc).ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"customer.subscription.updated\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"sub_conflict\",\"object\":\"subscription\",\"customer\":\"cus_conflict\",\"status\":\"active\",\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.SubscriptionOwnershipConflict.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == existingUserId && x.Provider == "stripe");
        Assert.Null(subscription.ExternalCustomerId);
        Assert.Equal("Pending", subscription.Status);
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == existingUserId).ToListAsync());
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

        var missingAmountSession = new Stripe.Checkout.Session
        {
            ClientReferenceId = order.Id.ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            Currency = "usd",
        };

        var missingCurrencySession = new Stripe.Checkout.Session
        {
            ClientReferenceId = order.Id.ToString("D"),
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            AmountTotal = 999,
        };

        Assert.True(EconomyService.IsStripeCheckoutSessionForOrder(validSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongOrderSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongAmountSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(wrongCurrencySession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(missingAmountSession, order));
        Assert.False(EconomyService.IsStripeCheckoutSessionForOrder(missingCurrencySession, order));
    }

    [Theory]
    [InlineData("paid", "complete", true)]
    [InlineData("unpaid", "complete", false)]
    [InlineData("paid", "open", false)]
    [InlineData(null, "complete", false)]
    public void StripeCheckoutSessionPaymentConfirmation_ShouldRequirePaidAndComplete(
        string? paymentStatus,
        string? sessionStatus,
        bool expected)
    {
        Assert.Equal(expected, EconomyService.IsStripeCheckoutSessionPaymentConfirmed(paymentStatus, sessionStatus));
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

        var missingCurrencyPaymentIntent = new Stripe.PaymentIntent
        {
            Metadata = new Dictionary<string, string> { ["order_id"] = order.Id.ToString("D") },
            Amount = 499,
        };

        Assert.True(EconomyService.IsStripePaymentIntentForOrder(validPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongOrderPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongAmountPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(wrongCurrencyPaymentIntent, order));
        Assert.False(EconomyService.IsStripePaymentIntentForOrder(missingCurrencyPaymentIntent, order));
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldActivateAfterBackendValidation()
    {
        await using var dbContext = CreateDbContext();
        var expiresAtUtc = DateTime.UtcNow.AddDays(30);

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
            ExpiresAtUtc = expiresAtUtc,
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
        Assert.StartsWith("gpt_", subscription.ExternalTransactionId, StringComparison.Ordinal);
        Assert.DoesNotContain("server-payload", subscription.ExternalTransactionId, StringComparison.Ordinal);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Single(grantEntries);
        Assert.Equal(2, identityService.SetPremiumStatusCalls.Count);
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldPersistEconomyState_WhenIdentitySyncFails()
    {
        await using var dbContext = CreateDbContext();

        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        var expiresAtUtc = now.AddDays(30);
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
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            SetPremiumStatusError = EconomyErrors.PremiumBillingUnavailable
        };
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = expiresAtUtc,
            Status = "active",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                userId,
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "server-payload-identity-fails",
                null,
                "purchase-identity-fails",
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumBillingUnavailable.Code, result.Error.Code);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId);
        Assert.Equal("Active", subscription.Status);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
        Assert.Contains(
            await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync(),
            x => x.EventType == "PremiumIdentitySyncFailed");
    }

    [Fact]
    public async Task GetSubscriptionSummaryAsync_ShouldReconcileActiveEconomySubscription_WhenIdentityPremiumFalse()
    {
        await using var dbContext = CreateDbContext();

        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
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
            DisplayOrder = 1,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            ExternalSubscriptionId = "sub_reconcile_active",
            CurrentPeriodStartUtc = now.AddDays(-1),
            CurrentPeriodEndUtc = now.AddDays(29),
            MonthlyTokenLimit = 777,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = false
        };
        var result = await CreateService(dbContext, identityService: identityService)
            .GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.IsPremium);
        var call = Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(call.IsPremium);
        Assert.Contains(
            await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync(),
            x => x.EventType == "PremiumReconciliationFixed");
    }

    [Fact]
    public async Task GetSubscriptionSummaryAsync_ShouldReconcileInactiveEconomySubscription_WhenIdentityPremiumTrue()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var result = await CreateService(dbContext, identityService: identityService)
            .GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.IsPremium);
        var call = Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(call.IsPremium);
        Assert.Contains(
            await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync(),
            x => x.EventType == "PremiumReconciliationFixed");
    }

    [Fact]
    public async Task GetSubscriptionSummaryAsync_ShouldCreateReconciliationIncident_WhenIdentityCannotBeRead()
    {
        await using var dbContext = CreateDbContext();

        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            ExternalSubscriptionId = "sub_reconcile_read_fails",
            CurrentPeriodStartUtc = now.AddDays(-1),
            CurrentPeriodEndUtc = now.AddDays(29),
            MonthlyTokenLimit = 777,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            GetCurrentUserError = EconomyErrors.PremiumBillingUnavailable
        };
        var result = await CreateService(dbContext, identityService: identityService)
            .GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.IsPremium);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Contains(
            await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync(),
            x => x.EventType == "PremiumReconciliationIncident");
    }

    [Fact]
    public async Task PremiumEntitlementAudit_ShouldSanitizeDurablePayloadSecrets()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var service = CreateService(dbContext);
        var appendMethod = typeof(EconomyService).GetMethod(
            "AppendPremiumEntitlementEventAsync",
            BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.NotNull(appendMethod);

        var task = (Task)appendMethod.Invoke(
            service,
            [
                userId,
                null,
                "google_play",
                "PremiumReconciliationIncident",
                "Active",
                "evt_safe",
                "sub_safe",
                new
                {
                    reason = "manual_check",
                    purchaseToken = "gp-token-secret",
                    signedPayload = "app-store-secret",
                    api_secret = "sk_live_hidden",
                    rawReceipt = "receipt-secret"
                },
                CancellationToken.None
            ])!;
        await task;

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.UserId == userId);
        Assert.NotNull(eventLog.PayloadJson);
        Assert.Contains("manual_check", eventLog.PayloadJson);
        Assert.DoesNotContain("gp-token-secret", eventLog.PayloadJson);
        Assert.DoesNotContain("app-store-secret", eventLog.PayloadJson);
        Assert.DoesNotContain("sk_live_hidden", eventLog.PayloadJson);
        Assert.DoesNotContain("receipt-secret", eventLog.PayloadJson);
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldNotDuplicateAllowanceAcrossDuplicateProviderSubscriptions()
    {
        await using var connection = await CreateSharedSqliteEconomyDatabaseAsync();
        await using var dbContext = CreateSqliteDbContext(connection.ConnectionString);

        var now = DateTime.UtcNow;
        var periodStartUtc = now.AddDays(-3);
        var periodEndUtc = now.AddDays(27);
        var userId = Guid.NewGuid();
        var existingSubscriptionId = Guid.NewGuid();

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
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 40,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = existingSubscriptionId,
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "Active",
            ExternalSubscriptionId = "sub_existing",
            CurrentPeriodStartUtc = periodStartUtc,
            CurrentPeriodEndUtc = periodEndUtc,
            MonthlyTokenLimit = 777,
            MonthlyTokensGranted = 40,
            LastTokenGrantAtUtc = now.AddDays(-2),
            CreatedAtUtc = periodStartUtc,
            UpdatedAtUtc = now,
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 40,
            BalanceAfter = 40,
            Source = WalletLedgerSource.PremiumSubscriptionGrant,
            Reason = $"premium_allowance:{periodStartUtc:O}",
            CreatedAtUtc = now.AddDays(-2),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var storeVerifier = new FakeStoreSubscriptionVerifier
        {
            ExpiresAtUtc = periodEndUtc,
            Status = "active",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                userId,
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "server-payload-duplicate-subscription",
                null,
                "purchase-duplicate-subscription",
                null),
            CancellationToken.None);

        Assert.True(result.IsSuccess);

        var grantEntries = await dbContext.WalletLedgerEntries
            .Where(x => x.UserId == userId && x.Source == WalletLedgerSource.PremiumSubscriptionGrant)
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync();
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var googleSubscription = await dbContext.UserSubscriptions.SingleAsync(
            x => x.UserId == userId && x.Provider == "google_play");

        _ = Assert.Single(grantEntries);
        Assert.Equal(40, wallet.Balance);
        Assert.Equal(40, googleSubscription.MonthlyTokensGranted);
        Assert.NotNull(googleSubscription.LastTokenGrantAtUtc);
        Assert.Equal("Active", googleSubscription.Status);
        _ = Assert.Single(identityService.SetPremiumStatusCalls);
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldRejectSubscriptionOwnedByAnotherUser()
    {
        await using var dbContext = CreateDbContext();
        var expiresAtUtc = DateTime.UtcNow.AddDays(30);

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
            ExpiresAtUtc = expiresAtUtc,
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
    public async Task VerifyPremiumStorePurchaseAsync_ShouldRejectMismatchedAccountBinding()
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
            IsActive = true,
            AppleProductId = "com.petmagic.custom.monthly.apple",
            GoogleProductId = "com.petmagic.custom.monthly.google",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(
            dbContext,
            storeVerifier: new FakeStoreSubscriptionVerifier
            {
                AccountBindingState = StoreAccountBindingState.Mismatched
            });
        var result = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                Guid.NewGuid(),
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "mismatched-token",
                null,
                "mismatched-order",
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StoreAccountBindingMismatch.Code, result.Error.Code);
        Assert.Empty(await dbContext.UserSubscriptions.ToListAsync());
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_EnforceMode_ShouldAllowMissingBindingOnlyForSameUserRestore()
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
            IsActive = true,
            AppleProductId = "com.petmagic.custom.monthly.apple",
            GoogleProductId = "com.petmagic.custom.monthly.google",
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var userId = Guid.NewGuid();
        var verifier = new FakeStoreSubscriptionVerifier
        {
            AccountBindingState = StoreAccountBindingState.Missing
        };
        var identityService = new FakeIdentityService();
        var command = new VerifyPremiumStorePurchaseCommand(
            userId,
            "monthly",
            "google_play",
            "com.petmagic.custom.monthly.google",
            "legacy-unbound-token",
            null,
            "legacy-unbound-order",
            null);

        var firstClaim = await CreateService(
            dbContext,
            storeVerifier: verifier,
            identityService: identityService,
            storeAccountBindingMode: "enforce").VerifyPremiumStorePurchaseAsync(
                command,
                CancellationToken.None);
        Assert.True(firstClaim.IsFailure);
        Assert.Equal(EconomyErrors.StoreAccountBindingMissing.Code, firstClaim.Error.Code);

        var compatibilityClaim = await CreateService(
            dbContext,
            storeVerifier: verifier,
            identityService: identityService,
            storeAccountBindingMode: "compatibility").VerifyPremiumStorePurchaseAsync(
                command,
                CancellationToken.None);
        Assert.True(compatibilityClaim.IsSuccess, compatibilityClaim.Error.Code);

        var sameUserRestore = await CreateService(
            dbContext,
            storeVerifier: verifier,
            identityService: identityService,
            storeAccountBindingMode: "enforce").VerifyPremiumStorePurchaseAsync(
                command,
                CancellationToken.None);
        Assert.True(sameUserRestore.IsSuccess, sameUserRestore.Error.Code);
        Assert.Single(await dbContext.UserSubscriptions.ToListAsync());
    }

    [Fact]
    public async Task VerifyPremiumStorePurchaseAsync_ShouldRejectActiveStoreVerificationWithoutExpiry()
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
            ExpiresAtUtc = null,
            Status = "active",
            IsActive = true,
        };
        var service = CreateService(dbContext, storeVerifier: storeVerifier, identityService: identityService);

        var result = await service.VerifyPremiumStorePurchaseAsync(
            new VerifyPremiumStorePurchaseCommand(
                Guid.NewGuid(),
                "monthly",
                "google_play",
                "com.petmagic.custom.monthly.google",
                "server-payload-without-expiry",
                null,
                "purchase-without-expiry",
                null),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.StorePurchaseInvalid.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(await dbContext.UserSubscriptions.ToListAsync());
    }

    [Fact]
    public void ResolveStripeCurrentPeriodBounds_ShouldPreferRawCurrentPeriodFieldsOverStartDateFallback()
    {
        var originalStartUtc = new DateTime(2025, 6, 1, 0, 0, 0, DateTimeKind.Utc);
        var currentPeriodStartUtc = new DateTime(2026, 6, 1, 0, 0, 0, DateTimeKind.Utc);
        var currentPeriodEndUtc = new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc);
        var subscription = new Stripe.Subscription
        {
            StartDate = originalStartUtc,
            CancelAt = currentPeriodEndUtc.AddDays(10),
        };

        SetStripeRawJsonElement(
            subscription,
            $$"""
            {
              "current_period_start": {{new DateTimeOffset(currentPeriodStartUtc).ToUnixTimeSeconds()}},
              "current_period_end": {{new DateTimeOffset(currentPeriodEndUtc).ToUnixTimeSeconds()}}
            }
            """);

        var periodBounds = EconomyService.ResolveStripeCurrentPeriodBounds(subscription);

        Assert.Equal(currentPeriodStartUtc, periodBounds.CurrentPeriodStartUtc);
        Assert.Equal(currentPeriodEndUtc, periodBounds.CurrentPeriodEndUtc);
    }

    [Fact]
    public void ResolveStripeCurrentPeriodBounds_ShouldFallbackToKnownSubscriptionDatesWhenRawPeriodIsMissing()
    {
        var startUtc = new DateTime(2026, 6, 1, 0, 0, 0, DateTimeKind.Utc);
        var cancelAtUtc = new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc);
        var subscription = new Stripe.Subscription
        {
            StartDate = startUtc,
            CancelAt = cancelAtUtc,
        };

        var periodBounds = EconomyService.ResolveStripeCurrentPeriodBounds(subscription);

        Assert.Equal(startUtc, periodBounds.CurrentPeriodStartUtc);
        Assert.Equal(cancelAtUtc, periodBounds.CurrentPeriodEndUtc);
    }

    [Fact]
    public void ResolveStripeCurrentPeriodBounds_ShouldUseSubscriptionItemPeriodWhenRawFieldsAreMissing()
    {
        var createdStartUtc = new DateTime(2025, 6, 1, 0, 0, 0, DateTimeKind.Utc);
        var currentPeriodStartUtc = new DateTime(2026, 6, 1, 0, 0, 0, DateTimeKind.Utc);
        var currentPeriodEndUtc = new DateTime(2026, 7, 1, 0, 0, 0, DateTimeKind.Utc);
        var subscription = new Stripe.Subscription
        {
            StartDate = createdStartUtc,
            Items = new Stripe.StripeList<Stripe.SubscriptionItem>
            {
                Data =
                [
                    new Stripe.SubscriptionItem
                    {
                        CurrentPeriodStart = currentPeriodStartUtc,
                        CurrentPeriodEnd = currentPeriodEndUtc,
                    }
                ]
            }
        };

        var periodBounds = EconomyService.ResolveStripeCurrentPeriodBounds(subscription);

        Assert.Equal(currentPeriodStartUtc, periodBounds.CurrentPeriodStartUtc);
        Assert.Equal(currentPeriodEndUtc, periodBounds.CurrentPeriodEndUtc);
    }

    [Fact]
    public void ShouldStripeSubscriptionRemainPremium_ShouldKeepPastDueUntilCurrentPeriodEnds()
    {
        var result = EconomyService.ShouldStripeSubscriptionRemainPremium(
            "past_due",
            DateTime.UtcNow.AddDays(3),
            cancelAtPeriodEnd: false);

        Assert.True(result);
    }

    [Fact]
    public void ShouldStripeSubscriptionRemainPremium_ShouldStopPastDueAfterCurrentPeriodEnds()
    {
        var result = EconomyService.ShouldStripeSubscriptionRemainPremium(
            "past_due",
            DateTime.UtcNow.AddMinutes(-1),
            cancelAtPeriodEnd: false);

        Assert.False(result);
    }

    [Fact]
    public void ShouldStripeSubscriptionRemainPremium_ShouldStopPastDueWhenPeriodEndIsMissing()
    {
        var result = EconomyService.ShouldStripeSubscriptionRemainPremium(
            "past_due",
            null,
            cancelAtPeriodEnd: false);

        Assert.False(result);
    }

    [Fact]
    public void ShouldStripeSubscriptionRemainPremium_ShouldStopActiveWhenPeriodEndIsMissing()
    {
        var result = EconomyService.ShouldStripeSubscriptionRemainPremium(
            "active",
            null,
            cancelAtPeriodEnd: false);

        Assert.False(result);
    }

    [Fact]
    public void IsStripeSubscriptionForPlan_ShouldMatchConfiguredStripePriceId()
    {
        var subscription = new Stripe.Subscription
        {
            Items = new Stripe.StripeList<Stripe.SubscriptionItem>
            {
                Data =
                [
                    new Stripe.SubscriptionItem
                    {
                        Price = new Stripe.Price
                        {
                            Id = "price_yearly",
                            Currency = "usd",
                            UnitAmount = 9999,
                            Recurring = new Stripe.PriceRecurring { Interval = "year" }
                        }
                    }
                ]
            }
        };

        var result = EconomyService.IsStripeSubscriptionForPlan(
            subscription,
            "price_yearly",
            "USD",
            9.99m,
            "year");

        Assert.True(result);
    }

    [Fact]
    public void IsStripeSubscriptionForPlan_ShouldRejectMismatchedConfiguredStripePriceId()
    {
        var subscription = new Stripe.Subscription
        {
            Items = new Stripe.StripeList<Stripe.SubscriptionItem>
            {
                Data =
                [
                    new Stripe.SubscriptionItem
                    {
                        Price = new Stripe.Price
                        {
                            Id = "price_monthly",
                            Currency = "usd",
                            UnitAmount = 1499,
                            Recurring = new Stripe.PriceRecurring { Interval = "month" }
                        }
                    }
                ]
            }
        };

        var result = EconomyService.IsStripeSubscriptionForPlan(
            subscription,
            "price_yearly",
            "USD",
            99.99m,
            "year");

        Assert.False(result);
    }

    [Fact]
    public void IsStripeSubscriptionForPlan_ShouldMatchInlineRecurringAmountCurrencyAndIntervalWithoutConfiguredPriceId()
    {
        var subscription = new Stripe.Subscription
        {
            Items = new Stripe.StripeList<Stripe.SubscriptionItem>
            {
                Data =
                [
                    new Stripe.SubscriptionItem
                    {
                        Price = new Stripe.Price
                        {
                            Currency = "usd",
                            UnitAmount = 1999,
                            Recurring = new Stripe.PriceRecurring { Interval = "month" }
                        }
                    }
                ]
            }
        };

        var result = EconomyService.IsStripeSubscriptionForPlan(
            subscription,
            null,
            "USD",
            19.99m,
            "month");

        Assert.True(result);
    }

    [Fact]
    public void IsStoreSubscriptionPremium_ShouldRequirePeriodEndForCanceledStatus()
    {
        Assert.False(EconomyWebhookParser.IsStoreSubscriptionPremium("Canceled", null));
        Assert.True(EconomyWebhookParser.IsStoreSubscriptionPremium("Canceled", DateTime.UtcNow.AddDays(1)));
    }

    [Fact]
    public void IsStoreSubscriptionPremium_ShouldRequirePeriodEndForActiveStatus()
    {
        Assert.False(EconomyWebhookParser.IsStoreSubscriptionPremium("Active", null));
        Assert.True(EconomyWebhookParser.IsStoreSubscriptionPremium("Active", DateTime.UtcNow.AddDays(1)));
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
        Assert.Equal("settled", first.Value.Status);
        Assert.Equal("already_settled", second.Value.Status);
        Assert.True(first.Value.TokensGranted);
        Assert.False(second.Value.TokensGranted);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        var ledgerEntries = await dbContext.WalletLedgerEntries.Where(x => x.UserId == userId).ToListAsync();
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);

        Assert.Equal("succeeded", order.Status);
        Assert.StartsWith("gpt_", order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.DoesNotContain("gp-token-pack-1", order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.Equal(120, wallet.Balance);
        Assert.Single(ledgerEntries);
        Assert.Equal(120, ledgerEntries[0].Delta);
    }

    [Fact]
    public async Task ValidateGooglePlayBillingAsync_ShouldRecognizeLegacyRawPurchaseTokenWithoutDuplicating()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();
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
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = "gp-legacy-token-pack-1",
            CreatedAtUtc = DateTime.UtcNow,
            ConfirmedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateService(dbContext);

        var result = await service.ValidateGooglePlayBillingAsync(
            new ValidateGooglePlayBillingCommand(
                userId,
                "gp-legacy-token-pack-1",
                "com.petmagic.app.tokens.google.pack100",
                "com.petmagic.app"),
            CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal("already_settled", result.Value.Status);
        Assert.False(result.Value.TokensGranted);
        Assert.Single(await dbContext.PurchaseOrders.ToListAsync());
        Assert.Empty(await dbContext.WalletLedgerEntries.ToListAsync());
    }

    [Fact]
    public async Task VerifyPackStorePurchaseAsync_ShouldStoreHashedGooglePlayPurchaseTokenAndNotGrantTwice()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        EnableStoreProvider(dbContext, "google_play", "android");

        var packCode = await dbContext.CurrencyPacks
            .Where(x => x.Id == packId)
            .Select(x => x.Code)
            .SingleAsync();
        var productId = BuildStoreProductId("google_play", packCode);
        var purchaseToken = "gp-direct-pack-token-1";
        var service = CreateService(dbContext);

        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "google_play", "android", "1.0.0", "US", "en"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var command = new VerifyPackStorePurchaseCommand(
            userId,
            createResult.Value.OrderId,
            "google_play",
            productId,
            purchaseToken,
            null,
            "purchase-direct-1",
            DateTime.UtcNow.ToString("O"));

        var first = await service.VerifyPackStorePurchaseAsync(command, CancellationToken.None);
        var second = await service.VerifyPackStorePurchaseAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal(PurchaseOrderStatus.Succeeded, first.Value.Status);
        Assert.Equal(PurchaseOrderStatus.Succeeded, second.Value.Status);

        var order = await dbContext.PurchaseOrders.SingleAsync();
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var ledgerEntry = await dbContext.WalletLedgerEntries.SingleAsync(x => x.UserId == userId);

        Assert.StartsWith("gpt_", order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.DoesNotContain(purchaseToken, order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.Equal(120, wallet.Balance);
        Assert.Equal(120, ledgerEntry.Delta);
        Assert.Equal(order.ExternalPaymentId, ledgerEntry.SourceTransactionId);
        Assert.DoesNotContain(purchaseToken, ledgerEntry.SourceTransactionId, StringComparison.Ordinal);
    }

    [Fact]
    public async Task VerifyPackStorePurchaseAsync_ShouldRecognizeLegacyRawGooglePlayTokenWithoutDuplicating()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = AddStarterPack(dbContext);
        EnableStoreProvider(dbContext, "google_play", "android");
        var now = DateTime.UtcNow;
        var purchaseToken = "gp-direct-legacy-token-1";
        var legacyOrderId = Guid.NewGuid();

        dbContext.PurchaseOrders.Add(new PurchaseOrder
        {
            Id = legacyOrderId,
            UserId = userId,
            PackId = packId,
            PaymentProvider = "google_play",
            Status = PurchaseOrderStatus.Succeeded,
            PriceAmount = 4.99m,
            CurrencyCode = "USD",
            SparkToGrant = 120,
            ExternalPaymentId = purchaseToken,
            CreatedAtUtc = now,
            ConfirmedAtUtc = now
        });
        dbContext.Wallets.Add(new Wallet
        {
            UserId = userId,
            Balance = 120,
            UpdatedAtUtc = now
        });
        dbContext.WalletLedgerEntries.Add(new WalletLedgerEntry
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Delta = 120,
            BalanceAfter = 120,
            Source = WalletLedgerSource.PackPurchase,
            Reason = $"purchase:{legacyOrderId:D}",
            TokenKind = "purchased",
            OperationKind = "credit",
            SourceProvider = "google_play",
            SourceTransactionId = purchaseToken,
            CreatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        var packCode = await dbContext.CurrencyPacks
            .Where(x => x.Id == packId)
            .Select(x => x.Code)
            .SingleAsync();
        var service = CreateService(dbContext);
        var createResult = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(userId, packId, "USD", "google_play", "android", "1.0.0", "US", "en"),
            CancellationToken.None);

        Assert.True(createResult.IsSuccess);

        var verifyResult = await service.VerifyPackStorePurchaseAsync(
            new VerifyPackStorePurchaseCommand(
                userId,
                createResult.Value.OrderId,
                "google_play",
                BuildStoreProductId("google_play", packCode),
                purchaseToken,
                null,
                "purchase-direct-legacy-1",
                DateTime.UtcNow.ToString("O")),
            CancellationToken.None);

        Assert.True(verifyResult.IsSuccess);
        Assert.Equal(legacyOrderId, verifyResult.Value.OrderId);
        Assert.Equal(PurchaseOrderStatus.Succeeded, verifyResult.Value.Status);
        Assert.Equal(2, await dbContext.PurchaseOrders.CountAsync());
        Assert.Single(await dbContext.PurchaseOrders.Where(x => x.Status == PurchaseOrderStatus.Succeeded).ToListAsync());
        Assert.Single(await dbContext.PurchaseOrders.Where(x => x.Status == PurchaseOrderStatus.Pending).ToListAsync());
        Assert.Equal(120, (await dbContext.Wallets.SingleAsync(x => x.UserId == userId)).Balance);
        Assert.Single(await dbContext.WalletLedgerEntries.Where(x => x.UserId == userId).ToListAsync());
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
    public async Task ListPacksAsync_ShouldUseProviderSpecificStoreIdentifiers()
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

        var options = Microsoft.Extensions.Options.Options.Create(
            new PetMagic.Modules.Economy.Infrastructure.Options.EconomyOptions
            {
                GooglePlayPackageName = "com.petmagic.android",
                AppStoreBundleId = "com.petmagic.ios"
            });
        using var memoryCache = new Microsoft.Extensions.Caching.Memory.MemoryCache(
            new Microsoft.Extensions.Caching.Memory.MemoryCacheOptions());
        var service = new EconomyService(
            dbContext,
            new FakePaymentGateway(),
            new FakeStoreSubscriptionVerifier(),
            options,
            memoryCache,
            storeWebhookSecurityValidator: new FakeStoreWebhookSecurityValidator(Result.Success()));

        var result = await service.ListPacksAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        var pack = Assert.Single(result.Value, x => x.Code == "pack100");
        Assert.Equal("com.petmagic.android.tokens.google.pack100", pack.GooglePlayProductId);
        Assert.Equal("com.petmagic.ios.tokens.apple.pack100", pack.AppStoreProductId);
    }

    private static void SetStripeRawJsonElement(Stripe.Subscription subscription, string json)
    {
        var property = typeof(Stripe.StripeEntity).GetProperty(
            "RawJsonElement",
            BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
        var element = JsonDocument.Parse(json).RootElement.Clone();
        property!.SetValue(subscription, (JsonElement?)element);
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
        Assert.StartsWith("gpt_", order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.DoesNotContain("gp-sensitive-purchase-token-1", order.ExternalPaymentId, StringComparison.Ordinal);
        Assert.Equal(order.ExternalPaymentId, ledgerEntry.SourceTransactionId);
        Assert.DoesNotContain("gp-sensitive-purchase-token-1", ledgerEntry.SourceTransactionId, StringComparison.Ordinal);

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
        Assert.Equal("settled", first.Value.Status);
        Assert.Equal("already_settled", second.Value.Status);
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
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"cs_sub_test\",\"object\":\"checkout.session\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"status\":\"complete\",\"payment_status\":\"paid\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"yearly\"}},\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
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
    public async Task HandleStripeWebhook_ShouldNotActivatePremiumWithoutConfirmedCurrentPeriodEnd()
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
            StripePriceId = "price_yearly",
            DisplayOrder = 2,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var userId = Guid.NewGuid();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var periodStart = new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)).ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"cs_sub_missing_period_end\",\"object\":\"checkout.session\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"status\":\"complete\",\"payment_status\":\"paid\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"yearly\"}},\"current_period_start\":{periodStart},\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("Pending", subscription.Status);
        Assert.Null(subscription.CurrentPeriodEndUtc);
        Assert.Equal(0, subscription.MonthlyTokensGranted);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.ExternalEventId == eventId);
        Assert.Equal("SubscriptionPending", eventLog.EventType);
        Assert.Equal("Pending", eventLog.Status);
        Assert.NotNull(eventLog.PayloadJson);
        Assert.Contains("\"Purpose\":\"premium_subscription\"", eventLog.PayloadJson);
        Assert.Contains("\"CheckoutPaymentStatus\":\"paid\"", eventLog.PayloadJson);
        Assert.Contains("\"PlanCode\":\"yearly\"", eventLog.PayloadJson);
        Assert.Contains("\"HasCustomerId\":true", eventLog.PayloadJson);
        Assert.Contains("\"HasUserId\":true", eventLog.PayloadJson);
        Assert.DoesNotContain(payload, eventLog.PayloadJson);
        Assert.DoesNotContain("cus_test", eventLog.PayloadJson);
        Assert.DoesNotContain(userId.ToString("D"), eventLog.PayloadJson);
        Assert.DoesNotContain("cs_sub_missing_period_end", eventLog.PayloadJson);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldNotActivatePremiumUntilCheckoutSessionPaymentStatusIsPaid()
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
            StripePriceId = "price_yearly",
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
        var unpaidEventId = $"evt_{Guid.NewGuid():N}";
        var unpaidPayload = $"{{\"id\":\"{unpaidEventId}\",\"object\":\"event\",\"type\":\"checkout.session.completed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"cs_sub_unpaid\",\"object\":\"checkout.session\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"status\":\"complete\",\"payment_status\":\"unpaid\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"yearly\"}},\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var unpaidSignature = BuildStripeSignature(unpaidPayload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var unpaidResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(unpaidPayload, unpaidSignature), CancellationToken.None);

        Assert.True(unpaidResult.IsSuccess, unpaidResult.IsFailure ? $"{unpaidResult.Error.Code}:{unpaidResult.Error.Message}" : "unexpected failure state");
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(await dbContext.UserSubscriptions.Where(x => x.UserId == userId).ToListAsync());
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());

        var invoiceEventId = $"evt_{Guid.NewGuid():N}";
        var invoicePayload = $"{{\"id\":\"{invoiceEventId}\",\"object\":\"event\",\"type\":\"invoice.payment_succeeded\",\"created\":{created + 1},\"data\":{{\"object\":{{\"id\":\"in_test_paid\",\"object\":\"invoice\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"status\":\"paid\",\"metadata\":{{\"purpose\":\"premium_subscription\",\"user_id\":\"{userId:D}\",\"plan_code\":\"yearly\"}},\"current_period_start\":{periodStart},\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var invoiceSignature = BuildStripeSignature(invoicePayload, "test_webhook_secret");

        var invoiceResult = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(invoicePayload, invoiceSignature), CancellationToken.None);

        Assert.True(invoiceResult.IsSuccess, invoiceResult.IsFailure ? $"{invoiceResult.Error.Code}:{invoiceResult.Error.Message}" : "unexpected failure state");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);
        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal(40, wallet.Balance);
        Assert.Equal("Active", subscription.Status);
        Assert.Equal("yearly", subscription.PlanId);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldResolvePlanFromStripePriceIdWithoutMetadataPlanCode()
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
            StripePriceId = "price_yearly",
            DisplayOrder = 2,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_price_lookup",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var periodStart = new DateTimeOffset(new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc)).ToUnixTimeSeconds();
        var periodEnd = new DateTimeOffset(new DateTime(2027, 1, 1, 0, 0, 0, DateTimeKind.Utc)).ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = JsonSerializer.Serialize(new
        {
            id = eventId,
            @object = "event",
            type = "customer.subscription.created",
            created,
            data = new
            {
                @object = new
                {
                    id = "sub_price_lookup",
                    @object = "subscription",
                    customer = "cus_price_lookup",
                    status = "active",
                    current_period_start = periodStart,
                    current_period_end = periodEnd,
                    cancel_at_period_end = false,
                    items = new
                    {
                        data = new object[]
                        {
                            new
                            {
                                id = "si_test",
                                @object = "subscription_item",
                                current_period_start = periodStart,
                                current_period_end = periodEnd,
                                price = new
                                {
                                    id = "price_yearly",
                                    currency = "usd",
                                    unit_amount = 14999,
                                    recurring = new
                                    {
                                        interval = "year"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        var wallet = await dbContext.Wallets.SingleAsync(x => x.UserId == userId);

        Assert.Equal("yearly", subscription.PlanId);
        Assert.Equal("Active", subscription.Status);
        Assert.Equal(2222, subscription.MonthlyTokenLimit);
        Assert.Equal(40, wallet.Balance);
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldKeepExistingPremiumStateWhenActiveUpdateOmitsCurrentPeriodEnd()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Yearly",
            BillingPeriod = "yearly",
            PriceAmount = 99.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 700,
            IsRecommended = false,
            IsActive = true,
            StripePriceId = "price_yearly",
            DisplayOrder = 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_active_missing_period_end",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            ProductId = "price_yearly",
            Status = "Active",
            ExternalCustomerId = "cus_active_missing_period_end",
            ExternalSubscriptionId = "sub_active_missing_period_end",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = now.AddDays(20),
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-10),
            UpdatedAtUtc = now.AddMinutes(-5),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"customer.subscription.updated\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"sub_active_missing_period_end\",\"object\":\"subscription\",\"customer\":\"cus_active_missing_period_end\",\"status\":\"active\",\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("Active", subscription.Status);
        Assert.Equal(40, subscription.MonthlyTokensGranted);
        Assert.True(subscription.CurrentPeriodEndUtc >= DateTime.UtcNow);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(await dbContext.Wallets.Where(x => x.UserId == userId).ToListAsync());

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.ExternalEventId == eventId);
        Assert.Equal("SubscriptionStatusUpdated", eventLog.EventType);
        Assert.Equal("Active", eventLog.Status);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldKeepPremiumEntitlementOnInvoicePaymentFailedUntilTerminalSubscriptionEvent()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Yearly",
            BillingPeriod = "yearly",
            PriceAmount = 99.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 700,
            IsRecommended = false,
            IsActive = true,
            StripePriceId = "price_yearly",
            DisplayOrder = 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_test",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            ProductId = "price_yearly",
            Status = "Active",
            ExternalCustomerId = "cus_test",
            ExternalSubscriptionId = "sub_test",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = now.AddDays(20),
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-10),
            UpdatedAtUtc = now.AddMinutes(-5),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"invoice.payment_failed\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"in_test\",\"object\":\"invoice\",\"customer\":\"cus_test\",\"subscription\":\"sub_test\",\"status\":\"open\"}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("PastDue", subscription.Status);
        Assert.Equal(now.AddDays(20).Date, subscription.CurrentPeriodEndUtc?.Date);

        var eventLog = await dbContext.SubscriptionEventLogs
            .SingleAsync(x => x.ExternalEventId == eventId);
        Assert.Equal(userId, eventLog.UserId);
        Assert.Equal("SubscriptionPaymentFailed", eventLog.EventType);
        Assert.Equal("PastDue", eventLog.Status);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldKeepPremiumEntitlementOnPastDueSubscriptionUpdatedUntilCurrentPeriodEnds()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Yearly",
            BillingPeriod = "yearly",
            PriceAmount = 99.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 700,
            IsRecommended = false,
            IsActive = true,
            StripePriceId = "price_yearly",
            DisplayOrder = 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var periodEnd = DateTimeOffset.UtcNow.AddDays(15).ToUnixTimeSeconds();
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_test",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            ProductId = "price_yearly",
            Status = "Active",
            ExternalCustomerId = "cus_test",
            ExternalSubscriptionId = "sub_test",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = now.AddDays(20),
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-10),
            UpdatedAtUtc = now.AddMinutes(-5),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"customer.subscription.updated\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"sub_test\",\"object\":\"subscription\",\"customer\":\"cus_test\",\"status\":\"past_due\",\"current_period_end\":{periodEnd},\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.True(identityService.SetPremiumStatusCalls[0].IsPremium);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("PastDue", subscription.Status);
        Assert.True(subscription.CurrentPeriodEndUtc >= DateTime.UtcNow);

        var summary = await service.GetSubscriptionSummaryAsync(userId, CancellationToken.None);
        Assert.True(summary.IsSuccess);
        Assert.True(summary.Value.IsPremium);

        var eventLog = await dbContext.SubscriptionEventLogs
            .SingleAsync(x => x.ExternalEventId == eventId);
        Assert.Equal("SubscriptionStatusUpdated", eventLog.EventType);
        Assert.Equal("PastDue", eventLog.Status);
    }

    [Fact]
    public async Task HandleStripeWebhook_ShouldResolveStripeSubscriptionUserWithoutMetadata()
    {
        await using var dbContext = CreateDbContext();

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = "yearly",
            Name = "PetMagic Premium Yearly",
            BillingPeriod = "yearly",
            PriceAmount = 99.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 700,
            IsRecommended = false,
            IsActive = true,
            StripePriceId = "price_yearly",
            DisplayOrder = 1,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow,
        });

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.PaymentCustomers.Add(new PaymentCustomer
        {
            UserId = userId,
            Provider = "stripe",
            ExternalCustomerId = "cus_test",
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            ProductId = "price_yearly",
            Status = "Active",
            ExternalCustomerId = "cus_test",
            ExternalSubscriptionId = "sub_test",
            CurrentPeriodStartUtc = now.AddDays(-10),
            CurrentPeriodEndUtc = now.AddDays(20),
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-10),
            UpdatedAtUtc = now.AddMinutes(-5),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var eventId = $"evt_{Guid.NewGuid():N}";
        var payload = $"{{\"id\":\"{eventId}\",\"object\":\"event\",\"type\":\"customer.subscription.deleted\",\"created\":{created},\"data\":{{\"object\":{{\"id\":\"sub_test\",\"object\":\"subscription\",\"customer\":\"cus_test\",\"status\":\"canceled\",\"cancel_at_period_end\":false}}}}}}";
        var signature = BuildStripeSignature(payload, "test_webhook_secret");

        var service = CreateService(dbContext, identityService: identityService);
        var result = await service.HandleStripeWebhookAsync(new StripeWebhookCommand(payload, signature), CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.Equal(userId, identityService.SetPremiumStatusCalls[0].UserId);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("Expired", subscription.Status);

        var eventLog = await dbContext.SubscriptionEventLogs
            .SingleAsync(x => x.ExternalEventId == eventId);
        Assert.Equal(userId, eventLog.UserId);
        Assert.Equal("SubscriptionExpired", eventLog.EventType);
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldExpireLocalStripeSubscriptionWithoutExternalSubscriptionId()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "yearly",
            Status = "Active",
            ExternalCustomerId = "cus_legacy",
            ExternalSubscriptionId = null,
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = now.AddDays(25),
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-5),
            UpdatedAtUtc = now.AddMinutes(-1),
        });
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService();
        var service = CreateService(
            dbContext,
            identityService: identityService,
            adminAuditLog: new RecordingAdminAuditLog());

        var result = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(userId, "stripe", "Verified administrative cancellation."),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure state");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
        Assert.False(result.Value.IsPremium);
        Assert.Equal("Expired", result.Value.Status);

        var subscription = await dbContext.UserSubscriptions.SingleAsync(x => x.UserId == userId && x.Provider == "stripe");
        Assert.Equal("Expired", subscription.Status);
        Assert.False(subscription.CancelAtPeriodEnd);
        Assert.NotNull(subscription.CurrentPeriodEndUtc);
        Assert.True(subscription.CurrentPeriodEndUtc <= DateTime.UtcNow);

        var eventLog = await dbContext.SubscriptionEventLogs.SingleAsync(x => x.UserId == userId);
        Assert.Equal("AdminImmediateCancelRequested", eventLog.EventType);
        Assert.Equal("Completed", eventLog.Status);
        Assert.NotNull(eventLog.ProcessedAtUtc);
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
    public async Task GetSubscriptionSummaryAsync_ShouldPreferActiveSubscriptionOverNewerExpiredRecord()
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
                Provider = "google_play",
                PurchaseChannel = "in_app",
                Region = "US",
                PlanId = "monthly",
                Status = "Active",
                ExternalSubscriptionId = "gp_active",
                CurrentPeriodStartUtc = now.AddDays(-7),
                CurrentPeriodEndUtc = now.AddDays(21),
                MonthlyTokenLimit = 500,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-7),
                UpdatedAtUtc = now.AddMinutes(-10),
            },
            new UserSubscription
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Provider = "stripe",
                PurchaseChannel = "web",
                Region = "US",
                PlanId = "yearly",
                Status = "Expired",
                ExternalSubscriptionId = "sub_expired",
                CurrentPeriodStartUtc = now.AddDays(-40),
                CurrentPeriodEndUtc = now.AddDays(-5),
                MonthlyTokenLimit = 700,
                MonthlyTokensGranted = 40,
                CreatedAtUtc = now.AddDays(-40),
                UpdatedAtUtc = now.AddMinutes(-1),
            });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.True(result.Value.IsPremium);
        Assert.Equal("google_play", result.Value.Provider);
        Assert.Equal("Active", result.Value.Status);
        Assert.Equal("monthly", result.Value.BillingPeriod);
    }

    [Fact]
    public async Task GetSubscriptionSummaryAsync_ShouldNotTreatPastDueWithoutPeriodEndAsPremium()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
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
        });
        dbContext.UserSubscriptions.Add(new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = "stripe",
            PurchaseChannel = "web",
            Region = "US",
            PlanId = "monthly",
            Status = "PastDue",
            ExternalSubscriptionId = "sub_missing_period_end",
            CurrentPeriodStartUtc = now.AddDays(-7),
            CurrentPeriodEndUtc = null,
            MonthlyTokenLimit = 500,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-7),
            UpdatedAtUtc = now,
        });
        await dbContext.SaveChangesAsync();

        var result = await CreateService(dbContext).GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.False(result.Value.IsPremium);
        Assert.Equal("PastDue", result.Value.Status);
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
    public async Task CreatePackPurchase_WithSavedPaymentMethodForStoreProvider_ShouldFailWithoutPersistingOrder()
    {
        await using var dbContext = CreateDbContext();

        var userId = Guid.NewGuid();
        var packId = Guid.NewGuid();

        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "starter-google",
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

        var purchase = await service.CreatePackPurchaseAsync(
            new CreatePackPurchaseCommand(
                userId,
                packId,
                "USD",
                "google_play",
                "android",
                "1.0.0",
                "US",
                "en",
                Guid.NewGuid()),
            CancellationToken.None);

        Assert.True(purchase.IsFailure);
        Assert.Equal("economy.payment_method_provider_invalid", purchase.Error.Code);
        Assert.Empty(await dbContext.PurchaseOrders.ToListAsync());
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
    public async Task CreatePaymentProviderConfigurationAsync_ShouldFail_WhenNativePaymentSheetCopyProvided()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        var create = await service.CreatePaymentProviderConfigurationAsync(
            new CreatePaymentProviderConfigurationCommand(
                "stripe",
                "android",
                "EU",
                true,
                true,
                true,
                true,
                true,
                "1.0.0",
                true,
                10,
                "Stripe",
                null,
                null,
                "Stripe billing is completed inside PetMagic with native payment sheet.",
                "test",
                "Secure hosted checkout." ),
            CancellationToken.None);

        Assert.True(create.IsFailure);
        Assert.Equal(EconomyErrors.PaymentProviderDisclosureInvalid.Code, create.Error.Code);
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

    [Theory]
    [InlineData("23505", "IX_economy_payment_provider_configs_Provider_Platform_Region", true)]
    [InlineData("23505", "IX_economy_payment_provider_configs_Platform_IsEnabled", false)]
    [InlineData("23514", "IX_economy_payment_provider_configs_Provider_Platform_Region", false)]
    public void PaymentProviderConfigurationRouteUniqueViolation_ShouldOnlyMatchRouteIndex(
        string sqlState,
        string constraintName,
        bool expected)
    {
        var actual = EconomyAdminConfigurationService.IsPaymentProviderConfigurationRouteUniqueViolation(
            sqlState,
            constraintName);

        Assert.Equal(expected, actual);
    }

    [Fact]
    public async Task UpdatePaymentProviderConfigurationAsync_ShouldRejectDuplicateNormalizedRoute()
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

        var update = await service.UpdatePaymentProviderConfigurationAsync(
            new UpdatePaymentProviderConfigurationCommand(
                source.Id,
                " us ",
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

        Assert.True(update.IsFailure);
        Assert.Equal(EconomyErrors.PaymentProviderConfigurationAlreadyExists.Code, update.Error.Code);
        Assert.Equal(
            "*",
            await dbContext.PaymentProviderConfigurations
                .Where(x => x.Id == source.Id)
                .Select(x => x.Region)
                .SingleAsync());
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
    public async Task CurrencyPackAndSubscriptionPlanMutations_ShouldWriteAuditTrail()
    {
        await using var dbContext = CreateDbContext();
        var packId = Guid.NewGuid();
        const string planId = "premium-audit-monthly";
        dbContext.CurrencyPacks.Add(new CurrencyPack
        {
            Id = packId,
            Code = "audit-pack",
            DisplayName = "Audit pack before",
            CurrencyCode = "USD",
            PriceAmount = 4.99m,
            GrantedSpark = 100,
            BonusSpark = 10,
            IsActive = true,
            SortOrder = 5,
        });
        dbContext.SubscriptionPlans.Add(new SubscriptionPlan
        {
            Id = planId,
            Name = "Audit plan before",
            BillingPeriod = "monthly",
            PriceAmount = 9.99m,
            CurrencyCode = "USD",
            MonthlyTokenLimit = 500,
            IsRecommended = false,
            IsActive = true,
            AppleProductId = "apple-old-product-id",
            GoogleProductId = null,
            StripePriceId = "stripe-old-price-id",
            DisplayOrder = 2,
            CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
            UpdatedAtUtc = DateTime.UtcNow.AddDays(-1),
        });
        await dbContext.SaveChangesAsync();

        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);

        var packUpdate = await service.UpdateCurrencyPackAsync(
            new UpdateCurrencyPackCommand(packId, "Audit pack after", 5.49m, 120, 20, false, 7),
            CancellationToken.None);
        var planUpdate = await service.UpdateSubscriptionPlanAsync(
            new UpdateSubscriptionPlanCommand(
                planId,
                "Audit plan after",
                11.99m,
                "eur",
                700,
                true,
                false,
                null,
                "google-new-product-id",
                null,
                3),
            CancellationToken.None);

        Assert.True(packUpdate.IsSuccess);
        Assert.True(planUpdate.IsSuccess);
        Assert.Collection(
            auditLog.Entries,
            entry =>
            {
                Assert.Equal("admin.economy.currency_pack.updated", entry.Action);
                Assert.Equal("currency_pack", entry.TargetType);
                Assert.Equal(packId.ToString("D"), entry.TargetId);
                Assert.NotEqual(entry.OldValue, entry.NewValue);

                using var oldSnapshot = JsonDocument.Parse(entry.OldValue!);
                using var newSnapshot = JsonDocument.Parse(entry.NewValue!);
                Assert.Equal("Audit pack before", oldSnapshot.RootElement.GetProperty("DisplayName").GetString());
                Assert.Equal("Audit pack after", newSnapshot.RootElement.GetProperty("DisplayName").GetString());
                Assert.Equal(120, newSnapshot.RootElement.GetProperty("GrantedSpark").GetInt32());
            },
            entry =>
            {
                Assert.Equal("admin.economy.subscription_plan.updated", entry.Action);
                Assert.Equal("subscription_plan", entry.TargetType);
                Assert.Equal(planId, entry.TargetId);
                Assert.NotEqual(entry.OldValue, entry.NewValue);

                var snapshots = $"{entry.OldValue}\n{entry.NewValue}";
                Assert.DoesNotContain("apple-old-product-id", snapshots, StringComparison.Ordinal);
                Assert.DoesNotContain("stripe-old-price-id", snapshots, StringComparison.Ordinal);
                Assert.DoesNotContain("google-new-product-id", snapshots, StringComparison.Ordinal);

                using var oldSnapshot = JsonDocument.Parse(entry.OldValue!);
                using var newSnapshot = JsonDocument.Parse(entry.NewValue!);
                Assert.True(oldSnapshot.RootElement.GetProperty("AppleProductIdConfigured").GetBoolean());
                Assert.False(oldSnapshot.RootElement.GetProperty("GoogleProductIdConfigured").GetBoolean());
                Assert.True(oldSnapshot.RootElement.GetProperty("StripePriceIdConfigured").GetBoolean());
                Assert.False(newSnapshot.RootElement.GetProperty("AppleProductIdConfigured").GetBoolean());
                Assert.True(newSnapshot.RootElement.GetProperty("GoogleProductIdConfigured").GetBoolean());
                Assert.False(newSnapshot.RootElement.GetProperty("StripePriceIdConfigured").GetBoolean());
            });

        var outboxMessages = await dbContext.PushOutboxMessages
            .AsNoTracking()
            .OrderBy(message => message.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, outboxMessages.Count);
        Assert.All(outboxMessages, message =>
        {
            Assert.Equal(EconomyAdminAuditOutbox.Kind, message.Kind);
            Assert.Equal(PushOutboxStatus.Sent, message.Status);
            Assert.Contains("eventId", message.PayloadJson, StringComparison.Ordinal);
            Assert.Contains("occurredAtUtc", message.PayloadJson, StringComparison.Ordinal);
            Assert.DoesNotContain("apple-old-product-id", message.PayloadJson, StringComparison.Ordinal);
            Assert.DoesNotContain("stripe-old-price-id", message.PayloadJson, StringComparison.Ordinal);
            Assert.DoesNotContain("google-new-product-id", message.PayloadJson, StringComparison.Ordinal);
        });
    }

    [Fact]
    public async Task PaymentProviderConfigurationMutations_ShouldWriteAuditTrail()
    {
        await using var dbContext = CreateDbContext();
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(dbContext, adminAuditLog: auditLog);
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

        var clone = await service.ClonePaymentProviderConfigurationAsync(
            new ClonePaymentProviderConfigurationCommand(source.Id, "EU"),
            CancellationToken.None);

        Assert.True(clone.IsSuccess);

        var update = await service.UpdatePaymentProviderConfigurationAsync(
            new UpdatePaymentProviderConfigurationCommand(
                create.Value.ConfigurationId,
                "CA",
                create.Value.IsEnabled,
                create.Value.IsRecommended,
                create.Value.IsSelectedByDefault,
                create.Value.RequiresExternalWarning,
                create.Value.RequiresStoreDisclosure,
                create.Value.AllowedFromAppVersion,
                create.Value.ExternalCheckoutAllowed,
                create.Value.BonusTokensPercent,
                create.Value.DisplayLabel,
                create.Value.DisplaySubtitle,
                create.Value.WarningTitle,
                create.Value.WarningMessage,
                create.Value.Mode,
                create.Value.Notes),
            CancellationToken.None);

        Assert.True(update.IsSuccess);

        var delete = await service.DeletePaymentProviderConfigurationAsync(
            new DeletePaymentProviderConfigurationCommand(clone.Value.ConfigurationId),
            CancellationToken.None);

        Assert.True(delete.IsSuccess);

        Assert.Collection(
            auditLog.Entries,
            entry =>
            {
                Assert.Equal("admin.economy.payment_provider_configuration.created", entry.Action);
                Assert.Equal("payment_provider_configuration", entry.TargetType);
                Assert.Equal(create.Value.ConfigurationId.ToString("D"), entry.TargetId);
                Assert.Null(entry.OldValue);
                Assert.Contains("region=US", entry.NewValue ?? string.Empty);
            },
            entry =>
            {
                Assert.Equal("admin.economy.payment_provider_configuration.cloned", entry.Action);
                Assert.Equal(clone.Value.ConfigurationId.ToString("D"), entry.TargetId);
                Assert.Contains("region=*", entry.OldValue ?? string.Empty);
                Assert.Contains("region=EU", entry.NewValue ?? string.Empty);
                Assert.Contains(source.Id.ToString("D"), entry.Details ?? string.Empty);
            },
            entry =>
            {
                Assert.Equal("admin.economy.payment_provider_configuration.updated", entry.Action);
                Assert.Equal(create.Value.ConfigurationId.ToString("D"), entry.TargetId);
                Assert.Contains("region=US", entry.OldValue ?? string.Empty);
                Assert.Contains("region=CA", entry.NewValue ?? string.Empty);
            },
            entry =>
            {
                Assert.Equal("admin.economy.payment_provider_configuration.deleted", entry.Action);
                Assert.Equal(clone.Value.ConfigurationId.ToString("D"), entry.TargetId);
                Assert.Contains("region=EU", entry.OldValue ?? string.Empty);
                Assert.Null(entry.NewValue);
            });
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
