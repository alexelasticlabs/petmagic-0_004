using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Middleware;
using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RequestDrainingMiddlewareTests
{
    [Fact]
    public async Task StoppingHost_ShouldReturnSafeProblemDetailsWithStableCode()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(RequestDrainingMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Configuration["AllowedHosts"] = "*";
        builder.Services.AddSingleton<GracefulShutdownCoordinator>();

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseMiddleware<RequestDrainingMiddleware>();
        app.MapGet("/api/users/{userId:guid}/drain", (Guid userId) => Results.Ok());

        var coordinator = app.Services.GetRequiredService<GracefulShutdownCoordinator>();
        coordinator.SignalStopping();
        await app.StartAsync();

        var sensitiveUserId = Guid.Parse("c906db54-6926-4458-bcd2-52541d8b0e65");
        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("http://localhost");
        using var request = new HttpRequestMessage(HttpMethod.Get, $"/api/users/{sensitiveUserId:D}/drain");
        request.Headers.Add(CorrelationId.HeaderName, "draining-correlation");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var headerValues));
        Assert.Equal("draining-correlation", Assert.Single(headerValues));
        Assert.True(response.Headers.TryGetValues("Retry-After", out var retryAfterValues));
        Assert.Equal("10", Assert.Single(retryAfterValues));
        Assert.NotNull(body);
        Assert.Equal("SERVICE_DRAINING", body!["title"]?.ToString());
        Assert.Equal("SERVICE_DRAINING", body["code"]?.ToString());
        Assert.False(body.ContainsKey("detail"));
        Assert.Equal("draining-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
        Assert.True(body.TryGetValue("instance", out var instance));
        Assert.DoesNotContain(sensitiveUserId.ToString("D"), instance?.ToString(), StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("shutting down", await response.Content.ReadAsStringAsync(), StringComparison.OrdinalIgnoreCase);
    }
}
