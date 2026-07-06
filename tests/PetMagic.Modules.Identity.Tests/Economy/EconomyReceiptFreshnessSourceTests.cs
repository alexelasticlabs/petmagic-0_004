namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyReceiptFreshnessSourceTests
{
    [Fact]
    public void StoreReceiptFreshness_ShouldRejectOldFutureOrUnparseableTransactionDates()
    {
        var source = File.ReadAllText(SourcePath("EconomyService.StoreReceiptFreshness.cs"));

        Assert.Contains("MaxStoreReceiptAgeHours", source, StringComparison.Ordinal);
        Assert.Contains("receiptAge > maxAge", source, StringComparison.Ordinal);
        Assert.Contains("purchasedAtUtc > now.Add(StoreReceiptFutureSkew)", source, StringComparison.Ordinal);
        Assert.Contains("EconomyErrors.StorePurchaseInvalid", source, StringComparison.Ordinal);
    }

    [Fact]
    public void StoreReceiptVerificationPaths_ShouldCheckFreshnessBeforeGrantingEntitlements()
    {
        var premiumSource = File.ReadAllText(SourcePath("EconomyService.PremiumVerification.cs"));
        Assert.True(
            premiumSource.IndexOf("EnsureStoreReceiptIsFresh", StringComparison.Ordinal)
            < premiumSource.IndexOf("storeSubscriptionVerifier.VerifyAsync", StringComparison.Ordinal));

        var purchaseSource = File.ReadAllText(SourcePath("EconomyService.PurchaseVerification.cs"));
        Assert.True(
            purchaseSource.IndexOf("EnsureStoreReceiptIsFresh", StringComparison.Ordinal)
            < purchaseSource.IndexOf("storeSubscriptionVerifier.VerifyProductPurchaseAsync", StringComparison.Ordinal));
        Assert.Contains("transactionInfo.PurchaseDateUtc?.ToString(\"O\")", purchaseSource, StringComparison.Ordinal);
    }

    private static string SourcePath(string fileName)
    {
        return Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            fileName);
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
