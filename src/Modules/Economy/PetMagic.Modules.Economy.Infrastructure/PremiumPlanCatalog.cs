namespace PetMagic.Modules.Economy.Infrastructure;

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
    private static readonly IReadOnlyList<PremiumPlanDefinition> Plans =
    [
        new(
            "monthly",
            "PetMagic Premium Monthly",
            "month",
            14.99m,
            null,
            "USD",
            500,
            false,
            null,
            1,
            "com.petmagic.app.premium.monthly",
            "com.petmagic.app.premium.monthly"),
        new(
            "yearly",
            "PetMagic Premium Yearly",
            "year",
            99.99m,
            149.99m,
            "USD",
            1000,
            true,
            33,
                2,
            "com.petmagic.app.premium.yearly",
            "com.petmagic.app.premium.yearly")
    ];

    public static IReadOnlyList<PremiumPlanDefinition> All => Plans;

    public static PremiumPlanDefinition? Find(string planCode)
    {
        return Plans.FirstOrDefault(x =>
            string.Equals(x.PlanCode, planCode.Trim(), StringComparison.OrdinalIgnoreCase));
    }
}
