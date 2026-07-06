using System.Diagnostics;

using PetMagic.BuildingBlocks.Observability;

using Serilog.Context;

namespace PetMagic.Host.Api.Observability;

public sealed class CorrelationIdMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = CorrelationId.NormalizeOrCreate(context.Request.Headers[CorrelationId.HeaderName]);
        var correlationIdHash = SafeLogValues.StableHash(correlationId);
        context.Items[CorrelationId.HttpContextItemKey] = correlationId;
        Activity.Current?.SetTag("correlation.id_hash", correlationIdHash);

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
        using (LogContext.PushProperty("CorrelationIdHash", correlationIdHash))
        {
            await next(context);
        }
    }
}
