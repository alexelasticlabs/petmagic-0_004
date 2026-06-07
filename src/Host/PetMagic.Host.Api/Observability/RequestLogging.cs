using System.Diagnostics;
using System.Security.Claims;

using Microsoft.Extensions.Hosting;

using Serilog.Events;

namespace PetMagic.Host.Api.Observability;

public static class RequestLogging
{
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
        var path = httpContext.Request.Path.Value ?? string.Empty;
        var endpoint = httpContext.GetEndpoint()?.DisplayName ?? path;
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
            ["CorrelationId"] = string.IsNullOrWhiteSpace(correlationId) ? "unknown" : correlationId,
            ["RequestId"] = httpContext.TraceIdentifier,
            ["UserId"] = userId,
            ["Role"] = role,
            ["Endpoint"] = endpoint,
            ["HttpMethod"] = httpContext.Request.Method,
            ["Path"] = path,
            ["StatusCode"] = httpContext.Response.StatusCode,
            ["ElapsedMs"] = elapsedMs
        };
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
