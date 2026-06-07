using System.Diagnostics;
using System.Text.Json;

using Microsoft.AspNetCore.Mvc;

namespace PetMagic.Host.Api.Observability;

public sealed class GlobalExceptionMiddleware(
    RequestDelegate next,
    ILogger<GlobalExceptionMiddleware> logger,
    IHostEnvironment environment)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (OperationCanceledException) when (context.RequestAborted.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            var correlationId = ResolveCorrelationId(context);
            var traceId = Activity.Current?.TraceId.ToString() ?? context.TraceIdentifier;
            if (!context.Response.HasStarted)
            {
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            }

            using var scope = logger.BeginScope(RequestLogging.CreateScope(context, elapsedMs: 0));
            logger.LogError(
                exception,
                "Unhandled exception while processing HTTP request {HttpMethod} {RequestPath}.",
                context.Request.Method,
                context.Request.Path.Value ?? string.Empty);

            if (context.Response.HasStarted)
            {
                throw;
            }

            context.Response.Clear();
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/problem+json";
            context.Response.Headers[CorrelationId.HeaderName] = correlationId;

            var problem = new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "INTERNAL_SERVER_ERROR",
                Detail = environment.IsDevelopment()
                    ? exception.ToString()
                    : "An unexpected error occurred.",
                Instance = context.Request.Path.Value
            };
            problem.Extensions["code"] = "INTERNAL_SERVER_ERROR";
            problem.Extensions["traceId"] = traceId;
            problem.Extensions["correlationId"] = correlationId;

            await JsonSerializer.SerializeAsync(
                context.Response.Body,
                problem,
                new JsonSerializerOptions(JsonSerializerDefaults.Web),
                context.RequestAborted);
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
