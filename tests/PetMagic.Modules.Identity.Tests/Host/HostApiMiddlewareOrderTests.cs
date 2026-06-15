namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class HostApiMiddlewareOrderTests
{
    [Fact]
    public void Program_ShouldAuthenticateBeforeRateLimitingUserPartitionedRequests()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Program.cs"));

        var authenticationIndex = source.IndexOf("app.UseAuthentication();", StringComparison.Ordinal);
        var rateLimiterIndex = source.IndexOf("app.UseRateLimiter();", StringComparison.Ordinal);
        var authorizationIndex = source.IndexOf("app.UseAuthorization();", StringComparison.Ordinal);

        Assert.True(authenticationIndex >= 0, "UseAuthentication was not found.");
        Assert.True(rateLimiterIndex >= 0, "UseRateLimiter was not found.");
        Assert.True(authorizationIndex >= 0, "UseAuthorization was not found.");
        Assert.True(
            authenticationIndex < rateLimiterIndex,
            "UseRateLimiter must run after UseAuthentication so UserOrIp policies can partition by authenticated user.");
        Assert.True(
            rateLimiterIndex < authorizationIndex,
            "UseRateLimiter must still run before UseAuthorization to throttle protected endpoint traffic before authorization handlers.");
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
