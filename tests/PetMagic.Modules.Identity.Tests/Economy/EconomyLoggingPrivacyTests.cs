using PetMagic.Modules.Economy.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyLoggingPrivacyTests
{
    [Fact]
    public void EconomyInfrastructureExceptions_ShouldUseSafeErrorCodes()
    {
        var root = FindRepositoryRoot();
        var loggingSource = ReadEconomyInfrastructureSource(root, "EconomyService.Logging.cs");
        var subscriptionAllowanceSource = ReadEconomyInfrastructureSource(root, "EconomyService.SubscriptionAllowance.cs");
        var reconciliationSource = ReadEconomyInfrastructureSource(root, "EconomyService.Reconciliation.cs");
        var referralsSource = ReadEconomyInfrastructureSource(root, "EconomyService.Internal.CustomersAndReferrals.cs");

        Assert.Contains("BuildSafeEconomyOperationException", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeErrorCode(error.Code)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"premium_weekly_grant\", walletMutation.Error);", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"premium_subscription_allowance\", result.Error);", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"premium_subscription_grant\", walletMutation.Error);", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"reconcile_purchase_ledger\", result.Error);", reconciliationSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"referral_inviter_bonus\", referrerMutation.Error);", referralsSource, StringComparison.Ordinal);
        Assert.Contains("throw BuildSafeEconomyOperationException(\"referral_friend_bonus\", refereeMutation.Error);", referralsSource, StringComparison.Ordinal);
        Assert.DoesNotContain("new InvalidOperationException(result.Error.Message)", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("new InvalidOperationException(walletMutation.Error.Message)", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("new InvalidOperationException(result.Error.Message)", reconciliationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("new InvalidOperationException(referrerMutation.Error.Message)", referralsSource, StringComparison.Ordinal);
        Assert.DoesNotContain("new InvalidOperationException(refereeMutation.Error.Message)", referralsSource, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyLogging_ShouldMaskExternalProviderIdentifiers()
    {
        var root = FindRepositoryRoot();
        var loggingSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Logging.cs"));
        var economyServiceSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.cs"));
        var paymentsAndCheckoutSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PaymentsAndCheckout.cs"));
        var sanitizerSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyLogSanitizer.cs"));
        var appStoreWebhookSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Webhooks.AppStore.cs"));
        var googlePlayWebhookSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Webhooks.GooglePlay.cs"));
        var stripeGatewayHelpersSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "Payments",
            "StripePaymentGateway.Helpers.cs"));
        var webhookParserSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "Payments",
            "EconomyWebhookParser.cs"));

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(eventId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(paymentIntentId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(stripeCustomerId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("internal static string? SafeUserId(Guid? userId)", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(userId.Value.ToString(\"D\"))", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("UserIdHash={UserIdHash}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeUserId(userId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeUserId(order.UserId)", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("UserId={UserId}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EventIdSafe={EventIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("PaymentIntentIdSafe={PaymentIntentIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("StripeCustomerIdSafe={StripeCustomerIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate())", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("EventId={EventId}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("PaymentIntentId={PaymentIntentId}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("StripeCustomerId={StripeCustomerId}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", economyServiceSource, StringComparison.Ordinal);
        Assert.Contains("CurrentCorrelationIdHash", economyServiceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", economyServiceSource, StringComparison.Ordinal);
        Assert.Contains("OrderIdHash={OrderIdHash}", paymentsAndCheckoutSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(order.Id.ToString(\"D\"))", paymentsAndCheckoutSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", paymentsAndCheckoutSource, StringComparison.Ordinal);
        Assert.DoesNotContain("OrderId={OrderId}", paymentsAndCheckoutSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", paymentsAndCheckoutSource, StringComparison.Ordinal);
        Assert.Contains("internal static string? SafeExternalId(string? value)", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("internal static string? SafePaymentIntentId(string? externalPaymentId)", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("var safeAppStoreEventId = EconomyLogSanitizer.SafeExternalId(parsed.EventId)", appStoreWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogStoreWebhookReceived(\"app_store\", safeAppStoreEventId", appStoreWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogDuplicateStoreWebhook(\"app_store\", parsed.EventId", appStoreWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogStoreWebhookProcessed(\"app_store\", parsed.EventId", appStoreWebhookSource, StringComparison.Ordinal);
        Assert.Contains("var safeGooglePlayEventId = EconomyLogSanitizer.SafeExternalId(parsed.EventId)", googlePlayWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogStoreWebhookReceived(\"google_play\", safeGooglePlayEventId", googlePlayWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogDuplicateStoreWebhook(\"google_play\", parsed.EventId", googlePlayWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogStoreWebhookProcessed(\"google_play\", parsed.EventId", googlePlayWebhookSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalCustomerId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalSetupId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("OrderIdHash={OrderIdHash}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(orderId.Value.ToString(\"D\"))", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("ExternalCustomerIdSafe={ExternalCustomerIdSafe}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("ExternalPaymentIdSafe={ExternalPaymentIdSafe}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("ExternalPaymentMethodIdSafe={ExternalPaymentMethodIdSafe}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("ExternalSetupIdSafe={ExternalSetupIdSafe}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("OrderId={OrderId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalCustomerId={ExternalCustomerId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalPaymentId={ExternalPaymentId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalPaymentMethodId={ExternalPaymentMethodId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalSetupId={ExternalSetupId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("BuildGooglePlayFallbackEventId(purchaseToken, notificationType, \"sub\")", webhookParserSource, StringComparison.Ordinal);
        Assert.Contains("BuildGooglePlayFallbackEventId(purchaseToken, notificationType, \"one_time\")", webhookParserSource, StringComparison.Ordinal);
        Assert.DoesNotContain("\":{notificationType}:sub\"", webhookParserSource, StringComparison.Ordinal);
        Assert.DoesNotContain("\":{notificationType}:one_time\"", webhookParserSource, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyStructuredErrorCodeLogs_ShouldUseSafeCodes()
    {
        Assert.Equal("economy.payment_failed", EconomyLogSanitizer.SafeErrorCode(" economy.payment_failed "));
        Assert.Equal(EconomyLogSanitizer.UnknownErrorCode, EconomyLogSanitizer.SafeErrorCode(null));
        Assert.Equal(EconomyLogSanitizer.UnknownErrorCode, EconomyLogSanitizer.SafeErrorCode(" "));
        Assert.Equal(
            EconomyLogSanitizer.UnknownErrorCode,
            EconomyLogSanitizer.SafeErrorCode("economy.payment_failed token=provider-secret"));
        Assert.Equal(
            EconomyLogSanitizer.UnknownErrorCode,
            EconomyLogSanitizer.SafeErrorCode("economy.payment_failed api_secret=provider-secret"));

        var root = FindRepositoryRoot();
        var loggingSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Logging.cs"));
        var reconciliationWorkerSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyReconciliationWorker.cs"));
        var normalizedLoggingSource = loggingSource.Replace("\r\n", "\n", StringComparison.Ordinal);
        var normalizedReconciliationWorkerSource = reconciliationWorkerSource.Replace("\r\n", "\n", StringComparison.Ordinal);

        Assert.Contains("EconomyLogSanitizer.SafeErrorCode(error.Code)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeErrorCode(result.Error.Code)", reconciliationWorkerSource, StringComparison.Ordinal);
        Assert.DoesNotContain("\n            error.Code,\n", normalizedLoggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("\n                    result.Error.Code);", normalizedReconciliationWorkerSource, StringComparison.Ordinal);
    }

    [Fact]
    public void StoreVerificationLogs_ShouldMaskPurchaseIdentifiers_AndAvoidRawPayloadLogging()
    {
        var root = FindRepositoryRoot();
        var googlePlaySource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "Payments",
            "StoreSubscriptionVerifier.GooglePlay.cs"));
        var appStoreSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "Payments",
            "StoreSubscriptionVerifier.AppStore.cs"));

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(request.PurchaseId)", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("PurchaseIdSafe={PurchaseIdSafe}", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("DescribeGooglePlayVerificationData(request.ServerVerificationData)", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(request.PurchaseId)", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("PurchaseIdSafe={PurchaseIdSafe}", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("DescribeAppStoreVerificationData(request.ServerVerificationData)", appStoreSource, StringComparison.Ordinal);
        Assert.DoesNotContain("PurchaseId={PurchaseId}", googlePlaySource, StringComparison.Ordinal);
        Assert.DoesNotContain("PurchaseId={PurchaseId}", appStoreSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", googlePlaySource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", appStoreSource, StringComparison.Ordinal);
        Assert.DoesNotContain("logger?.LogWarning(\r\n                ex,", googlePlaySource, StringComparison.Ordinal);
        Assert.DoesNotContain("logger?.LogWarning(\r\n                ex,", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(ex)", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(ex)", appStoreSource, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyPaymentProviderJsonReads_ShouldBeBounded()
    {
        var root = FindRepositoryRoot();
        foreach (var relativePath in new[]
        {
            Path.Combine("src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Payments", "StripePaymentGateway.Helpers.cs"),
            Path.Combine("src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Payments", "StoreSubscriptionVerifier.GooglePlay.cs"),
            Path.Combine("src", "Modules", "Economy", "PetMagic.Modules.Economy.Infrastructure", "Payments", "StoreSubscriptionVerifier.AppStore.cs")
        })
        {
            var source = File.ReadAllText(Path.Combine(root, relativePath));

            Assert.Contains("HttpCompletionOption.ResponseHeadersRead", source, StringComparison.Ordinal);
            Assert.True(
                source.Contains("SafeHttpContentReader.ReadStringPrefixAsync(", StringComparison.Ordinal)
                || source.Contains("SafeHttpContentReader.ReadRawStringPrefixAsync(", StringComparison.Ordinal)
                || source.Contains("ReadProviderJsonAsync(response.Content, cancellationToken)", StringComparison.Ordinal));
            Assert.DoesNotContain("JsonDocument.ParseAsync(stream", source, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void PremiumVerificationAndCancellationLogs_ShouldAvoidRawStripeIdentifiers()
    {
        var root = FindRepositoryRoot();
        var premiumVerificationSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PremiumVerification.cs"));
        var subscriptionManagementSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PremiumSubscriptionManagement.cs"));
        var entitlementReconciliationSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PremiumEntitlementReconciliation.cs"));
        var purchaseVerificationSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PurchaseVerification.cs"));
        var storeReceiptFreshnessSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.StoreReceiptFreshness.cs"));
        var subscriptionAllowanceSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.SubscriptionAllowance.cs"));
        var stripeWebhookSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Webhooks.Stripe.cs"));
        var loggingSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Logging.cs"));
        var stripeGatewayHelpersSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "Payments",
            "StripePaymentGateway.Helpers.cs"));

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(normalizedSubscriptionId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(stripeSubscription.CustomerId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(customer.ExternalCustomerId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeUserId(command.UserId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("SubscriptionIdSafe={SubscriptionIdSafe}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("CustomerIdSafe={CustomerIdSafe}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("ExpectedCustomerIdSafe={ExpectedCustomerIdSafe}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("ExpectedPriceIdSafe={ExpectedPriceIdSafe}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("UserIdHash={UserIdHash}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("SubscriptionId={SubscriptionId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CustomerId={CustomerId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExpectedCustomerId={ExpectedCustomerId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("ExpectedPriceId={ExpectedPriceId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("user {UserId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("UserId={UserId}", premiumVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", premiumVerificationSource, StringComparison.Ordinal);

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId)", subscriptionManagementSource, StringComparison.Ordinal);
        Assert.Contains("SubscriptionIdSafe={SubscriptionIdSafe}", subscriptionManagementSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", subscriptionManagementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("SubscriptionId={SubscriptionId}", subscriptionManagementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", subscriptionManagementSource, StringComparison.Ordinal);

        Assert.Contains("UserIdHash={UserIdHash}", entitlementReconciliationSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", entitlementReconciliationSource, StringComparison.Ordinal);
        Assert.Contains("CurrentCorrelationIdHash", entitlementReconciliationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("UserId={UserId}", entitlementReconciliationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", entitlementReconciliationSource, StringComparison.Ordinal);

        Assert.Contains("OrderIdHash={OrderIdHash}", purchaseVerificationSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(order.Id.ToString(\"D\"))", purchaseVerificationSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(confirmResult.Value.Id.ToString(\"D\"))", purchaseVerificationSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", purchaseVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("OrderId={OrderId}", purchaseVerificationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", purchaseVerificationSource, StringComparison.Ordinal);

        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", storeReceiptFreshnessSource, StringComparison.Ordinal);
        Assert.Contains("CurrentCorrelationIdHash", storeReceiptFreshnessSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", storeReceiptFreshnessSource, StringComparison.Ordinal);

        Assert.Contains("SubscriptionIdHash={SubscriptionIdHash}", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(subscription.Id.ToString(\"D\"))", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("SubscriptionId={SubscriptionId}", subscriptionAllowanceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", subscriptionAllowanceSource, StringComparison.Ordinal);

        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", stripeWebhookSource, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", stripeWebhookSource, StringComparison.Ordinal);

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(eventId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(paymentIntentId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(stripeCustomerId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EventIdSafe={EventIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("PaymentIntentIdSafe={PaymentIntentIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("StripeCustomerIdSafe={StripeCustomerIdSafe}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("EventId={EventId}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("PaymentIntentId={PaymentIntentId}", loggingSource, StringComparison.Ordinal);
        Assert.DoesNotContain("StripeCustomerId={StripeCustomerId}", loggingSource, StringComparison.Ordinal);
        Assert.Contains("LogPaymentWebhookReceived(", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogPaymentWebhookProcessed(", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("LogDuplicatePaymentWebhook(", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("parsedEvent.ObjectId", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("parsedEvent.CustomerId", stripeWebhookSource, StringComparison.Ordinal);
        Assert.DoesNotContain("logger?.LogWarning(\r\n            exception,", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(exception)", stripeGatewayHelpersSource, StringComparison.Ordinal);
    }

    [Fact]
    public void EconomyInfrastructureLogs_ShouldNotSerializeRawExceptions()
    {
        var root = FindRepositoryRoot();
        var infrastructureRoot = Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure");
        var sourceFiles = Directory
            .EnumerateFiles(infrastructureRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}Data{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .Order(StringComparer.Ordinal)
            .ToArray();

        Assert.NotEmpty(sourceFiles);

        foreach (var sourceFile in sourceFiles)
        {
            var source = File.ReadAllText(sourceFile);
            Assert.DoesNotContain("UserId={UserId}", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogWarning(\r\n                ex,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogWarning(\r\n                    ex,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogWarning(\r\n                exception,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogWarning(\r\n                    exception,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogError(\r\n                ex,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogError(\r\n                    ex,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogError(\r\n                exception,", source, StringComparison.Ordinal);
            Assert.DoesNotContain("LogError(\r\n                    exception,", source, StringComparison.Ordinal);
        }

        var premiumPlansHealthCheckSource = File.ReadAllText(Path.Combine(
            infrastructureRoot,
            "PremiumSubscriptionPlansHealthCheck.cs"));
        Assert.DoesNotContain("HealthCheckResult.Unhealthy(\r\n                \"Failed to verify SubscriptionPlans premium catalog coverage.\",\r\n                exception)", premiumPlansHealthCheckSource, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(exception)", premiumPlansHealthCheckSource, StringComparison.Ordinal);
    }

    private static string ReadEconomyInfrastructureSource(string root, string fileName)
    {
        return File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            fileName));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
