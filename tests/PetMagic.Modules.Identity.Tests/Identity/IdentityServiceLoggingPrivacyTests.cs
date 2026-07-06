namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityServiceLoggingPrivacyTests
{
    [Fact]
    public void IdentityServiceAuthLogs_ShouldHashUserIdentifiers()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Infrastructure",
            "IdentityService.cs"));

        Assert.Contains("UserIdHash={UserIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("HashUserId(userId)", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(userId.Value.ToString(\"D\"))", source, StringComparison.Ordinal);
        Assert.DoesNotContain("UserId={UserId}", source, StringComparison.Ordinal);
        Assert.Contains("CorrelationIdHash={CorrelationIdHash}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate())", source, StringComparison.Ordinal);
        Assert.DoesNotContain("CorrelationId={CorrelationId}", source, StringComparison.Ordinal);
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
