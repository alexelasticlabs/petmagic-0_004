using System.Diagnostics;

using Microsoft.Extensions.Options;

using Serilog.Events;

namespace PetMagic.Host.Api.Observability;

public sealed class StructuredRequestLoggingMiddleware(
    RequestDelegate next,
    ILogger<StructuredRequestLoggingMiddleware> logger,
    IOptions<LoggingOptions> options)
{
    private readonly LoggingOptions loggingOptions = options.Value;

    public async Task InvokeAsync(HttpContext context)
    {
        var startedAt = Stopwatch.GetTimestamp();
        Exception? exception = null;

        try
        {
            await next(context);
        }
        catch (Exception caughtException)
        {
            exception = caughtException;
            if (!RequestAborted(context, caughtException) && !context.Response.HasStarted)
            {
                context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            }

            throw;
        }
        finally
        {
            if (RequestLogging.ShouldLog(context) && (exception is null || !RequestAborted(context, exception)))
            {
                var elapsedMs = (int)Math.Min(int.MaxValue, Stopwatch.GetElapsedTime(startedAt).TotalMilliseconds);
                using var scope = logger.BeginScope(RequestLogging.CreateScope(context, elapsedMs));
                var level = exception is not null
                    ? LogEventLevel.Error
                    : RequestLogging.GetLevel(context, elapsedMs, loggingOptions.SlowRequestThresholdMs);

                logger.Log(
                    ToMicrosoftLogLevel(level),
                    null,
                    "HTTP {HttpMethod} {SafePath} responded {StatusCode} in {ElapsedMs} ms.",
                    context.Request.Method,
                    RequestLogging.ResolveSafePath(context),
                    context.Response.StatusCode,
                    elapsedMs);
            }
        }
    }

    private static bool RequestAborted(HttpContext context, Exception exception)
    {
        return exception is OperationCanceledException && context.RequestAborted.IsCancellationRequested;
    }

    private static LogLevel ToMicrosoftLogLevel(LogEventLevel level)
    {
        return level switch
        {
            LogEventLevel.Fatal => LogLevel.Critical,
            LogEventLevel.Error => LogLevel.Error,
            LogEventLevel.Warning => LogLevel.Warning,
            LogEventLevel.Information => LogLevel.Information,
            LogEventLevel.Debug => LogLevel.Debug,
            LogEventLevel.Verbose => LogLevel.Trace,
            _ => LogLevel.Information
        };
    }
}
