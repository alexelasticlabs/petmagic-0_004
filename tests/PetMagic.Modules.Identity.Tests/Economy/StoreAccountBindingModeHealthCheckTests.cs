using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StoreAccountBindingModeHealthCheckTests
{
    [Fact]
    public async Task CheckHealthAsync_ShouldDegrade_WhenProductionUsesCompatibilityMode()
    {
        var healthCheck = CreateHealthCheck("Production", "compatibility");

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Degraded, result.Status);
        Assert.Equal("compatibility", result.Data["mode"]);
    }

    [Theory]
    [InlineData("Development", "compatibility")]
    [InlineData("Production", "enforce")]
    public async Task CheckHealthAsync_ShouldBeHealthy_WhenBindingRiskIsNotActive(
        string environmentName,
        string mode)
    {
        var healthCheck = CreateHealthCheck(environmentName, mode);

        var result = await healthCheck.CheckHealthAsync(new HealthCheckContext());

        Assert.Equal(HealthStatus.Healthy, result.Status);
    }

    private static StoreAccountBindingModeHealthCheck CreateHealthCheck(string environmentName, string mode) =>
        new(
            Options.Create(new EconomyOptions { StoreAccountBindingMode = mode }),
            new TestHostEnvironment { EnvironmentName = environmentName });

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = Directory.GetCurrentDirectory();

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
