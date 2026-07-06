using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class EconomyValidatorsTests
{
    [Fact]
    public void ClaimWeeklyGrantValidator_ShouldFail_WhenUserIdEmpty()
    {
        var validator = new ClaimWeeklyGrantCommandValidator();
        var result = validator.Validate(new ClaimWeeklyGrantCommand(Guid.Empty, false));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void ClaimAdRewardValidator_ShouldPass_WhenUserIdValid()
    {
        var validator = new ClaimAdRewardCommandValidator();
        var result = validator.Validate(new ClaimAdRewardCommand(Guid.NewGuid()));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void CreatePackPurchaseValidator_ShouldFail_WhenCurrencyInvalid()
    {
        var validator = new CreatePackPurchaseCommandValidator();
        var result = validator.Validate(new CreatePackPurchaseCommand(Guid.NewGuid(), Guid.NewGuid(), "US", "stripe", "web", "1.0.0", "*", "en"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePackPurchaseValidator_ShouldFail_WhenProviderUnsupported()
    {
        var validator = new CreatePackPurchaseCommandValidator();
        var result = validator.Validate(new CreatePackPurchaseCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "USD",
            "paypal",
            "android",
            "1.0.0",
            "US",
            "en"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePackPurchaseValidator_ShouldFail_WhenSavedPaymentMethodUsedWithStoreProvider()
    {
        var validator = new CreatePackPurchaseCommandValidator();
        var result = validator.Validate(new CreatePackPurchaseCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "USD",
            "google_play",
            "android",
            "1.0.0",
            "US",
            "en",
            Guid.NewGuid()));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void VerifyPremiumStorePurchaseValidator_ShouldFail_WhenVerificationDataMissing()
    {
        var validator = new VerifyPremiumStorePurchaseCommandValidator();
        var result = validator.Validate(new VerifyPremiumStorePurchaseCommand(
            Guid.NewGuid(),
            "yearly",
            "google_play",
            "com.petmagic.app.premium.yearly",
            string.Empty,
            null,
            "purchase-id",
            "1234567890"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void VerifyPremiumStorePurchaseValidator_ShouldPass_WhenPayloadValid()
    {
        var validator = new VerifyPremiumStorePurchaseCommandValidator();
        var result = validator.Validate(new VerifyPremiumStorePurchaseCommand(
            Guid.NewGuid(),
            "yearly",
            "google_play",
            "com.petmagic.app.premium.yearly",
            "token-123",
            "signed-payload",
            "purchase-id",
            "1234567890"));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void VerifyPackStorePurchaseValidator_ShouldPass_WhenPayloadValid()
    {
        var validator = new VerifyPackStorePurchaseCommandValidator();
        var result = validator.Validate(new VerifyPackStorePurchaseCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "app_store",
            "com.petmagic.app.tokens.apple.starter",
            "receipt-token",
            "signed-payload",
            "purchase-id",
            "1234567890"));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void StripeWebhookValidator_ShouldFail_WhenSignatureEmpty()
    {
        var validator = new StripeWebhookCommandValidator();
        var result = validator.Validate(new StripeWebhookCommand("{}", string.Empty));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePremiumCheckoutValidator_ShouldPass_WhenPlanCodeIsCustom()
    {
        var validator = new CreatePremiumCheckoutCommandValidator();
        var result = validator.Validate(new CreatePremiumCheckoutCommand(
            Guid.NewGuid(),
            "plan_pro_v2",
            "stripe",
            "android",
            "1.0.0",
            "US",
            "en"));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void CreatePremiumCheckoutValidator_ShouldFail_WhenProviderUnsupported()
    {
        var validator = new CreatePremiumCheckoutCommandValidator();
        var result = validator.Validate(new CreatePremiumCheckoutCommand(
            Guid.NewGuid(),
            "monthly",
            "paypal",
            "android",
            "1.0.0",
            "US",
            "en"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePremiumBillingPortalValidator_ShouldFail_WhenProviderUnsupported()
    {
        var validator = new CreatePremiumBillingPortalCommandValidator();
        var result = validator.Validate(new CreatePremiumBillingPortalCommand(
            Guid.NewGuid(),
            "google_play"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void CreatePaymentMethodSetupValidator_ShouldFail_WhenProviderUnsupported()
    {
        var validator = new CreatePaymentMethodSetupCommandValidator();
        var result = validator.Validate(new CreatePaymentMethodSetupCommand(
            Guid.NewGuid(),
            "app_store"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void UpdateSubscriptionPlanValidator_ShouldFail_WhenActivePlanMissingProviderIds()
    {
        var validator = new UpdateSubscriptionPlanCommandValidator();
        var result = validator.Validate(new UpdateSubscriptionPlanCommand(
            "monthly",
            "Monthly",
            14.99m,
            "USD",
            500,
            false,
            true,
            null,
            null,
            null,
            1));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void UpdateSubscriptionPlanValidator_ShouldPass_WhenActivePlanHasAllProviderIds()
    {
        var validator = new UpdateSubscriptionPlanCommandValidator();
        var result = validator.Validate(new UpdateSubscriptionPlanCommand(
            "yearly",
            "Yearly",
            99.99m,
            "USD",
            1000,
            true,
            true,
            "com.petmagic.app.premium.yearly",
            "com.petmagic.app.premium.yearly",
            "price_123",
            2));

        Assert.True(result.IsValid);
    }

    [Fact]
    public void CreatePaymentProviderConfigurationValidator_ShouldFail_WhenLegacyStripeDisclosureTextProvided()
    {
        var validator = new CreatePaymentProviderConfigurationCommandValidator();
        var result = validator.Validate(new CreatePaymentProviderConfigurationCommand(
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
            "This route uses external checkout."));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "WarningMessage");
        Assert.Contains(result.Errors, error => error.PropertyName == "Notes");
    }

    [Fact]
    public void UpdatePaymentProviderConfigurationValidator_ShouldFail_WhenLegacyStripeDisclosureTextProvided()
    {
        var validator = new UpdatePaymentProviderConfigurationCommandValidator();
        var result = validator.Validate(new UpdatePaymentProviderConfigurationCommand(
            Guid.NewGuid(),
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
            "This route uses external checkout."));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "WarningMessage");
        Assert.Contains(result.Errors, error => error.PropertyName == "Notes");
    }

    [Fact]
    public void CreatePaymentProviderConfigurationValidator_ShouldFail_WhenNativePaymentSheetCopyProvided()
    {
        var validator = new CreatePaymentProviderConfigurationCommandValidator();
        var result = validator.Validate(new CreatePaymentProviderConfigurationCommand(
            "stripe",
            "android",
            "*",
            true,
            true,
            true,
            true,
            true,
            "0.0.0",
            true,
            0,
            "Stripe",
            null,
            null,
            "Stripe billing is completed inside PetMagic with native payment sheet.",
            "test",
            "Secure hosted checkout."));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "WarningMessage");
    }
}
