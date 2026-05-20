namespace PetMagic.Modules.Economy.Infrastructure.Options;

public sealed class EconomyOptions
{
    public const string SectionName = "Economy";

    public int WeeklyFreeSpark { get; init; } = 100;

    public int WeeklyPremiumSpark { get; init; } = 250;

    public int AdRewardSpark { get; init; } = 15;

    public int AdRewardDailyLimit { get; init; } = 5;

    public string StripeSecretKey { get; init; } = string.Empty;

    public string StripeWebhookSecret { get; init; } = string.Empty;

    public string StripeCheckoutSuccessUrl { get; init; } = "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}";

    public string StripeCheckoutCancelUrl { get; init; } = "https://petmagic.app/payments/cancel";

    public string StripeBillingPortalReturnUrl { get; init; } = "https://petmagic.app/profile/premium";

    public string GooglePlayPackageName { get; init; } = "com.petmagic.app";

    public string GooglePlayServiceAccountEmail { get; init; } = string.Empty;

    public string GooglePlayPrivateKeyPem { get; init; } = string.Empty;

    public string AppStoreBundleId { get; init; } = "com.petmagic.app";

    public string AppStoreSharedSecret { get; init; } = string.Empty;
}
