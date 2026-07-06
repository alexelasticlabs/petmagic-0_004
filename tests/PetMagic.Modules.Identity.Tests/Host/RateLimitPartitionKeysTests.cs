using System.Net;
using System.Security.Claims;

using Microsoft.AspNetCore.Http;

using PetMagic.Host.Api.Security;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RateLimitPartitionKeysTests
{
    [Fact]
    public void UserOrIp_ShouldPreferJwtSubjectClaim()
    {
        var context = CreateContext(
            claims:
            [
                new Claim(ClaimTypes.NameIdentifier, "mapped-user"),
                new Claim("sub", "jwt-subject")
            ]);

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("jwt-subject", partitionKey);
    }

    [Fact]
    public void UserOrIp_ShouldUseMappedNameIdentifierClaim()
    {
        var context = CreateContext(claims: [new Claim(ClaimTypes.NameIdentifier, "mapped-user")]);

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("mapped-user", partitionKey);
    }

    [Fact]
    public void UserOrIp_ShouldFallbackToRemoteIp_WhenNoUserClaimExists()
    {
        var context = CreateContext(remoteIp: "203.0.113.10");

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("203.0.113.10", partitionKey);
    }

    [Fact]
    public void Ip_ShouldIgnoreUserClaims()
    {
        var context = CreateContext(
            remoteIp: "203.0.113.20",
            claims: [new Claim("sub", "jwt-subject")]);

        var partitionKey = RateLimitPartitionKeys.Ip(context);

        Assert.Equal("203.0.113.20", partitionKey);
    }

    [Theory]
    [InlineData("/api/economy/webhooks/stripe", "stripe:203.0.113.10")]
    [InlineData("/api/economy/webhooks/stripe/", "stripe:203.0.113.10")]
    [InlineData("/api/economy/webhooks/app-store", "apple:203.0.113.10")]
    [InlineData("/api/webhooks/apple-app-store", "apple:203.0.113.10")]
    [InlineData("/api/economy/webhooks/google-play", "google:203.0.113.10")]
    [InlineData("/api/webhooks/google-play", "google:203.0.113.10")]
    public void WebhookProvider_ShouldUseKnownRouteContract(string path, string expected)
    {
        var context = CreateContext(path: path);

        Assert.Equal(expected, RateLimitPartitionKeys.WebhookProvider(context));
    }

    [Theory]
    [InlineData("/api/economy/webhooks/not-stripe")]
    [InlineData("/api/economy/webhooks/google-play-extra")]
    [InlineData("/api/webhooks/apple-app-store-preview")]
    public void WebhookProvider_ShouldNotInferProviderFromSubstring(string path)
    {
        var context = CreateContext(path: path);

        Assert.Equal("other:203.0.113.10", RateLimitPartitionKeys.WebhookProvider(context));
    }

    private static DefaultHttpContext CreateContext(
        string path = "/api/test",
        string remoteIp = "203.0.113.10",
        params Claim[] claims)
    {
        var context = new DefaultHttpContext();
        context.Request.Path = path;
        context.Connection.RemoteIpAddress = IPAddress.Parse(remoteIp);
        if (claims.Length > 0)
        {
            context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "Test"));
        }

        return context;
    }
}
