namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class AdminUserEconomyAnalyticsReaderHardeningTests
{
    [Fact]
    public void AnalyticsReader_ShouldNormalizeLegacyNullPurchaseAndLedgerStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "AdminUserEconomyAnalyticsReader.cs"));

        Assert.Contains("x.Status ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CurrencyCode ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.PaymentProvider ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Source ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Reason ?? string.Empty", source, StringComparison.Ordinal);
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
