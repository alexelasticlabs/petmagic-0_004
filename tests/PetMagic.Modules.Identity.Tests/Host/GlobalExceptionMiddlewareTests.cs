using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class GlobalExceptionMiddlewareTests
{
    [Fact]
    public async Task Middleware_ShouldReturnSafeProblemDetailsWithCorrelationId_InProduction()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Production,
            ApplicationName = typeof(GlobalExceptionMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Configuration["AllowedHosts"] = "*";

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseMiddleware<GlobalExceptionMiddleware>();
        app.MapGet("/api/users/{userId:guid}/boom", static IResult (Guid userId) => throw new InvalidOperationException("secret-provider-token"));
        await app.StartAsync();

        var sensitiveUserId = Guid.Parse("c8249f11-33de-47dc-b7dd-b3206ae421a9");
        using var request = new HttpRequestMessage(HttpMethod.Get, $"/api/users/{sensitiveUserId:D}/boom");
        request.Headers.Add(CorrelationId.HeaderName, "global-exception-correlation");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("http://localhost");
        using var response = await client.SendAsync(request);
        var rawBody = await response.Content.ReadAsStringAsync();
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var values));
        Assert.Equal("global-exception-correlation", Assert.Single(values));
        Assert.DoesNotContain("secret-provider-token", rawBody);
        Assert.DoesNotContain(nameof(InvalidOperationException), rawBody);
        Assert.NotNull(body);
        Assert.Equal("INTERNAL_SERVER_ERROR", body!["title"]?.ToString());
        Assert.Equal("INTERNAL_SERVER_ERROR", body["code"]?.ToString());
        Assert.False(body.ContainsKey("detail"));
        Assert.Equal("global-exception-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
        Assert.True(body.TryGetValue("instance", out var instance));
        Assert.DoesNotContain(sensitiveUserId.ToString("D"), instance?.ToString(), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void MiddlewareLogs_ShouldNotSerializeRawExceptions()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.Api",
            "Observability",
            "GlobalExceptionMiddleware.cs"));

        Assert.DoesNotContain("logger.LogError(\r\n                exception,", source, StringComparison.Ordinal);
        Assert.Contains("ExceptionType={ExceptionType}", source, StringComparison.Ordinal);
        Assert.Contains("{SafePath}", source, StringComparison.Ordinal);
        Assert.DoesNotContain("{RequestPath}", source, StringComparison.Ordinal);
        Assert.Contains("SafeLogValues.ExceptionType(exception)", source, StringComparison.Ordinal);
        Assert.Contains("RequestLogging.ResolveSafePath(context)", source, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "src"))
                && Directory.Exists(Path.Combine(current.FullName, "tests")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
