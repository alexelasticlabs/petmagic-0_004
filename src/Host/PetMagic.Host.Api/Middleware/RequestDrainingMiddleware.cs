using System.Diagnostics;
using System.Text.Json;

using Microsoft.AspNetCore.Mvc;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Host.Api.Middleware;

public sealed class RequestDrainingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly GracefulShutdownCoordinator _coordinator;

    public RequestDrainingMiddleware(RequestDelegate next, GracefulShutdownCoordinator coordinator)
    {
        _next = next;
        _coordinator = coordinator;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        if (_coordinator.IsStopping)
        {
            var correlationId = ResolveCorrelationId(context);
            var traceId = Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier;
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.ContentType = "application/problem+json";
            context.Response.Headers[CorrelationId.HeaderName] = correlationId;
            context.Response.Headers.RetryAfter = "10";
            var problem = new ProblemDetails
            {
                Status = StatusCodes.Status503ServiceUnavailable,
                Title = "SERVICE_DRAINING",
                Instance = RequestLogging.ResolveSafePath(context)
            };
            problem.Extensions["code"] = "SERVICE_DRAINING";
            problem.Extensions["traceId"] = traceId;
            problem.Extensions["correlationId"] = correlationId;

            await JsonSerializer.SerializeAsync(
                context.Response.Body,
                problem,
                new JsonSerializerOptions(JsonSerializerDefaults.Web),
                context.RequestAborted);
            return;
        }

        await _next(context);
    }

    private static string ResolveCorrelationId(HttpContext context)
    {
        if (context.Items.TryGetValue(CorrelationId.HttpContextItemKey, out var value)
            && value is string correlationId
            && CorrelationId.IsValid(correlationId))
        {
            return correlationId;
        }

        return CorrelationId.NormalizeOrCreate(context.Request.Headers[CorrelationId.HeaderName]);
    }
}
