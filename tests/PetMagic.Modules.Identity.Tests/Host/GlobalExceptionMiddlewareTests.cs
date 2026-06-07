using System.Net;
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

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseMiddleware<GlobalExceptionMiddleware>();
        app.MapGet("/boom", () =>
        {
            throw new InvalidOperationException("secret-provider-token");
#pragma warning disable CS0162
            return Results.Ok();
#pragma warning restore CS0162
        });
        await app.StartAsync();

        using var request = new HttpRequestMessage(HttpMethod.Get, "/boom");
        request.Headers.Add(CorrelationId.HeaderName, "global-exception-correlation");

        using var response = await app.GetTestClient().SendAsync(request);
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
        Assert.Equal("global-exception-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
    }
}
