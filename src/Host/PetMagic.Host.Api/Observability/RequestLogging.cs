using System.Diagnostics;
using System.Security.Claims;

using Microsoft.Extensions.Hosting;

using PetMagic.BuildingBlocks.Observability;

using Serilog.Events;

namespace PetMagic.Host.Api.Observability;

public static class RequestLogging
{
    private static readonly HashSet<string> SensitiveParentSegments = new(StringComparer.OrdinalIgnoreCase)
    {
        "accounts",
        "attachments",
        "conversations",
        "customers",
        "feedback",
        "generations",
        "incidents",
        "messages",
        "orders",
        "pets",
        "photos",
        "purchases",
        "reports",
        "subscriptions",
        "tickets",
        "users",
        "wallets"
    };

    private static readonly HashSet<string> SafeActionSegments = new(StringComparer.OrdinalIgnoreCase)
    {
        "accept",
        "active",
        "cancel",
        "categories",
        "checkout",
        "confirm",
        "create",
        "current",
        "daily-featured",
        "feed",
        "health",
        "history",
        "list",
        "random",
        "redeem",
        "refresh",
        "refund",
        "retry",
        "search",
        "stats",
        "status",
        "summary",
        "token",
        "verify",
        "webhook",
        "webhooks"
    };

    private static readonly string[] ExcludedPathPrefixes =
    [
        "/health",
        "/metrics",
        "/swagger",
        "/favicon.ico",
        "/templates-media",
        "/support-attachments",
        "/user-avatars"
    ];

    public static bool ShouldLog(HttpContext httpContext) => !IsExcluded(httpContext);

    public static LogEventLevel GetLevel(HttpContext httpContext, int elapsedMs, int slowRequestThresholdMs)
    {
        if (httpContext.Response.StatusCode >= StatusCodes.Status500InternalServerError)
        {
            return LogEventLevel.Error;
        }

        if (elapsedMs >= slowRequestThresholdMs)
        {
            return LogEventLevel.Warning;
        }

        return LogEventLevel.Information;
    }

    public static Dictionary<string, object?> CreateScope(HttpContext httpContext, int elapsedMs)
    {
        var rawPath = ResolveRawPath(httpContext);
        var safePath = ResolveSafePath(httpContext);
        var endpoint = ResolveSafeEndpoint(httpContext);
        var traceId = Activity.Current?.TraceId.ToString() ?? httpContext.TraceIdentifier;
        var correlationId = httpContext.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value)
            ? value?.ToString()
            : null;
        var userId = ResolveUserId(httpContext);
        var role = ResolveRole(httpContext);

        return new Dictionary<string, object?>
        {
            ["ApplicationName"] = "PetMagic.Host.Api",
            ["Environment"] = httpContext.RequestServices.GetRequiredService<IHostEnvironment>().EnvironmentName,
            ["TraceId"] = traceId,
            ["CorrelationIdHash"] = SafeLogValues.StableHash(correlationId),
            ["RequestIdHash"] = SafeLogValues.StableHash(httpContext.TraceIdentifier),
            ["UserIdHash"] = SafeLogValues.StableHash(userId),
            ["Role"] = role,
            ["Endpoint"] = endpoint,
            ["HttpMethod"] = httpContext.Request.Method,
            ["Path"] = safePath,
            ["PathHash"] = SafeLogValues.StableHash(rawPath),
            ["StatusCode"] = httpContext.Response.StatusCode,
            ["ElapsedMs"] = elapsedMs
        };
    }

    public static string ResolveSafePath(HttpContext httpContext)
    {
        var rawPath = ResolveRawPath(httpContext);
        var endpoint = httpContext.GetEndpoint()?.DisplayName;
        if (string.IsNullOrWhiteSpace(endpoint))
        {
            return rawPath.StartsWith("/api/", StringComparison.OrdinalIgnoreCase)
                ? "/api/{unmatched}"
                : "/";
        }

        var method = httpContext.Request.Method;
        var methodPrefix = method + " ";
        var safePath = endpoint.StartsWith(methodPrefix, StringComparison.OrdinalIgnoreCase)
            ? endpoint[methodPrefix.Length..]
            : endpoint;

        return SanitizePathSegments(safePath);
    }

    public static string ResolveSafeEndpoint(HttpContext httpContext)
    {
        var endpoint = httpContext.GetEndpoint()?.DisplayName;
        if (string.IsNullOrWhiteSpace(endpoint))
        {
            return ResolveSafePath(httpContext);
        }

        var method = httpContext.Request.Method;
        var methodPrefix = method + " ";
        if (!endpoint.StartsWith(methodPrefix, StringComparison.OrdinalIgnoreCase))
        {
            return SanitizePathSegments(endpoint);
        }

        return methodPrefix + SanitizePathSegments(endpoint[methodPrefix.Length..]);
    }

    private static string ResolveRawPath(HttpContext httpContext) => httpContext.Request.Path.Value ?? string.Empty;

    private static string SanitizePathSegments(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || !value.Contains('/'))
        {
            return value;
        }

        var segments = value.Split('/');
        for (var index = 0; index < segments.Length; index++)
        {
            var segment = segments[index];
            if (string.IsNullOrEmpty(segment)
                || (segment.StartsWith('{') && segment.EndsWith('}')))
            {
                continue;
            }

            var previousSegment = index > 0 ? segments[index - 1] : null;
            if (IsSensitivePathSegment(segment, previousSegment))
            {
                segments[index] = "{id}";
            }
        }

        return string.Join('/', segments);
    }

    private static bool IsSensitivePathSegment(string segment, string? previousSegment)
    {
        if (Guid.TryParse(segment, out _))
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(previousSegment)
            && SensitiveParentSegments.Contains(previousSegment))
        {
            return !SafeActionSegments.Contains(segment);
        }

        return segment.Length >= 12 && segment.Any(char.IsDigit);
    }

    private static bool IsExcluded(HttpContext httpContext)
    {
        if (HttpMethods.IsOptions(httpContext.Request.Method))
        {
            return true;
        }

        if (httpContext.Response.StatusCode == StatusCodes.Status101SwitchingProtocols)
        {
            return true;
        }

        var path = httpContext.Request.Path.Value ?? string.Empty;
        if (ExcludedPathPrefixes.Any(prefix => path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))
        {
            return true;
        }

        return !path.StartsWith("/api/", StringComparison.OrdinalIgnoreCase)
            && Path.HasExtension(path);
    }

    private static string ResolveUserId(HttpContext httpContext)
    {
        return httpContext.User.FindFirst("sub")?.Value
            ?? httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? httpContext.User.FindFirst("userId")?.Value
            ?? "anonymous";
    }

    private static string ResolveRole(HttpContext httpContext)
    {
        var roles = httpContext.User.FindAll(ClaimTypes.Role)
            .Select(claim => claim.Value)
            .Where(role => !string.IsNullOrWhiteSpace(role))
            .OrderBy(role => role, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return roles.Length == 0 ? "anonymous" : string.Join(",", roles);
    }
}
