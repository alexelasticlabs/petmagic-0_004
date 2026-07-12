namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class HostApiMiddlewareOrderTests
{
    [Fact]
    public void Program_ShouldAuthenticateBeforeRateLimitingUserPartitionedRequests()
    {
        var source = ReadHostProgramSource();

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

    [Fact]
    public void Program_ShouldAuthorizeSignedMediaOnlyForManagedPrefixes()
    {
        var source = ReadHostProgramSource();

        Assert.Contains("IsManagedSignedMediaPath(", source, StringComparison.Ordinal);
        Assert.Contains("ResolvePublicBasePath(", source, StringComparison.Ordinal);
        Assert.Contains("\"/support-attachments\"", source, StringComparison.Ordinal);
        Assert.Contains("\"/user-avatars\"", source, StringComparison.Ordinal);
        Assert.Contains("\"/templates-media\"", source, StringComparison.Ordinal);
        Assert.Contains("GetRequiredService<ITemplateMediaReadUrlSigner>()", source, StringComparison.Ordinal);
        Assert.Contains("requestPath.StartsWithSegments(managedPrefix)", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "requestPath.Contains(\"/support-attachments\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "requestPath.Contains(\"/user-avatars\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void Program_ShouldAllowUnsignedLocalTemplateMediaOnlyInDevelopment()
    {
        var source = ReadHostProgramSource();

        Assert.Contains(
            "templatesOptions.PublicBaseUrl) &&\n            !app.Environment.IsDevelopment()",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "Local template storage is development-only",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void Program_ShouldClassifyStaticMediaOnlyByManagedPathSegments()
    {
        var source = ReadHostProgramSource();

        Assert.Contains("IsManagedStaticMediaPath(", source, StringComparison.Ordinal);
        Assert.Contains("IsManagedStaticMediaPath(requestPath, \"/support-attachments\")", source, StringComparison.Ordinal);
        Assert.Contains("IsManagedStaticMediaPath(requestPath, \"/user-avatars\")", source, StringComparison.Ordinal);
        Assert.Contains("IsManagedStaticMediaPath(requestPath, \"/templates-media\")", source, StringComparison.Ordinal);
        Assert.Contains("requestPath.StartsWithSegments(new PathString(managedPathPrefix))", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "requestPath.StartsWith(\"/support-attachments\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain(
            "requestPath.StartsWith(\"/user-avatars\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
    }

    private static string ReadHostProgramSource() => File.ReadAllText(Path.Combine(
        FindRepositoryRoot(),
        "src",
        "Host",
        "PetMagic.Host.Api",
        "Program.cs"));

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
