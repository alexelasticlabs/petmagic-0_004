namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record AdminRedeemCodeRedemptionResponse(
    Guid RedemptionId,
    Guid UserId,
    string RewardKind,
    int RewardValue,
    Guid? WalletLedgerEntryId,
    DateTime? PremiumExpiresAtUtc,
    DateTime RedeemedAtUtc);

public sealed record AdminRedeemCodeListQuery(
    int Skip = 0,
    int Take = 50,
    string? Search = null,
    string? Status = null,
    string? RewardKind = null,
    string? Sort = null);

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
    IReadOnlyList<AdminRedeemCodeRedemptionResponse> Redemptions,
    string? CampaignName = null,
    string? CampaignChannel = null,
    int MinimumSuccessfulPurchases = 0,
    string? CreatedBy = null,
    DateTime? LastRedeemedAtUtc = null,
    int UsesLast7d = 0,
    int GrantedLast7d = 0,
    int MaxRedeemedBySingleUser = 0);

public sealed record AdminRedeemCodeMetricsResponse(
    int TotalCodes,
    int ActiveCodes,
    int TotalUses,
    int TotalGranted,
    int CreatedLast7d,
    int ActiveTouchedLast7d,
    int UsesLast7d,
    int GrantedLast7d);

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

public sealed record AdminPaymentProviderConfigurationMatchResponse(
    string Provider,
    string Platform,
    string Country,
    string NormalizedRegion,
    bool IsEuRegion,
    string AppVersion,
    bool MatchFound,
    bool AllowedForCheckout,
    bool StripeModeConfigured,
    string DecisionCode,
    string DecisionMessage,
    AdminPaymentProviderConfigurationResponse? MatchedConfiguration);

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
    DateTime UpdatedAtUtc,
    string? ProductId = null,
    bool AutoRenewing = false,
    DateTime? CancelledAtUtc = null,
    DateTime? ExpiredAtUtc = null,
    DateTime? LastValidatedAtUtc = null);

public sealed record AdminUserEconomyPurchaseResponse(
    Guid OrderId,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string PaymentProvider,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);

public sealed record AdminUserEconomyWalletLedgerResponse(
    Guid EntryId,
    int Delta,
    int BalanceAfter,
    string Source,
    string Reason,
    DateTime CreatedAtUtc,
    string? SourceProvider = null,
    string? SourceTransactionId = null);

public sealed record AdminUserEconomyActivityResponse(
    string Kind,
    string Title,
    string? Details,
    DateTime OccurredAtUtc);

public sealed record AdminUserEconomyAnalyticsResponse(
    int WalletBalance,
    int TotalTokensCredited,
    int TotalTokensSpent,
    int ManualTokensGranted,
    int ManualTokensDebited,
    int TotalPurchases,
    int SuccessfulPurchases,
    int TotalPurchasedSpark,
    DateTime? LastPurchaseAtUtc,
    DateTime? LastWalletActivityAtUtc,
    IReadOnlyList<AdminUserEconomyPurchaseResponse> RecentPurchases,
    IReadOnlyList<AdminUserEconomyWalletLedgerResponse> RecentWalletLedger,
    IReadOnlyList<AdminUserEconomyActivityResponse> RecentActivity);

public sealed record AdminEconomyDashboardRevenuePointResponse(
    DateOnly Date,
    decimal Amount);

public sealed record AdminEconomyDashboardMetricsResponse(
    int PurchasesThisWeek,
    int PurchasesPreviousWeek,
    int SuccessfulPaymentsThisWeek,
    int SuccessfulPaymentsPreviousWeek,
    int FailedPaymentsThisWeek,
    int FailedPaymentsPreviousWeek,
    decimal RevenueThisWeek,
    decimal RevenuePreviousWeek,
    long TotalWalletCredits,
    long TotalWalletDebits,
    int ActiveSubscriptions,
    int RenewalStops,
    string CurrencyCode,
    IReadOnlyList<AdminEconomyDashboardRevenuePointResponse> RevenueSeries);

public sealed record AdminSubscriptionEventResponse(
    Guid EventId,
    Guid? UserId,
    Guid? UserSubscriptionId,
    string Provider,
    string EventType,
    string Status,
    string? ExternalEventId,
    DateTime CreatedAtUtc,
    DateTime? ProcessedAtUtc);
