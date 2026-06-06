using System.Net;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class RequestMetricsMiddlewareTests
{
    [Fact]
    public async Task Middleware_ShouldEmitRequestErrorMetric_ForErrorResponse()
    {
        using var recorder = new MeterMeasurementRecorder(HostApiMetrics.MeterName, "request_errors_total");
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(RequestMetricsMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();

        await using var app = builder.Build();
        app.UseMiddleware<RequestMetricsMiddleware>();
        app.MapGet("/bad-request", () => Results.BadRequest());
        await app.StartAsync();

        using var response = await app.GetTestClient().GetAsync("/bad-request");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains(
            recorder.Measurements,
            measurement => measurement.InstrumentName == "request_errors_total"
                && measurement.Value == 1
                && Equals(measurement.Tags["method"], "GET")
                && Equals(measurement.Tags["status_code"], 400)
                && Equals(measurement.Tags["error_kind"], "status"));
    }

    [Fact]
    public async Task Middleware_ShouldEmitRequestDurationMetric()
    {
        using var recorder = new MeterMeasurementRecorder(HostApiMetrics.MeterName, "request_duration_seconds");
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            EnvironmentName = Environments.Development,
            ApplicationName = typeof(RequestMetricsMiddlewareTests).Assembly.FullName,
        });
        builder.WebHost.UseTestServer();

        await using var app = builder.Build();
        app.UseMiddleware<RequestMetricsMiddleware>();
        app.MapGet("/ok", () => Results.Ok());
        await app.StartAsync();

        using var response = await app.GetTestClient().GetAsync("/ok");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Contains(
            recorder.Measurements,
            measurement => measurement.InstrumentName == "request_duration_seconds"
                && measurement.Value >= 0
                && Equals(measurement.Tags["method"], "GET")
                && Equals(measurement.Tags["status_code"], 200));
    }
}
