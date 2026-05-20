namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record ClaimWeeklyGrantCommand(Guid UserId, bool IsPremium);

public sealed record ClaimAdRewardCommand(Guid UserId);

public sealed record SpendBalanceCommand(Guid UserId, int Amount, string Reason);

public sealed record CreditBalanceCommand(Guid UserId, int Amount, string Source, string Reason);

public sealed record CreatePackPurchaseCommand(Guid UserId, Guid PackId, string CurrencyCode, string PaymentProvider, Guid? PaymentMethodId = null);

public sealed record CreatePremiumCheckoutCommand(Guid UserId, string PlanCode, string PaymentProvider);

public sealed record CreatePremiumBillingPortalCommand(Guid UserId, string PaymentProvider);

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

public sealed record CreatePaymentMethodSetupCommand(Guid UserId, string PaymentProvider);

public sealed record RemovePaymentMethodCommand(Guid UserId, Guid PaymentMethodId);

public sealed record ApplyRedeemCodeCommand(Guid UserId, string Code);

public sealed record CreateRedeemCodeCommand(
    string Code,
    string Description,
    int RewardSpark,
    int MaxRedemptions,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc);

public sealed record UpdateRedeemCodeCommand(
    Guid RedeemCodeId,
    string Description,
    int RewardSpark,
    int MaxRedemptions,
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
    int RewardSpark,
    WalletOperationResponse WalletOperation);

public sealed record AdminRedeemCodeResponse(
    Guid RedeemCodeId,
    string CodePrefix,
    string Description,
    int RewardSpark,
    int MaxRedemptions,
    int RedeemedCount,
    bool IsActive,
    DateTime? StartsAtUtc,
    DateTime? ExpiresAtUtc,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);

public sealed record CurrencyPackResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    string CurrencyCode,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    int TotalSpark);

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
