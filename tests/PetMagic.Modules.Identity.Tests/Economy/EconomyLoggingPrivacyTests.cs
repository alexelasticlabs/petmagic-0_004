namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyLoggingPrivacyTests
{
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

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(eventId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(paymentIntentId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(stripeCustomerId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafePaymentIntentId(order.ExternalPaymentId)", loggingSource, StringComparison.Ordinal);
        Assert.Contains("internal static string? SafeExternalId(string? value)", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("internal static string? SafePaymentIntentId(string? externalPaymentId)", sanitizerSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(parsed.EventId)", appStoreWebhookSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(parsed.EventId)", googlePlayWebhookSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalCustomerId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalPaymentMethodId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(externalSetupId)", stripeGatewayHelpersSource, StringComparison.Ordinal);
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
        Assert.Contains("DescribeGooglePlayVerificationData(request.ServerVerificationData)", googlePlaySource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(request.PurchaseId)", appStoreSource, StringComparison.Ordinal);
        Assert.Contains("DescribeAppStoreVerificationData(request.ServerVerificationData)", appStoreSource, StringComparison.Ordinal);
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
        var stripeWebhookSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Webhooks.Stripe.cs"));

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(normalizedSubscriptionId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(stripeSubscription.CustomerId)", premiumVerificationSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(customer.ExternalCustomerId)", premiumVerificationSource, StringComparison.Ordinal);

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(subscription.ExternalSubscriptionId)", subscriptionManagementSource, StringComparison.Ordinal);

        Assert.Contains("EconomyLogSanitizer.SafeExternalId(eventId)", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(parsedEvent.ObjectId)", stripeWebhookSource, StringComparison.Ordinal);
        Assert.Contains("EconomyLogSanitizer.SafeExternalId(parsedEvent.CustomerId)", stripeWebhookSource, StringComparison.Ordinal);
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
