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

    public static string WebhookProvider(HttpContext httpContext)
    {
        return $"{ResolveWebhookProvider(httpContext.Request.Path)}:{Ip(httpContext)}";
    }

    private static string ResolveWebhookProvider(PathString requestPath)
    {
        var path = (requestPath.Value ?? string.Empty).TrimEnd('/');
        return path.ToLowerInvariant() switch
        {
            "/api/economy/webhooks/stripe" => "stripe",
            "/api/economy/webhooks/app-store" => "apple",
            "/api/webhooks/apple-app-store" => "apple",
            "/api/economy/webhooks/google-play" => "google",
            "/api/webhooks/google-play" => "google",
            _ => "other"
        };
    }

    private static string? FirstNonEmpty(params string?[] values)
    {
        return values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
    }
}
