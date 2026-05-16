namespace PetMagic.Modules.Economy.Infrastructure.Options;

public sealed class EconomyOptions
{
    public const string SectionName = "Economy";

    public int WeeklyFreeSpark { get; init; } = 100;

    public int WeeklyPremiumSpark { get; init; } = 250;

    public int AdRewardSpark { get; init; } = 15;

    public int AdRewardDailyLimit { get; init; } = 5;

    public string StripeSecretKey { get; init; } = "sk_test_change_me";

    public string StripeWebhookSecret { get; init; } = "whsec_dev_change_me";

    public string StripeCheckoutSuccessUrl { get; init; } = "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}";

    public string StripeCheckoutCancelUrl { get; init; } = "https://petmagic.app/payments/cancel";
}
