using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Middleware;
using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RequestTimeoutMiddlewareTests
{
    [Fact]
    public async Task TimedOutRequest_ShouldReturnStableProblemCodeWithoutDetail()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Production,
            ApplicationName = typeof(RequestTimeoutMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Configuration["AllowedHosts"] = "*";

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseMiddleware<RequestTimeoutMiddleware>(TimeSpan.FromMilliseconds(10));
        app.MapGet("/api/users/{userId:guid}/slow", static async (Guid userId, CancellationToken cancellationToken) =>
        {
            await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
            return Results.Ok();
        });
        await app.StartAsync();

        var sensitiveUserId = Guid.Parse("08ba4f62-e251-4e5b-8e49-07d8e38c4e1c");
        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("http://localhost");
        using var request = new HttpRequestMessage(HttpMethod.Get, $"/api/users/{sensitiveUserId:D}/slow");
        request.Headers.Add(CorrelationId.HeaderName, "timeout-correlation");
        request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.GatewayTimeout, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var headerValues));
        Assert.Equal("timeout-correlation", Assert.Single(headerValues));
        Assert.NotNull(body);
        Assert.Equal("REQUEST_TIMEOUT", body!["title"]?.ToString());
        Assert.Equal("REQUEST_TIMEOUT", body["code"]?.ToString());
        Assert.False(body.ContainsKey("detail"));
        Assert.Equal("timeout-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
        Assert.True(body.TryGetValue("instance", out var instance));
        Assert.DoesNotContain(sensitiveUserId.ToString("D"), instance?.ToString(), StringComparison.OrdinalIgnoreCase);
    }
}
