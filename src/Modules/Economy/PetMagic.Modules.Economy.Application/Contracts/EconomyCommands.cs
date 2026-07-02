namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record ClaimWeeklyGrantCommand(Guid UserId, bool IsPremium);

public sealed record ClaimAdRewardCommand(Guid UserId);

public sealed record SpendBalanceCommand(Guid UserId, int Amount, string Reason, string? Source = null);

public sealed record CreditBalanceCommand(
    Guid UserId,
    int Amount,
    string Source,
    string Reason,
    string? IdempotencyKey = null);

public sealed record CreatePackPurchaseCommand(
    Guid UserId,
    Guid PackId,
    string CurrencyCode,
    string PaymentProvider,
    string Platform,
    string AppVersion,
    string Country,
    string Locale,
    Guid? PaymentMethodId = null);

public sealed record CreatePremiumCheckoutCommand(
    Guid UserId,
    string PlanCode,
    string PaymentProvider,
    string Platform,
    string AppVersion,
    string Country,
    string Locale);

public sealed record CreatePremiumBillingPortalCommand(Guid UserId, string PaymentProvider);

public sealed record CancelPremiumSubscriptionCommand(Guid UserId, string PaymentProvider);

public sealed record AdminRevokePremiumSubscriptionCommand(Guid UserId, string PaymentProvider);

public sealed record AdminRefundPurchaseCommand(Guid OrderId, string? Reason = null);

public sealed record VerifyPremiumStorePurchaseCommand(
    Guid UserId,
    string PlanCode,
    string PaymentProvider,
    string ProductId,
    string ServerVerificationData,
    string? LocalVerificationData,
    string? PurchaseId,
    string? TransactionDate);

public sealed record VerifyPremiumStripeSubscriptionCommand(
    Guid UserId,
    string PlanCode,
    string ExternalSubscriptionId);

public sealed record VerifyPackStorePurchaseCommand(
    Guid UserId,
    Guid OrderId,
    string PaymentProvider,
    string ProductId,
    string ServerVerificationData,
    string? LocalVerificationData,
    string? PurchaseId,
    string? TransactionDate);

public sealed record ValidateGooglePlayBillingCommand(
    Guid UserId,
    string PurchaseToken,
    string ProductId,
    string PackageName);

public sealed record ValidateAppleAppStoreBillingCommand(
    Guid UserId,
    string SignedTransactionInfo);

public sealed record CreatePaymentMethodSetupCommand(Guid UserId, string PaymentProvider);

public sealed record RemovePaymentMethodCommand(Guid UserId, Guid PaymentMethodId);

public sealed record ApplyRedeemCodeCommand(Guid UserId, string Code);

public sealed record ApplyReferralCodeCommand(Guid UserId, string Code);

public sealed record CreateRedeemCodeCommand(
    string Code,
    string Description,
    string RewardKind,
    int RewardValue,
    int MaxRedemptions,
    int MaxRedemptionsPerUser,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc,
    string? CampaignName = null,
    string? CampaignChannel = null,
    int MinimumSuccessfulPurchases = 0,
    string? CreatedBy = null);

public sealed record UpdateRedeemCodeCommand(
    Guid RedeemCodeId,
    string Description,
    string RewardKind,
    int RewardValue,
    int MaxRedemptions,
    int MaxRedemptionsPerUser,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc,
    string? CampaignName = null,
    string? CampaignChannel = null,
    int MinimumSuccessfulPurchases = 0,
    string? CreatedBy = null);

public sealed record UpdateCurrencyPackCommand(
    Guid PackId,
    string DisplayName,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    bool IsActive,
    int SortOrder);

public sealed record UpdateSubscriptionPlanCommand(
    string PlanId,
    string Name,
    decimal PriceAmount,
    string CurrencyCode,
    int MonthlyTokenLimit,
    bool IsRecommended,
    bool IsActive,
    string? AppleProductId,
    string? GoogleProductId,
    string? StripePriceId,
    int DisplayOrder);

public sealed record UpdatePaymentProviderConfigurationCommand(
    Guid ConfigurationId,
    string Region,
    bool IsEnabled,
    bool IsRecommended,
    bool IsSelectedByDefault,
    bool RequiresExternalWarning,
    bool RequiresStoreDisclosure,
    string AllowedFromAppVersion,
    bool ExternalCheckoutAllowed,
    int BonusTokensPercent,
    string? DisplayLabel,
    string? DisplaySubtitle,
    string? WarningTitle,
    string? WarningMessage,
    string Mode,
    string? Notes);

public sealed record CreatePaymentProviderConfigurationCommand(
    string Provider,
    string Platform,
    string Region,
    bool IsEnabled,
    bool IsRecommended,
    bool IsSelectedByDefault,
    bool RequiresExternalWarning,
    bool RequiresStoreDisclosure,
    string AllowedFromAppVersion,
    bool ExternalCheckoutAllowed,
    int BonusTokensPercent,
    string? DisplayLabel,
    string? DisplaySubtitle,
    string? WarningTitle,
    string? WarningMessage,
    string Mode,
    string? Notes);

public sealed record ClonePaymentProviderConfigurationCommand(
    Guid SourceConfigurationId,
    string Region);

public sealed record DeletePaymentProviderConfigurationCommand(Guid ConfigurationId);

public sealed record StripeWebhookCommand(string RawBody, string StripeSignature);

public sealed record AppStoreServerNotificationCommand(string SignedPayload);

public sealed record GooglePlayDeveloperNotificationCommand(string MessageData, string? MessageId);

public sealed record RegisterEconomyPushTokenCommand(
    Guid UserId,
    string Token,
    string Platform,
    string? DeviceId,
    string? AppVersion,
    string? Locale);

public sealed record UnregisterEconomyPushTokenCommand(Guid UserId, string Token);
