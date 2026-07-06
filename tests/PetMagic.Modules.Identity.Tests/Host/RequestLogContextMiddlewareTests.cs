using System.Security.Claims;

using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RequestLogContextMiddlewareTests
{
    [Fact]
    public async Task Middleware_ShouldAttachAmbientRequestContextToBusinessLogs()
    {
        var provider = new CapturingLoggerProvider();
        using var loggerFactory = LoggerFactory.Create(builder => builder.AddProvider(provider));
        var businessLogger = loggerFactory.CreateLogger("PetMagic.Business");
        var context = CreateContext();

        var middleware = new RequestLogContextMiddleware(
            _ =>
            {
                businessLogger.LogInformation(
                    "Admin action completed. TargetId={TargetId}",
                    "target-user-1");
                return Task.CompletedTask;
            },
            loggerFactory.CreateLogger<RequestLogContextMiddleware>());

        await middleware.InvokeAsync(context);

        var entry = Assert.Single(provider.Entries);
        Assert.Equal(LogLevel.Information, entry.Level);
        Assert.Equal("PetMagic.Business", entry.Category);

        var scope = Assert.Single(entry.Scopes);
        Assert.Equal("PetMagic.Host.Api", scope["ApplicationName"]);
        Assert.Equal(Environments.Staging, scope["Environment"]);
        Assert.Equal("request-1", scope["TraceId"]);
        Assert.Equal(SafeLogValues.StableHash("correlation-1"), scope["CorrelationIdHash"]);
        Assert.Equal(SafeLogValues.StableHash("request-1"), scope["RequestIdHash"]);
        Assert.Equal(SafeLogValues.StableHash("user-1"), scope["UserIdHash"]);
        Assert.Equal("Admin,Support", scope["Role"]);
        Assert.Equal("PATCH /api/admin/users/{id}/role", scope["Endpoint"]);
        Assert.Equal("PATCH", scope["HttpMethod"]);
        Assert.Equal("/api/admin/users/{id}/role", scope["Path"]);
        Assert.Equal(SafeLogValues.StableHash("/api/admin/users/user-2/role"), scope["PathHash"]);
        Assert.DoesNotContain("CorrelationId", scope.Keys);
        Assert.DoesNotContain("RequestId", scope.Keys);
        Assert.DoesNotContain("UserId", scope.Keys);
    }

    private static DefaultHttpContext CreateContext()
    {
        var services = new ServiceCollection()
            .AddSingleton<IHostEnvironment>(new TestHostEnvironment { EnvironmentName = Environments.Staging })
            .BuildServiceProvider();
        var context = new DefaultHttpContext
        {
            RequestServices = services
        };
        context.Request.Method = HttpMethods.Patch;
        context.Request.Path = "/api/admin/users/user-2/role";
        context.TraceIdentifier = "request-1";
        context.Items[CorrelationId.HttpContextItemKey] = "correlation-1";
        context.SetEndpoint(new Endpoint(
            _ => Task.CompletedTask,
            new EndpointMetadataCollection(),
            "PATCH /api/admin/users/{id}/role"));
        context.User = new ClaimsPrincipal(new ClaimsIdentity(
            [
                new Claim("sub", "user-1"),
                new Claim(ClaimTypes.Role, "Support"),
                new Claim(ClaimTypes.Role, "Admin")
            ],
            authenticationType: "Test"));

        return context;
    }

    private sealed class CapturingLoggerProvider : ILoggerProvider, ISupportExternalScope
    {
        private IExternalScopeProvider scopeProvider = new LoggerExternalScopeProvider();

        public List<CapturedLogEntry> Entries { get; } = [];

        public ILogger CreateLogger(string categoryName)
        {
            return new CapturingLogger(categoryName, this);
        }

        public void SetScopeProvider(IExternalScopeProvider provider)
        {
            scopeProvider = provider;
        }

        public void Dispose()
        {
        }

        private sealed class CapturingLogger(string categoryName, CapturingLoggerProvider provider) : ILogger
        {
            public IDisposable BeginScope<TState>(TState state)
                where TState : notnull
            {
                return provider.scopeProvider.Push(state);
            }

            public bool IsEnabled(LogLevel logLevel) => true;

            public void Log<TState>(
                LogLevel logLevel,
                EventId eventId,
                TState state,
                Exception? exception,
                Func<TState, Exception?, string> formatter)
            {
                var scopes = new List<Dictionary<string, object?>>();
                provider.scopeProvider.ForEachScope(static (scope, capturedScopes) =>
                {
                    if (scope is IEnumerable<KeyValuePair<string, object?>> pairs)
                    {
                        capturedScopes.Add(pairs.ToDictionary(pair => pair.Key, pair => pair.Value));
                    }
                }, scopes);

                provider.Entries.Add(new CapturedLogEntry(
                    categoryName,
                    logLevel,
                    formatter(state, exception),
                    scopes));
            }
        }
    }

    private sealed record CapturedLogEntry(
        string Category,
        LogLevel Level,
        string Message,
        IReadOnlyList<Dictionary<string, object?>> Scopes);

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = AppContext.BaseDirectory;

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
