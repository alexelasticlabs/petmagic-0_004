namespace PetMagic.Modules.Economy.Application.Contracts;

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
    DateTime? CurrentPeriodStartUtc,
    DateTime? CurrentPeriodEndUtc,
    bool CancelAtPeriodEnd,
    int MonthlyTokenLimit,
    int TokensAvailable,
    bool CanManageSubscription,
    string ManageSubscriptionAction,
    DateTime? LastTokenGrantAtUtc,
    string? CardBrand,
    string? CardLast4);

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
