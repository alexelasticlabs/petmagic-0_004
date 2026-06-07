using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class StructuredRequestLoggingMiddlewareTests
{
    [Theory]
    [InlineData("GET", "/health")]
    [InlineData("GET", "/metrics")]
    [InlineData("GET", "/swagger/index.html")]
    [InlineData("GET", "/favicon.ico")]
    [InlineData("OPTIONS", "/api/templates")]
    [InlineData("GET", "/assets/app.js")]
    public async Task Middleware_ShouldSkipExcludedRequests(string method, string path)
    {
        var logger = new CapturingLogger<StructuredRequestLoggingMiddleware>();
        var context = CreateContext(method, path);

        var middleware = new StructuredRequestLoggingMiddleware(
            _ => Task.CompletedTask,
            logger,
            Options.Create(new LoggingOptions { SlowRequestThresholdMs = 1000 }));

        await middleware.InvokeAsync(context);

        Assert.Empty(logger.Entries);
    }

    [Fact]
    public async Task Middleware_ShouldLogSlowRequestAsWarning()
    {
        var logger = new CapturingLogger<StructuredRequestLoggingMiddleware>();
        var context = CreateContext(HttpMethods.Get, "/api/slow");

        var middleware = new StructuredRequestLoggingMiddleware(
            _ => Task.Delay(20),
            logger,
            Options.Create(new LoggingOptions { SlowRequestThresholdMs = 1 }));

        await middleware.InvokeAsync(context);

        var entry = Assert.Single(logger.Entries);
        Assert.Equal(LogLevel.Warning, entry.Level);
        Assert.Contains("HTTP GET /api/slow responded 200", entry.Message, StringComparison.Ordinal);

        var scope = Assert.Single(entry.Scopes);
        Assert.Equal("GET", scope["HttpMethod"]);
        Assert.Equal(StatusCodes.Status200OK, scope["StatusCode"]);
        Assert.True((int)scope["ElapsedMs"]! >= 1);
    }

    [Fact]
    public async Task Middleware_ShouldLogFiveHundredResponseAsError()
    {
        var logger = new CapturingLogger<StructuredRequestLoggingMiddleware>();
        var context = CreateContext(HttpMethods.Post, "/api/payments/webhook");

        var middleware = new StructuredRequestLoggingMiddleware(
            httpContext =>
            {
                httpContext.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
                return Task.CompletedTask;
            },
            logger,
            Options.Create(new LoggingOptions { SlowRequestThresholdMs = 1000 }));

        await middleware.InvokeAsync(context);

        var entry = Assert.Single(logger.Entries);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Contains("HTTP POST /api/payments/webhook responded 503", entry.Message, StringComparison.Ordinal);

        var scope = Assert.Single(entry.Scopes);
        Assert.Equal("POST", scope["HttpMethod"]);
        Assert.Equal("/api/payments/webhook", scope["Path"]);
        Assert.Equal(StatusCodes.Status503ServiceUnavailable, scope["StatusCode"]);
        Assert.Equal("correlation-1", scope["CorrelationId"]);
    }

    [Fact]
    public async Task Middleware_ShouldLogUnhandledExceptionRequestAsErrorWith500()
    {
        var logger = new CapturingLogger<StructuredRequestLoggingMiddleware>();
        var context = CreateContext(HttpMethods.Get, "/api/failing-endpoint");

        var middleware = new StructuredRequestLoggingMiddleware(
            _ => throw new InvalidOperationException("boom"),
            logger,
            Options.Create(new LoggingOptions { SlowRequestThresholdMs = 1000 }));

        await Assert.ThrowsAsync<InvalidOperationException>(() => middleware.InvokeAsync(context));

        var entry = Assert.Single(logger.Entries);
        Assert.Equal(LogLevel.Error, entry.Level);
        Assert.Null(entry.Exception);
        Assert.Equal(StatusCodes.Status500InternalServerError, context.Response.StatusCode);
        Assert.Contains("HTTP GET /api/failing-endpoint responded 500", entry.Message, StringComparison.Ordinal);

        var scope = Assert.Single(entry.Scopes);
        Assert.Equal(StatusCodes.Status500InternalServerError, scope["StatusCode"]);
        Assert.Equal("correlation-1", scope["CorrelationId"]);
        Assert.Equal("GET", scope["HttpMethod"]);
        Assert.Equal("/api/failing-endpoint", scope["Path"]);
    }

    private static DefaultHttpContext CreateContext(string method, string path)
    {
        var services = new ServiceCollection()
            .AddSingleton<IHostEnvironment>(new TestHostEnvironment())
            .BuildServiceProvider();
        var context = new DefaultHttpContext
        {
            RequestServices = services
        };
        context.Request.Method = method;
        context.Request.Path = path;
        context.TraceIdentifier = "request-1";
        context.Items[CorrelationId.HttpContextItemKey] = "correlation-1";
        return context;
    }

    private sealed class CapturingLogger<T> : ILogger<T>
    {
        private readonly List<Dictionary<string, object?>> activeScopes = [];

        public List<CapturedLogEntry> Entries { get; } = [];

        public IDisposable BeginScope<TState>(TState state)
            where TState : notnull
        {
            var scope = state as Dictionary<string, object?> ?? [];
            activeScopes.Add(scope);
            return new Scope(this, scope);
        }

        public bool IsEnabled(LogLevel logLevel) => true;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            Entries.Add(new CapturedLogEntry(
                logLevel,
                formatter(state, exception),
                activeScopes.Select(scope => new Dictionary<string, object?>(scope)).ToArray(),
                exception));
        }

        private sealed class Scope(CapturingLogger<T> logger, Dictionary<string, object?> scope) : IDisposable
        {
            public void Dispose()
            {
                logger.activeScopes.Remove(scope);
            }
        }
    }

    private sealed record CapturedLogEntry(
        LogLevel Level,
        string Message,
        IReadOnlyList<Dictionary<string, object?>> Scopes,
        Exception? Exception);

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
