using System.Diagnostics;

using Microsoft.AspNetCore.Http;

namespace PetMagic.Host.Api.Observability;

public sealed class RequestMetricsMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var startedAt = Stopwatch.GetTimestamp();
        var recordedException = false;
        try
        {
            await next(context);
        }
        catch
        {
            recordedException = true;
            HostApiMetrics.RecordRequestError(context, StatusCodes.Status500InternalServerError, "exception");
            throw;
        }
        finally
        {
            var elapsed = Stopwatch.GetElapsedTime(startedAt);
            HostApiMetrics.RecordRequestDuration(context, context.Response.StatusCode, elapsed);

            if (!recordedException && context.Response.StatusCode >= StatusCodes.Status400BadRequest)
            {
                HostApiMetrics.RecordRequestError(context, context.Response.StatusCode, "status");
            }
        }
    }
}
