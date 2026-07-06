using System.Diagnostics;
using System.Text.Json;

using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Host.Api.Observability;

public sealed class GlobalExceptionMiddleware(
    RequestDelegate next,
    ILogger<GlobalExceptionMiddleware> logger)
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
                "Unhandled exception while processing HTTP request {HttpMethod} {SafePath}. ExceptionType={ExceptionType}",
                context.Request.Method,
                RequestLogging.ResolveSafePath(context),
                SafeLogValues.ExceptionType(exception));

            if (context.Response.HasStarted)
            {
                logger.LogWarning(
                    "Exception occurred after response started for {HttpMethod} {SafePath}. Connection will be terminated.",
                    context.Request.Method,
                    RequestLogging.ResolveSafePath(context));
                return;
            }

            context.Response.Clear();
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/problem+json";
            context.Response.Headers[CorrelationId.HeaderName] = correlationId;

            var problem = new ProblemDetails
            {
                Status = StatusCodes.Status500InternalServerError,
                Title = "INTERNAL_SERVER_ERROR",
                Instance = RequestLogging.ResolveSafePath(context)
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
