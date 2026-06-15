using System.Net;
using System.Net.Http.Json;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;
using PetMagic.Host.Api.Security;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RateLimitProblemResponseTests
{
    [Fact]
    public async Task RateLimitRejection_ShouldReturnProblemDetailsWithCorrelationId()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(RateLimitProblemResponseTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Services.AddRateLimiter(options =>
        {
            options.OnRejected = RateLimitProblemResponse.WriteAsync;
            options.AddPolicy("limited", _ =>
                RateLimitPartition.GetFixedWindowLimiter(
                    "tests",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 1,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));
        });

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseRateLimiter();
        app.MapGet("/limited", () => Results.Ok()).RequireRateLimiting("limited");
        await app.StartAsync();

        using var firstRequest = new HttpRequestMessage(HttpMethod.Get, "/limited");
        firstRequest.Headers.Add(CorrelationId.HeaderName, "warmup-correlation");
        using var firstResponse = await app.GetTestClient().SendAsync(firstRequest);
        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);

        using var request = new HttpRequestMessage(HttpMethod.Get, "/limited");
        request.Headers.Add(CorrelationId.HeaderName, "rate-limit-correlation");
        using var response = await app.GetTestClient().SendAsync(request);
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var headerValues));
        Assert.Equal("rate-limit-correlation", Assert.Single(headerValues));
        Assert.NotNull(body);
        Assert.Equal("RATE_LIMIT_EXCEEDED", body!["title"]?.ToString());
        Assert.Equal("RATE_LIMIT_EXCEEDED", body["code"]?.ToString());
        Assert.Equal("rate-limit-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
    }

    [Fact]
    public async Task RateLimitRejection_ShouldCreateCorrelationIdWhenHeaderIsMissing()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(RateLimitProblemResponseTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Services.AddRateLimiter(options =>
        {
            options.OnRejected = RateLimitProblemResponse.WriteAsync;
            options.AddPolicy("limited", _ =>
                RateLimitPartition.GetFixedWindowLimiter(
                    "missing-correlation-tests",
                    _ => new FixedWindowRateLimiterOptions
                    {
                        PermitLimit = 1,
                        Window = TimeSpan.FromMinutes(1),
                        QueueLimit = 0
                    }));
        });

        await using var app = builder.Build();
        app.UseRateLimiter();
        app.MapGet("/limited", () => Results.Ok()).RequireRateLimiting("limited");
        await app.StartAsync();

        using var firstResponse = await app.GetTestClient().GetAsync("/limited");
        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);

        using var response = await app.GetTestClient().GetAsync("/limited");
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.TooManyRequests, response.StatusCode);
        Assert.True(response.Headers.TryGetValues(CorrelationId.HeaderName, out var headerValues));
        var correlationId = Assert.Single(headerValues);
        Assert.False(string.IsNullOrWhiteSpace(correlationId));
        Assert.NotNull(body);
        Assert.Equal(correlationId, body!["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
    }
}
