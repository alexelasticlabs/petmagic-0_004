using System.Diagnostics.Metrics;

using Microsoft.AspNetCore.Http;

namespace PetMagic.Host.Api.Observability;

public static class HostApiMetrics
{
    public const string MeterName = "PetMagic.Host.Api";

    private static readonly Meter Meter = new(MeterName);

    private static readonly Counter<long> RequestErrorsTotal = Meter.CreateCounter<long>(
        "request_errors_total",
        unit: "{request}",
        description: "Number of HTTP requests that completed with a client/server error or an exception.");

    public static void RecordRequestError(HttpContext httpContext, int statusCode, string errorKind)
    {
        RequestErrorsTotal.Add(
            1,
            new KeyValuePair<string, object?>("method", httpContext.Request.Method),
            new KeyValuePair<string, object?>("route", ResolveRoute(httpContext)),
            new KeyValuePair<string, object?>("status_code", statusCode),
            new KeyValuePair<string, object?>("error_kind", errorKind));
    }

    private static string ResolveRoute(HttpContext httpContext)
    {
        var endpoint = httpContext.GetEndpoint();
        if (!string.IsNullOrWhiteSpace(endpoint?.DisplayName))
        {
            return endpoint.DisplayName;
        }

        return "unknown";
    }
}
