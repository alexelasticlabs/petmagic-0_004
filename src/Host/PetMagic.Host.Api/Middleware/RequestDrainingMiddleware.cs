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
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.Headers.RetryAfter = "10";
            await context.Response.WriteAsJsonAsync(new
            {
                type = "https://httpstatuses.com/503",
                title = "Service Unavailable",
                status = 503,
                detail = "The server is shutting down. Please retry your request."
            });
            return;
        }

        await _next(context);
    }
}
