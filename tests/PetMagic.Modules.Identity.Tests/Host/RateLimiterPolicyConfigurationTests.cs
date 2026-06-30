namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RateLimiterPolicyConfigurationTests
{
    [Theory]
    [InlineData("auth-register", "AuthRegister", "8")]
    [InlineData("auth-password-reset", "AuthPasswordReset", "10")]
    public void Program_ShouldUseSlidingWindowLimiter_ForSensitiveAnonymousAuthPolicies(
        string policyName,
        string configKey,
        string defaultPermitLimit)
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Program.cs"));

        var policyBlock = ExtractPolicyBlock(source, policyName);

        Assert.Contains("RateLimitPartition.GetSlidingWindowLimiter(", policyBlock, StringComparison.Ordinal);
        Assert.Contains($"PermitLimit = RateLimitPermit(\"{configKey}\", {defaultPermitLimit})", policyBlock, StringComparison.Ordinal);
        Assert.Contains("SegmentsPerWindow = 6", policyBlock, StringComparison.Ordinal);
        Assert.Contains("AutoReplenishment = true", policyBlock, StringComparison.Ordinal);
    }

    private static string ExtractPolicyBlock(string source, string policyName)
    {
        var startMarker = $"options.AddPolicy(\"{policyName}\"";
        var startIndex = source.IndexOf(startMarker, StringComparison.Ordinal);
        Assert.True(startIndex >= 0, $"Policy block '{policyName}' was not found.");

        var nextPolicyIndex = source.IndexOf("options.AddPolicy(", startIndex + startMarker.Length, StringComparison.Ordinal);
        if (nextPolicyIndex < 0)
        {
            nextPolicyIndex = source.Length;
        }

        return source[startIndex..nextPolicyIndex];
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
