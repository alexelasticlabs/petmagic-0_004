using System.Diagnostics;

using PetMagic.BuildingBlocks.Observability;

using Serilog.Context;

namespace PetMagic.Host.Api.Observability;

public sealed class CorrelationIdMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = CorrelationId.NormalizeOrCreate(context.Request.Headers[CorrelationId.HeaderName]);
        context.Items[CorrelationId.HttpContextItemKey] = correlationId;
        Activity.Current?.SetTag("correlation.id", correlationId);

        context.Response.OnStarting(static state =>
        {
            var httpContext = (HttpContext)state;
            if (httpContext.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value)
                && value is string correlationId)
            {
                httpContext.Response.Headers[CorrelationId.HeaderName] = correlationId;
            }

            return Task.CompletedTask;
        }, context);

        using (CorrelationContext.Push(correlationId))
        using (LogContext.PushProperty("CorrelationId", correlationId))
        {
            await next(context);
        }
    }
}
