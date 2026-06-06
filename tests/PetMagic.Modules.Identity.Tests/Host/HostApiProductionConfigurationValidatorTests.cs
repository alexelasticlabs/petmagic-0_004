using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Security;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class HostApiProductionConfigurationValidatorTests
{
    [Theory]
    [InlineData("http://localhost:3000")]
    [InlineData("https://localhost")]
    [InlineData("http://admin.petmagic.app")]
    [InlineData("*")]
    [InlineData("")]
    public void ValidateCorsAllowedOrigins_ShouldRejectUnsafeOriginsOutsideDevelopment(string origin)
    {
        var environment = CreateEnvironment(Environments.Production);

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateCorsAllowedOrigins([origin], environment));

        Assert.Contains("Cors:AllowedOrigins", exception.Message);
    }

    [Fact]
    public void ValidateCorsAllowedOrigins_ShouldRejectMissingOriginsOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateCorsAllowedOrigins([], environment));

        Assert.Contains("Cors:AllowedOrigins", exception.Message);
    }

    [Fact]
    public void ValidateCorsAllowedOrigins_ShouldAllowHttpsOriginsOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);

        HostApiProductionConfigurationValidator.ValidateCorsAllowedOrigins(
            ["https://admin.petmagic.app", "https://petmagic.app"],
            environment);
    }

    [Fact]
    public void ValidateCorsAllowedOrigins_ShouldAllowLocalOriginsInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);

        HostApiProductionConfigurationValidator.ValidateCorsAllowedOrigins(
            ["http://localhost:3000"],
            environment);
    }

    private static TestHostEnvironment CreateEnvironment(string environmentName)
    {
        return new TestHostEnvironment
        {
            EnvironmentName = environmentName
        };
    }

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = Directory.GetCurrentDirectory();

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
