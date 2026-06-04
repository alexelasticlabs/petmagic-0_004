using System.Security.Claims;

namespace PetMagic.Host.Api.Security;

public static class RateLimitPartitionKeys
{
    public static string UserOrIp(HttpContext httpContext)
    {
        return FirstNonEmpty(
                httpContext.User.FindFirst("sub")?.Value,
                httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value,
                httpContext.User.FindFirst("userId")?.Value)
            ?? httpContext.Connection.RemoteIpAddress?.ToString()
            ?? "global";
    }

    public static string Ip(HttpContext httpContext)
    {
        return httpContext.Connection.RemoteIpAddress?.ToString() ?? "global";
    }

    private static string? FirstNonEmpty(params string?[] values)
    {
        return values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
    }
}
