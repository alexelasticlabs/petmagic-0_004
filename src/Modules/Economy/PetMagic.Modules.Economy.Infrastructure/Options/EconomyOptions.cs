namespace PetMagic.Modules.Economy.Infrastructure.Options;

public sealed class EconomyOptions
{
    public const string SectionName = "Economy";

    public int WeeklyFreeSpark { get; init; } = 100;

    public int WeeklyPremiumSpark { get; init; } = 40;

    public int AdRewardSpark { get; init; } = 15;

    public int AdRewardDailyLimit { get; init; } = 5;

    public int ReferralBonusSpark { get; init; } = 15;

    public string StripeSecretKey { get; init; } = string.Empty;

    public string StripePublishableKey { get; init; } = string.Empty;

    public string StripeTestSecretKey { get; init; } = string.Empty;

    public string StripeTestPublishableKey { get; init; } = string.Empty;

    public string StripeLiveSecretKey { get; init; } = string.Empty;

    public string StripeLivePublishableKey { get; init; } = string.Empty;

    public string StripeWebhookSecret { get; init; } = string.Empty;

    public string StripeTestWebhookSecret { get; init; } = string.Empty;

    public string StripeLiveWebhookSecret { get; init; } = string.Empty;

    public string StripeCheckoutSuccessUrl { get; init; } = "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}";

    public string StripeCheckoutCancelUrl { get; init; } = "https://petmagic.app/payments/cancel";

    public string StripeBillingPortalReturnUrl { get; init; } = "https://petmagic.app/profile/premium";

    public string GooglePlayPackageName { get; init; } = "com.petmagic.app";

    public string GooglePlayServiceAccountEmail { get; init; } = string.Empty;

    public string GooglePlayPrivateKeyPem { get; init; } = string.Empty;

    public string GooglePlayPubSubAudience { get; init; } = string.Empty;

    public string GooglePlayPubSubExpectedEmail { get; init; } = string.Empty;

    public string GooglePlayEnvironment { get; init; } = "production";

    public string AppStoreBundleId { get; init; } = "com.petmagic.app";

    public string AppStoreSharedSecret { get; init; } = string.Empty;

    public string AppStoreEnvironment { get; init; } = "production";

    public bool FirebasePushEnabled { get; init; }

    public string FirebaseProjectId { get; init; } = string.Empty;

    public string FirebaseServiceAccountJson { get; init; } = string.Empty;

    public string FirebaseServiceAccountJsonPath { get; init; } = string.Empty;

    public bool IsFirebasePushConfigured =>
        FirebasePushEnabled
        && !string.IsNullOrWhiteSpace(FirebaseProjectId)
        && (!string.IsNullOrWhiteSpace(FirebaseServiceAccountJson)
            || !string.IsNullOrWhiteSpace(FirebaseServiceAccountJsonPath));
}
