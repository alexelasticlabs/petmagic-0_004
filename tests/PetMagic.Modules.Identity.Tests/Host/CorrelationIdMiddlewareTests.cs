using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class CorrelationIdMiddlewareTests
{
    [Fact]
    public async Task Middleware_ShouldEchoValidCorrelationId()
    {
        await using var app = await CreateAppAsync();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/ping");
        request.Headers.Add(CorrelationId.HeaderName, "test-correlation-123");

        using var response = await app.GetTestClient().SendAsync(request);

        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var values));
        Assert.Equal("test-correlation-123", Assert.Single(values));
    }

    [Fact]
    public async Task Middleware_ShouldReplaceInvalidCorrelationId()
    {
        await using var app = await CreateAppAsync();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/ping");
        request.Headers.Add(CorrelationId.HeaderName, "invalid correlation id with spaces");

        using var response = await app.GetTestClient().SendAsync(request);

        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var values));
        var generated = Assert.Single(values);
        Assert.NotEqual("invalid correlation id with spaces", generated);
        Assert.True(CorrelationId.IsValid(generated));
    }

    [Fact]
    public void Middleware_ShouldHashCorrelationIdBeforeAddingLogAndActivityContext()
    {
        var source = File.ReadAllText(ResolveRepositoryPath(Path.Combine(
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Observability",
            "CorrelationIdMiddleware.cs")));

        Assert.Contains("SafeLogValues.StableHash(correlationId)", source, StringComparison.Ordinal);
        Assert.Contains("Activity.Current?.SetTag(\"correlation.id_hash\", correlationIdHash)", source, StringComparison.Ordinal);
        Assert.Contains("LogContext.PushProperty(\"CorrelationIdHash\", correlationIdHash)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Activity.Current?.SetTag(\"correlation.id\", correlationId)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("LogContext.PushProperty(\"CorrelationId\", correlationId)", source, StringComparison.Ordinal);
    }

    private static string ResolveRepositoryPath(string relativePath)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(directory.FullName, relativePath);
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException($"Could not resolve repository file '{relativePath}'.");
    }

    private static async Task<WebApplication> CreateAppAsync()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(CorrelationIdMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Configuration["AllowedHosts"] = "*";

        var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.MapGet("/ping", () => Results.Ok(new { status = "ok" }));

        await app.StartAsync();
        return app;
    }
}
