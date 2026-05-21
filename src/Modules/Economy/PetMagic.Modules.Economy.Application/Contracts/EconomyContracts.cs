namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record ClaimWeeklyGrantCommand(Guid UserId, bool IsPremium);

public sealed record ClaimAdRewardCommand(Guid UserId);

public sealed record SpendBalanceCommand(Guid UserId, int Amount, string Reason);

public sealed record CreditBalanceCommand(Guid UserId, int Amount, string Source, string Reason);

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

public sealed record GetPaywallConfigQuery(string Platform, string AppVersion, string Country, string Locale);

public sealed record GetWalletCheckoutConfigQuery(string Platform, string AppVersion, string Country, string Locale);

public sealed record VerifyPremiumStorePurchaseCommand(
    Guid UserId,
    string PlanCode,
    string PaymentProvider,
    string ProductId,
    string ServerVerificationData,
    string? LocalVerificationData,
    string? PurchaseId,
    string? TransactionDate);

public sealed record ConfirmPackPurchaseCommand(Guid UserId, Guid OrderId);

public sealed record StripeWebhookCommand(string RawBody, string StripeSignature);

public sealed record AppStoreServerNotificationCommand(string SignedPayload);

public sealed record GooglePlayDeveloperNotificationCommand(string MessageData, string? MessageId);

public sealed record CreatePaymentMethodSetupCommand(Guid UserId, string PaymentProvider);

public sealed record RemovePaymentMethodCommand(Guid UserId, Guid PaymentMethodId);

public sealed record ApplyRedeemCodeCommand(Guid UserId, string Code);

public sealed record CreateRedeemCodeCommand(
    string Code,
    string Description,
    string RewardKind,
    int RewardValue,
    int MaxRedemptions,
    int MaxRedemptionsPerUser,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc);

public sealed record UpdateRedeemCodeCommand(
    Guid RedeemCodeId,
    string Description,
    string RewardKind,
    int RewardValue,
    int MaxRedemptions,
    int MaxRedemptionsPerUser,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc);

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

public sealed record OffsetPagedResponse<T>(
    IReadOnlyList<T> Items,
    int Skip,
    int Take,
    bool HasMore);

public sealed record WalletStateResponse(
    Guid UserId,
    int Balance,
    DateTime? NextWeeklyGrantAtUtc,
    int AdRewardsRemainingToday,
    bool IsPremium,
    DateTime UpdatedAtUtc);

public sealed record WalletOperationResponse(
    Guid UserId,
    int Delta,
    int NewBalance,
    string Source,
    DateTime OccurredAtUtc,
    DateTime? NextWeeklyGrantAtUtc,
    int AdRewardsRemainingToday);

public sealed record WalletLedgerItemResponse(
    Guid EntryId,
    Guid UserId,
    int Delta,
    int BalanceAfter,
    string Source,
    string Reason,
    DateTime CreatedAtUtc);

public sealed record RedeemCodeAppliedResponse(
    Guid RedeemCodeId,
    string RewardKind,
    int RewardValue,
    WalletOperationResponse? WalletOperation,
    DateTime? PremiumExpiresAtUtc);

public sealed record AdminRedeemCodeRedemptionResponse(
    Guid RedemptionId,
    Guid UserId,
    string RewardKind,
    int RewardValue,
    Guid? WalletLedgerEntryId,
    DateTime? PremiumExpiresAtUtc,
    DateTime RedeemedAtUtc);

public sealed record AdminRedeemCodeResponse(
    Guid RedeemCodeId,
    string Code,
    string CodePrefix,
    string Description,
    string RewardKind,
    int RewardValue,
    int MaxRedemptions,
    int MaxRedemptionsPerUser,
    int RedeemedCount,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    IReadOnlyList<AdminRedeemCodeRedemptionResponse> Redemptions);

public sealed record CurrencyPackResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    string CurrencyCode,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    int TotalSpark);

public sealed record WalletCheckoutConfigResponse(
    IReadOnlyList<CurrencyPackResponse> Packs,
    IReadOnlyList<PaywallPaymentMethodResponse> AvailablePaymentMethods,
    bool ExternalPaymentWarningRequired);

public sealed record PremiumPlanResponse(
    string PlanCode,
    string BillingInterval,
    decimal PriceAmount,
    decimal? CompareAtPriceAmount,
    string CurrencyCode,
    int TokenAllowance,
    bool IsPopular,
    int? DiscountPercent,
    int SortOrder,
    bool StripeCheckoutEnabled,
    string? GooglePlayProductId,
    string? AppStoreProductId);

public sealed record PremiumStatusResponse(
    bool IsPremium,
    bool CanManageBilling,
    string? PaymentProvider);

public sealed record SubscriptionSummaryResponse(
    bool IsPremium,
    string? Provider,
    string? PurchaseChannel,
    string Status,
    string? PlanName,
    string? BillingPeriod,
    DateTime? CurrentPeriodEndUtc,
    bool CancelAtPeriodEnd,
    int MonthlyTokenLimit,
    int TokensAvailable,
    bool CanManageSubscription,
    string ManageSubscriptionAction);

public sealed record PaywallPlanResponse(
    string PlanId,
    string Name,
    string BillingPeriod,
    decimal PriceAmount,
    string CurrencyCode,
    int MonthlyTokenLimit,
    bool IsRecommended,
    bool IsActive,
    string? AppleProductId,
    string? GoogleProductId,
    string? StripePriceId,
    int DisplayOrder,
    decimal? ApproxMonthlyPriceAmount,
    int? DiscountPercent);

public sealed record PaywallPaymentMethodResponse(
    string Provider,
    string PurchaseChannel,
    string Platform,
    string Region,
    bool IsEnabled,
    bool IsSelectedByDefault,
    bool RequiresExternalWarning,
    bool RequiresStoreDisclosure,
    bool IsRecommended,
    int BonusTokensPercent,
    string? DisplayLabel,
    string? DisplaySubtitle,
    string? WarningTitle,
    string? WarningMessage,
    string? Notes);

public sealed record PaywallLegalTextsResponse(
    string StoreNotice,
    string ExternalCheckoutNotice,
    string StripeNotice);

public sealed record PaywallConfigResponse(
    IReadOnlyList<PaywallPlanResponse> Plans,
    string? RecommendedPlan,
    IReadOnlyList<PaywallPaymentMethodResponse> AvailablePaymentMethods,
    PaywallLegalTextsResponse LegalTexts,
    bool ExternalPaymentWarningRequired);

public sealed record AdminCurrencyPackResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    string CurrencyCode,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    int TotalSpark,
    bool IsActive,
    int SortOrder);

public sealed record AdminSubscriptionPlanResponse(
    string PlanId,
    string Name,
    string BillingPeriod,
    decimal PriceAmount,
    string CurrencyCode,
    int MonthlyTokenLimit,
    bool IsRecommended,
    bool IsActive,
    string? AppleProductId,
    string? GoogleProductId,
    string? StripePriceId,
    int DisplayOrder,
    DateTime UpdatedAtUtc);

public sealed record AdminPaymentProviderConfigurationResponse(
    Guid ConfigurationId,
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
    string? Notes,
    DateTime UpdatedAtUtc);

public sealed record AdminUserSubscriptionResponse(
    Guid SubscriptionId,
    Guid UserId,
    string Provider,
    string PurchaseChannel,
    string Region,
    string PlanId,
    string? PlanName,
    string Status,
    DateTime? CurrentPeriodStartUtc,
    DateTime? CurrentPeriodEndUtc,
    bool CancelAtPeriodEnd,
    int MonthlyTokenLimit,
    int MonthlyTokensGranted,
    DateTime? LastTokenGrantAtUtc,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record AdminSubscriptionEventResponse(
    Guid EventId,
    Guid? UserId,
    Guid? UserSubscriptionId,
    string Provider,
    string EventType,
    string Status,
    string? ExternalEventId,
    string? ExternalSubscriptionId,
    DateTime CreatedAtUtc,
    DateTime? ProcessedAtUtc);

public sealed record PurchaseCheckoutResponse(
    Guid OrderId,
    Guid UserId,
    string PaymentProvider,
    string ExternalPaymentId,
    string CheckoutUrl,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    DateTime CreatedAtUtc);

public sealed record PurchaseOrderResponse(
    Guid OrderId,
    Guid UserId,
    Guid PackId,
    string PaymentProvider,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string? ExternalPaymentId,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);

public sealed record PurchaseHistoryItemResponse(
    Guid OrderId,
    Guid UserId,
    Guid PackId,
    string PackCode,
    string PackDisplayName,
    string PaymentProvider,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string? ExternalPaymentId,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);

public sealed record PaymentMethodResponse(
    Guid PaymentMethodId,
    string PaymentProvider,
    string Brand,
    string Last4,
    long? ExpMonth,
    long? ExpYear,
    bool IsDefault,
    DateTime CreatedAtUtc);

public sealed record PaymentMethodSetupResponse(
    string PaymentProvider,
    string ExternalSetupId,
    string CheckoutUrl);

public sealed record PremiumCheckoutResponse(
    string PaymentProvider,
    string CheckoutUrl,
    string Status);

public sealed record BillingPortalSessionResponse(
    string PaymentProvider,
    string PortalUrl);

public sealed record PremiumStoreVerificationResponse(
    string PaymentProvider,
    string ProductId,
    bool IsActive,
    DateTime? ExpiresAtUtc,
    string Status);

public sealed record StripeWebhookResultResponse(string EventId, bool Processed, string Status);

public sealed record StoreWebhookResultResponse(string Provider, string EventId, bool Processed, string Status);
