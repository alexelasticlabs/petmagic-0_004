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
    public void SpendBalanceValidator_ShouldFail_WhenAmountInvalid()
    {
        var validator = new SpendBalanceCommandValidator();
        var result = validator.Validate(new SpendBalanceCommand(Guid.NewGuid(), 0, "video_generation"));

        Assert.False(result.IsValid);
    }

    [Fact]
    public void SpendBalanceValidator_ShouldPass_WhenPayloadValid()
    {
        var validator = new SpendBalanceCommandValidator();
        var result = validator.Validate(new SpendBalanceCommand(Guid.NewGuid(), 60, "video_generation"));

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
    public void ConfirmPackPurchaseValidator_ShouldPass_WhenPayloadValid()
    {
        var validator = new ConfirmPackPurchaseCommandValidator();
        var result = validator.Validate(new ConfirmPackPurchaseCommand(Guid.NewGuid(), Guid.NewGuid()));

        Assert.True(result.IsValid);
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
    public void StripeWebhookValidator_ShouldFail_WhenSignatureEmpty()
    {
        var validator = new StripeWebhookCommandValidator();
        var result = validator.Validate(new StripeWebhookCommand("{}", string.Empty));

        Assert.False(result.IsValid);
    }
}
