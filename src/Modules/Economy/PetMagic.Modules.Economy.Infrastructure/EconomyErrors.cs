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

    public static readonly Error UnsupportedPaymentProvider = new("economy.payment_provider_unsupported", "Payment provider is not supported.");

    public static readonly Error InvalidStripeSignature = new("economy.invalid_stripe_signature", "Stripe signature is invalid.");

    public static readonly Error InvalidWebhookPayload = new("economy.invalid_webhook_payload", "Webhook payload is invalid.");

    public static readonly Error PaymentGatewayFailed = new("economy.payment_gateway_failed", "Payment gateway call failed.");
}
