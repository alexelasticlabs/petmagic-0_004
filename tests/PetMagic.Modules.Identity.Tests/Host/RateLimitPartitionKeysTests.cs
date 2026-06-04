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
            new Claim(ClaimTypes.NameIdentifier, "mapped-user"),
            new Claim("sub", "jwt-subject"));

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("jwt-subject", partitionKey);
    }

    [Fact]
    public void UserOrIp_ShouldUseMappedNameIdentifierClaim()
    {
        var context = CreateContext(new Claim(ClaimTypes.NameIdentifier, "mapped-user"));

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("mapped-user", partitionKey);
    }

    [Fact]
    public void UserOrIp_ShouldFallbackToRemoteIp_WhenNoUserClaimExists()
    {
        var context = CreateContext();
        context.Connection.RemoteIpAddress = IPAddress.Parse("203.0.113.10");

        var partitionKey = RateLimitPartitionKeys.UserOrIp(context);

        Assert.Equal("203.0.113.10", partitionKey);
    }

    [Fact]
    public void Ip_ShouldIgnoreUserClaims()
    {
        var context = CreateContext(new Claim("sub", "jwt-subject"));
        context.Connection.RemoteIpAddress = IPAddress.Parse("203.0.113.20");

        var partitionKey = RateLimitPartitionKeys.Ip(context);

        Assert.Equal("203.0.113.20", partitionKey);
    }

    private static DefaultHttpContext CreateContext(params Claim[] claims)
    {
        var context = new DefaultHttpContext();
        if (claims.Length > 0)
        {
            context.User = new ClaimsPrincipal(new ClaimsIdentity(claims, "Test"));
        }

        return context;
    }
}
