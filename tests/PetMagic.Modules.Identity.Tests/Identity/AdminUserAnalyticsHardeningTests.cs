namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminUserAnalyticsHardeningTests
{
    [Fact]
    public void AuditSliceProjection_ShouldNormalizeLegacyNullAuditStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "IdentityAdminUserAnalyticsService.cs"));

        Assert.Contains("x.Action ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Details ?? string.Empty", source, StringComparison.Ordinal);
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
