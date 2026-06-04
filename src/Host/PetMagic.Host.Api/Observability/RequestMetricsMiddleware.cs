using Microsoft.AspNetCore.Http;

namespace PetMagic.Host.Api.Observability;

public sealed class RequestMetricsMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
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
            if (!recordedException && context.Response.StatusCode >= StatusCodes.Status400BadRequest)
            {
                HostApiMetrics.RecordRequestError(context, context.Response.StatusCode, "status");
            }
        }
    }
}
