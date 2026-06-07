namespace PetMagic.Modules.Economy.Application.Contracts;

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
    DateTime CreatedAtUtc,
    string? SourceProvider = null,
    string? SourceTransactionId = null);

public sealed record CurrencyPackResponse(
    Guid PackId,
    string Code,
    string DisplayName,
    string CurrencyCode,
    decimal PriceAmount,
    int GrantedSpark,
    int BonusSpark,
    int TotalSpark,
    string? GooglePlayProductId = null,
    string? AppStoreProductId = null);

public sealed record WalletCheckoutConfigResponse(
    IReadOnlyList<CurrencyPackResponse> Packs,
    IReadOnlyList<PaywallPaymentMethodResponse> AvailablePaymentMethods,
    bool ExternalPaymentWarningRequired);
