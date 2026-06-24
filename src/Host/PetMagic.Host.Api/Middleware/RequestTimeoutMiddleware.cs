using System.Diagnostics;

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
                context.Response.StatusCode = StatusCodes.Status504GatewayTimeout;
                await context.Response.WriteAsJsonAsync(new
                {
                    type = "https://httpstatuses.com/504",
                    title = "Gateway Timeout",
                    status = 504,
                    detail = "The request timed out."
                });
            }
        }
    }
}
