namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyServiceLegacyHardeningTests
{
    [Fact]
    public void ListPaymentMethodsProjection_ShouldNormalizeLegacyNullStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.PaymentsAndCheckout.cs"));

        Assert.Contains("x.Provider ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Brand ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Last4 ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminSubscriptionsQueryAndProjection_ShouldGuardLegacyNullStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Admin.cs"));

        Assert.Contains("(x.subscription.PlanId ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.plan.Name ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("x.subscription.Provider ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.subscription.PurchaseChannel ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.subscription.Region ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.subscription.PlanId ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.subscription.Status ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminPurchaseHistoryQueryAndProjection_ShouldGuardLegacyNullStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Admin.cs"));

        Assert.Contains("(x.pack.Code ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.pack.DisplayName ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("x.PackCode ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.PackDisplayName ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.PaymentProvider ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Status ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CurrencyCode ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminConfigurationMappings_ShouldNormalizeLegacyNullStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyAdminConfigurationService.cs"));

        Assert.Contains("x.Code ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.DisplayName ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CurrencyCode ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Id ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Name ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.BillingPeriod ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("configuration.Provider ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("configuration.Platform ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("configuration.Region ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("configuration.AllowedFromAppVersion ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("configuration.Mode ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("plan.Id ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("plan.Name ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("plan.BillingPeriod ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("plan.CurrencyCode ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("pack.Code ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("pack.DisplayName ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("pack.CurrencyCode ?? string.Empty", source, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
