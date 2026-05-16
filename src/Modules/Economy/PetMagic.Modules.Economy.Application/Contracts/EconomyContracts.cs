namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record ClaimWeeklyGrantCommand(Guid UserId, bool IsPremium);

public sealed record ClaimAdRewardCommand(Guid UserId);

public sealed record SpendBalanceCommand(Guid UserId, int Amount, string Reason);

public sealed record CreditBalanceCommand(Guid UserId, int Amount, string Source, string Reason);

public sealed record CreatePackPurchaseCommand(Guid UserId, Guid PackId, string CurrencyCode, string PaymentProvider);

public sealed record ConfirmPackPurchaseCommand(Guid UserId, Guid OrderId);

public sealed record StripeWebhookCommand(string RawBody, string StripeSignature);

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

public sealed record CurrencyPackResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    string CurrencyCode,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    int TotalSpark);

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

public sealed record StripeWebhookResultResponse(string EventId, bool Processed, string Status);
