using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Infrastructure;

public static class EconomyErrors
{
    public static readonly Error WeeklyGrantCooldown = new("economy.weekly_cooldown", "Weekly reward is not available yet.");

    public static readonly Error AdRewardLimitReached = new("economy.ad_reward_limit_reached", "Daily ad reward limit reached.");

    public static readonly Error InsufficientBalance = new("economy.insufficient_balance", "Not enough PawSpark balance.");

    public static readonly Error InvalidAmount = new("economy.invalid_amount", "Wallet amount must be greater than zero.");

    public static readonly Error InvalidSubject = new("economy.invalid_subject", "Invalid access token subject.");

    public static readonly Error CurrencyPackNotFound = new("economy.pack_not_found", "Currency pack was not found.");

    public static readonly Error PurchaseNotFound = new("economy.purchase_not_found", "Purchase order was not found.");

    public static readonly Error PurchaseAlreadyProcessed = new("economy.purchase_already_processed", "Purchase order is already processed.");

    public static readonly Error PurchaseNotRefundable = new("economy.purchase_not_refundable", "Purchase order cannot be refunded.");

    public static readonly Error UnsupportedPaymentProvider = new("economy.payment_provider_unsupported", "Payment provider is not supported.");

    public static readonly Error PaymentProviderUnavailable = new("economy.payment_provider_unavailable", "Payment provider is not available for this platform, region, or app version.");

    public static readonly Error InvalidStripeSignature = new("economy.invalid_stripe_signature", "Stripe signature is invalid.");

    public static readonly Error InvalidStoreWebhookSignature = new("economy.invalid_store_webhook_signature", "Store webhook signature is invalid.");

    public static readonly Error InvalidWebhookPayload = new("economy.invalid_webhook_payload", "Webhook payload is invalid.");

    public static readonly Error PaymentGatewayFailed = new("economy.payment_gateway_failed", "Payment gateway call failed.");

    public static readonly Error PremiumPlanNotFound = new("economy.premium_plan_not_found", "Premium plan was not found.");

    public static readonly Error PaymentProviderConfigurationNotFound = new("economy.payment_provider_config_not_found", "Payment provider configuration was not found.");

    public static readonly Error PaymentProviderConfigurationAlreadyExists = new("economy.payment_provider_config_exists", "Payment provider configuration already exists for this provider, platform, and region.");

    public static readonly Error PaymentProviderDisclosureInvalid = new("economy.payment_provider_disclosure_invalid", "Payment provider disclosures must not reference deprecated external Stripe checkout copy.");

    public static readonly Error PremiumBillingUnavailable = new("economy.premium_billing_unavailable", "Premium billing is not available right now.");

    public static readonly Error StoreVerificationUnavailable = new("economy.store_verification_unavailable", "Store subscription verification is not configured.");

    public static readonly Error StorePurchaseInvalid = new("economy.store_purchase_invalid", "Store subscription purchase is invalid.");

    public static readonly Error StorePurchaseInactive = new("economy.store_purchase_inactive", "Store subscription is not active.");

    public static readonly Error PaymentMethodNotFound = new("economy.payment_method_not_found", "Payment method was not found.");
    public static readonly Error PaymentMethodProviderInvalid = new("economy.payment_method_provider_invalid", "Saved payment methods are only supported for Stripe purchases.");
    public static readonly Error PaymentMethodOwnershipConflict = new("economy.payment_method_ownership_conflict", "Payment method is already linked to a different user.");
    public static readonly Error SubscriptionOwnershipConflict = new("economy.subscription_ownership_conflict", "Subscription is already linked to a different user.");

    public static readonly Error RedeemCodeNotFound = new("economy.redeem_code_not_found", "Redeem code was not found.");

    public static readonly Error RedeemCodeInactive = new("economy.redeem_code_inactive", "Redeem code is not active.");

    public static readonly Error RedeemCodeExpired = new("economy.redeem_code_expired", "Redeem code is expired.");

    public static readonly Error RedeemCodeAlreadyUsed = new("economy.redeem_code_already_used", "Redeem code was already used by this user.");

    public static readonly Error RedeemCodeUserLimitReached = new("economy.redeem_code_user_limit_reached", "Redeem code is no longer available for this user.");

    public static readonly Error RedeemCodePurchaseRequirementNotMet = new("economy.redeem_code_purchase_requirement_not_met", "Redeem code requires a paid purchase history.");

    public static readonly Error RedeemCodeExhausted = new("economy.redeem_code_exhausted", "Redeem code redemption limit reached.");

    public static readonly Error RedeemCodeAlreadyExists = new("economy.redeem_code_exists", "Redeem code already exists.");

    public static readonly Error RedeemCodeRewardUnsupported = new("economy.redeem_code_reward_unsupported", "Redeem code reward is not supported.");

    public static readonly Error ReferralCodeNotFound = new("economy.referral_code_not_found", "Referral code was not found.");

    public static readonly Error ReferralSelfReferral = new("economy.referral_self_referral", "Users cannot activate their own referral code.");

    public static readonly Error ReferralAlreadyLinked = new("economy.referral_already_linked", "Referral code is already activated for this user.");

    public static readonly Error ReferralPaidUserIneligible = new("economy.referral_paid_user_ineligible", "Referral code must be activated before the first paid purchase.");

    public static readonly Error InvalidPushToken = new("economy.push_token_invalid", "Economy push token is invalid.");
}
