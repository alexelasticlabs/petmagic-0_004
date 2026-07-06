using System.Diagnostics;
using System.Text.Json;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Host.Api.Security;

public static class RateLimitProblemResponse
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static async ValueTask WriteAsync(OnRejectedContext context, CancellationToken cancellationToken)
    {
        var response = context.HttpContext.Response;
        response.StatusCode = StatusCodes.Status429TooManyRequests;
        response.ContentType = "application/problem+json";

        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            response.Headers.RetryAfter = Math.Ceiling(retryAfter.TotalSeconds).ToString("0");
        }

        var correlationId = ResolveCorrelationId(context.HttpContext);
        var traceId = Activity.Current?.TraceId.ToString() ?? context.HttpContext.TraceIdentifier;
        var problem = new ProblemDetails
        {
            Status = StatusCodes.Status429TooManyRequests,
            Title = "RATE_LIMIT_EXCEEDED"
        };
        problem.Extensions["code"] = "RATE_LIMIT_EXCEEDED";
        problem.Extensions["traceId"] = traceId;
        problem.Extensions["correlationId"] = correlationId;

        await response.WriteAsync(JsonSerializer.Serialize(problem, JsonOptions), cancellationToken);
    }

    private static string ResolveCorrelationId(HttpContext httpContext)
    {
        if (httpContext.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value)
            && value is string correlationId
            && CorrelationId.IsValid(correlationId))
        {
            return correlationId;
        }

        correlationId = CorrelationId.NormalizeOrCreate(httpContext.Request.Headers[CorrelationId.HeaderName]);
        httpContext.Items[CorrelationId.HttpContextItemKey] = correlationId;
        httpContext.Response.Headers[CorrelationId.HeaderName] = correlationId;
        return correlationId;
    }
}
