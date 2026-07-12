namespace PetMagic.Modules.Economy.Infrastructure.Options;

public sealed class EconomyOptions
{
    public const string SectionName = "Economy";

    public int WeeklyFreeSpark { get; init; } = 100;

    public int WeeklyPremiumSpark { get; init; } = 40;

    public int AdRewardSpark { get; init; } = 15;

    public int AdRewardDailyLimit { get; init; } = 5;

    public int ReferralBonusSpark { get; init; } = 15;

    public string StripeTestSecretKey { get; init; } = string.Empty;

    public string StripeTestPublishableKey { get; init; } = string.Empty;

    public string StripeLiveSecretKey { get; init; } = string.Empty;

    public string StripeLivePublishableKey { get; init; } = string.Empty;

    public string StripeTestWebhookSecret { get; init; } = string.Empty;

    public string StripeLiveWebhookSecret { get; init; } = string.Empty;

    public string StripeCheckoutSuccessUrl { get; init; } = "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}";

    public string StripeCheckoutCancelUrl { get; init; } = "https://petmagic.app/payments/cancel";

    public string StripeBillingPortalReturnUrl { get; init; } = "https://petmagic.app/profile/premium";

    public string GooglePlayPackageName { get; init; } = "com.petmagic.app";

    public string GooglePlayPremiumMonthlyProductId { get; init; } = "com.petmagic.app.premium.monthly";

    public string GooglePlayPremiumYearlyProductId { get; init; } = "com.petmagic.app.premium.yearly";

    public string GooglePlayServiceAccountEmail { get; init; } = string.Empty;

    public string GooglePlayPrivateKeyPem { get; init; } = string.Empty;

    public string GooglePlayPubSubAudience { get; init; } = string.Empty;

    public string GooglePlayPubSubExpectedEmail { get; init; } = string.Empty;

    public string GooglePlayEnvironment { get; init; } = "production";

    public string AppStoreBundleId { get; init; } = "com.petmagic.app";

    public string AppStorePremiumMonthlyProductId { get; init; } = "com.petmagic.app.premium.monthly";

    public string AppStorePremiumYearlyProductId { get; init; } = "com.petmagic.app.premium.yearly";

    public string AppStoreSharedSecret { get; init; } = string.Empty;

    public string AppStoreEnvironment { get; init; } = "production";

    public int MaxStoreReceiptAgeHours { get; init; } = 24;

    public string StoreAccountBindingMode { get; init; } = "compatibility";

    public bool EconomyReconciliationEnabled { get; init; } = true;

    public int EconomyReconciliationIntervalMinutes { get; init; } = 15;

    public int EconomyReconciliationPendingOrderMinutes { get; init; } = 30;

    public int EconomyReconciliationLookbackDays { get; init; } = 30;

    public int EconomyReconciliationRetryDelayMinutes { get; init; } = 30;

    public bool FirebasePushEnabled { get; init; }

    public string FirebaseProjectId { get; init; } = string.Empty;

    public string FirebaseServiceAccountJson { get; init; } = string.Empty;

    public string FirebaseServiceAccountJsonPath { get; init; } = string.Empty;

    public bool PushOutboxDispatcherEnabled { get; init; } = true;

    public bool IsFirebasePushConfigured =>
        FirebasePushEnabled
        && !string.IsNullOrWhiteSpace(FirebaseProjectId)
        && (!string.IsNullOrWhiteSpace(FirebaseServiceAccountJson)
            || !string.IsNullOrWhiteSpace(FirebaseServiceAccountJsonPath));
}
