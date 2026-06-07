using System.Diagnostics;
using System.Security.Claims;

using Microsoft.Extensions.Hosting;

namespace PetMagic.Host.Api.Observability;

public sealed class RequestLogContextMiddleware(
    RequestDelegate next,
    ILogger<RequestLogContextMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        using var scope = logger.BeginScope(CreateScope(context));
        await next(context);
    }

    internal static Dictionary<string, object?> CreateScope(HttpContext httpContext)
    {
        var path = httpContext.Request.Path.Value ?? string.Empty;
        var endpoint = httpContext.GetEndpoint()?.DisplayName ?? path;
        var traceId = Activity.Current?.TraceId.ToString() ?? httpContext.TraceIdentifier;
        var correlationId = httpContext.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value)
            ? value?.ToString()
            : null;

        return new Dictionary<string, object?>
        {
            ["ApplicationName"] = "PetMagic.Host.Api",
            ["Environment"] = httpContext.RequestServices.GetRequiredService<IHostEnvironment>().EnvironmentName,
            ["TraceId"] = traceId,
            ["CorrelationId"] = string.IsNullOrWhiteSpace(correlationId) ? "unknown" : correlationId,
            ["RequestId"] = httpContext.TraceIdentifier,
            ["UserId"] = ResolveUserId(httpContext),
            ["Role"] = ResolveRole(httpContext),
            ["Endpoint"] = endpoint,
            ["HttpMethod"] = httpContext.Request.Method,
            ["Path"] = path
        };
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
