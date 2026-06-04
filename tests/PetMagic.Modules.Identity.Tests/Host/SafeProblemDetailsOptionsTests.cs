using System.Net;
using System.Net.Http.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;
using PetMagic.Host.Api.Security;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class SafeProblemDetailsOptionsTests
{
    [Fact]
    public async Task ExceptionHandler_ShouldReturnSafeProblemDetails_InProduction()
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Production,
            ApplicationName = typeof(SafeProblemDetailsOptionsTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();
        builder.Services.AddProblemDetails(SafeProblemDetailsOptions.Configure);

        await using var app = builder.Build();
        app.UseMiddleware<CorrelationIdMiddleware>();
        app.UseExceptionHandler();
        app.MapGet("/boom", () =>
        {
            throw new InvalidOperationException("secret-provider-token");
#pragma warning disable CS0162
            return Results.Ok();
#pragma warning restore CS0162
        });
        await app.StartAsync();

        using var request = new HttpRequestMessage(HttpMethod.Get, "/boom");
        request.Headers.Add(CorrelationId.HeaderName, "problem-correlation");

        using var response = await app.GetTestClient().SendAsync(request);
        var rawBody = await response.Content.ReadAsStringAsync();
        var body = await response.Content.ReadFromJsonAsync<Dictionary<string, object?>>();

        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        Assert.DoesNotContain("secret-provider-token", rawBody);
        Assert.DoesNotContain(nameof(InvalidOperationException), rawBody);
        Assert.NotNull(body);
        Assert.Equal("INTERNAL_SERVER_ERROR", body!["title"]?.ToString());
        Assert.Equal("INTERNAL_SERVER_ERROR", body["code"]?.ToString());
        Assert.Equal("problem-correlation", body["correlationId"]?.ToString());
        Assert.False(string.IsNullOrWhiteSpace(body["traceId"]?.ToString()));
    }
}
