namespace PetMagic.Modules.Economy.Infrastructure;

using PetMagic.Modules.Economy.Infrastructure.Options;

internal sealed record PremiumPlanDefinition(
    string PlanCode,
    string ProductName,
    string BillingInterval,
    decimal PriceAmount,
    decimal? CompareAtPriceAmount,
    string CurrencyCode,
    int TokenAllowance,
    bool IsPopular,
    int? DiscountPercent,
    int SortOrder,
    string GooglePlayProductId,
    string AppStoreProductId);

internal static class PremiumPlanCatalog
{
    public static IReadOnlyList<PremiumPlanDefinition> Create(EconomyOptions options) =>
    [
        new(
            "monthly",
            "PetMagic Premium Monthly",
            "month",
            14.99m,
            null,
            "USD",
            40,
            false,
            null,
            1,
            options.GooglePlayPremiumMonthlyProductId,
            options.AppStorePremiumMonthlyProductId),
        new(
            "yearly",
            "PetMagic Premium Yearly",
            "year",
            99.99m,
            149.99m,
            "USD",
            40,
            true,
            33,
            2,
            options.GooglePlayPremiumYearlyProductId,
            options.AppStorePremiumYearlyProductId)
    ];

    public static PremiumPlanDefinition? Find(EconomyOptions options, string planCode)
    {
        return Create(options).FirstOrDefault(x =>
            string.Equals(x.PlanCode, planCode.Trim(), StringComparison.OrdinalIgnoreCase));
    }
}
