namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyAdminRedeemCodeServiceHardeningTests
{
    [Fact]
    public void AdminRedeemCodeQueries_ShouldFilterSortAndPageBeforeMaterialization()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyAdminRedeemCodeService.cs"));

        Assert.Contains("ApplyRedeemCodeStatusFilter(codesQuery, normalizedStatus, now)", source, StringComparison.Ordinal);
        Assert.Equal(2, CountOccurrences(source, "codesQuery = ApplyRedeemCodeStatusFilter(codesQuery, normalizedStatus, now);"));
        Assert.DoesNotContain("(await codesQuery.ToListAsync(cancellationToken))", source, StringComparison.Ordinal);
        Assert.Contains("var totalCount = await codesQuery.CountAsync(cancellationToken);", source, StringComparison.Ordinal);
        Assert.Contains("var pageCodes = await ApplyRedeemCodeSort(codesQuery, normalizedSort)", source, StringComparison.Ordinal);
        Assert.Contains(".Skip(normalizedSkip)", source, StringComparison.Ordinal);
        Assert.Contains(".Take(normalizedTake + 1)", source, StringComparison.Ordinal);

        var firstFilter = source.IndexOf(
            "codesQuery = ApplyRedeemCodeStatusFilter(codesQuery, normalizedStatus, now);",
            StringComparison.Ordinal);
        var firstPageMaterialization = source.IndexOf(
            ".ToListAsync(cancellationToken);",
            StringComparison.Ordinal);

        Assert.True(firstFilter >= 0);
        Assert.True(firstPageMaterialization > firstFilter);

        Assert.Contains("\"active\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("\"scheduled\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("\"expired\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("\"exhausted\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("code.RedeemedCount >= code.MaxRedemptions", source, StringComparison.Ordinal);
        Assert.Contains("\"draft\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("\"paused\" => query.Where(code =>", source, StringComparison.Ordinal);
        Assert.Contains("!code.IsActive", source, StringComparison.Ordinal);
        Assert.Contains("\"archived\" => query.Where(code =>", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminRedeemCodeSort_ShouldUseDatabaseStableIdTieBreaker()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyAdminRedeemCodeService.cs"));

        Assert.Equal(5, CountOccurrences(source, ".ThenByDescending(code => code.Id)"));
        Assert.Contains("\"code\" => query", source, StringComparison.Ordinal);
        Assert.Contains(".OrderBy(code => code.Code)", source, StringComparison.Ordinal);
        Assert.Contains("\"expiry\" => query", source, StringComparison.Ordinal);
        Assert.Contains(".OrderBy(code => code.ExpiresAtUtc == null)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminRedeemCodeMetrics_ShouldAggregateCodeCountsInSingleDatabaseQuery()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyAdminRedeemCodeService.cs"));

        Assert.Contains("var codeStats = await codesQuery", source, StringComparison.Ordinal);
        Assert.Contains(".GroupBy(_ => 1)", source, StringComparison.Ordinal);
        Assert.Contains("TotalCodes = group.Count()", source, StringComparison.Ordinal);
        Assert.Contains("ActiveCodes = group.Count(code =>", source, StringComparison.Ordinal);
        Assert.Contains("CreatedLast7d = group.Count(code => code.CreatedAtUtc >= sevenDaysAgo)", source, StringComparison.Ordinal);
        Assert.Contains("ActiveTouchedLast7d = group.Count(code =>", source, StringComparison.Ordinal);
        Assert.DoesNotContain("var totalCodes = await codesQuery.CountAsync(cancellationToken);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("await codesQuery.CountAsync(code => code.CreatedAtUtc >= sevenDaysAgo, cancellationToken)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("await ApplyRedeemCodeStatusFilter(codesQuery, \"active\", now).CountAsync", source, StringComparison.Ordinal);
    }

    private static int CountOccurrences(string source, string value)
    {
        var count = 0;
        var index = 0;

        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
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
