using System.Diagnostics;
using System.Text.Json;

using Microsoft.AspNetCore.Mvc;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Host.Api.Middleware;

public sealed class RequestTimeoutMiddleware
{
    private readonly RequestDelegate _next;
    private readonly TimeSpan _timeout;

    public RequestTimeoutMiddleware(RequestDelegate next, TimeSpan? timeout = null)
    {
        _next = next;
        _timeout = timeout ?? TimeSpan.FromSeconds(30);
    }

    public async Task InvokeAsync(HttpContext context)
    {
        using var cts = new CancellationTokenSource(_timeout);
        var originalToken = context.RequestAborted;
        using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(originalToken, cts.Token);

        try
        {
            context.RequestAborted = linkedCts.Token;
            await _next(context);
        }
        catch (OperationCanceledException) when (cts.IsCancellationRequested && !originalToken.IsCancellationRequested)
        {
            if (!context.Response.HasStarted)
            {
                var correlationId = ResolveCorrelationId(context);
                var traceId = Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier;
                context.Response.Clear();
                context.Response.StatusCode = StatusCodes.Status504GatewayTimeout;
                context.Response.ContentType = "application/problem+json";
                context.Response.Headers[CorrelationId.HeaderName] = correlationId;

                var problem = new ProblemDetails
                {
                    Status = StatusCodes.Status504GatewayTimeout,
                    Title = "REQUEST_TIMEOUT",
                    Instance = RequestLogging.ResolveSafePath(context)
                };
                problem.Extensions["code"] = "REQUEST_TIMEOUT";
                problem.Extensions["traceId"] = traceId;
                problem.Extensions["correlationId"] = correlationId;

                await JsonSerializer.SerializeAsync(
                    context.Response.Body,
                    problem,
                    new JsonSerializerOptions(JsonSerializerDefaults.Web),
                    originalToken);
            }
        }
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
