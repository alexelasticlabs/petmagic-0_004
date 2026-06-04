using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityInfrastructureConfigurationTests
{
    [Fact]
    public async Task AddIdentityInfrastructure_ShouldReadGoogleSettingsFromEnvironment()
    {
        const string clientId = "google-client-id";
        const string clientSecret = "google-client-secret";

        Environment.SetEnvironmentVariable("GOOGLE_CLIENT_ID", clientId);
        Environment.SetEnvironmentVariable("GOOGLE_CLIENT_SECRET", clientSecret);

        try
        {
            var services = CreateServices();
            var configuration = CreateConfiguration([]);

            services.AddIdentityInfrastructure(configuration);

            using var provider = services.BuildServiceProvider();
            var schemes = provider.GetRequiredService<IAuthenticationSchemeProvider>();
            var emailOptions = provider.GetRequiredService<EmailOptions>();

            var googleScheme = await schemes.GetSchemeAsync("Google");

            Assert.NotNull(googleScheme);
            Assert.Equal("Google", googleScheme!.Name);
            Assert.False(emailOptions.IsConfigured);
        }
        finally
        {
            Environment.SetEnvironmentVariable("GOOGLE_CLIENT_ID", null);
            Environment.SetEnvironmentVariable("GOOGLE_CLIENT_SECRET", null);
        }
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldRejectIncompleteGoogleConfiguration()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["ExternalAuth:Google:ClientId"] = "google-client-id"
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddIdentityInfrastructure(configuration));

        Assert.Contains("Google external auth configuration is incomplete", exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldRejectIncompleteAppleConfiguration()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["ExternalAuth:Apple:ClientId"] = "apple-client-id",
            ["ExternalAuth:Apple:ClientSecret"] = "apple-client-secret"
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddIdentityInfrastructure(configuration));

        Assert.Contains("Apple external auth configuration is incomplete", exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldRejectBootstrapAdminPassword_InProduction()
    {
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };
        var services = CreateServices(environment);
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["BootstrapAdmin:Email"] = "admin@petmagic.app",
            ["BootstrapAdmin:Password"] = "DemoPassword123!"
        });

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddIdentityInfrastructure(configuration, environment));

        Assert.Contains("BootstrapAdmin:Password must not be configured outside development", exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldAllowEmptyBootstrapAdmin_InProduction()
    {
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };
        var services = CreateServices(environment);
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["BootstrapAdmin:Email"] = "",
            ["BootstrapAdmin:Password"] = "",
            ["Email:DispatchWorkerEnabled"] = "false"
        });

        services.AddIdentityInfrastructure(configuration, environment);
    }

    private static IConfiguration CreateConfiguration(IEnumerable<KeyValuePair<string, string?>> values)
    {
        var defaults = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = "Host=localhost;Database=petmagic_tests;Username=test;Password=test",
            ["Jwt:Issuer"] = "petmagic-tests",
            ["Jwt:Audience"] = "petmagic-tests",
            ["Jwt:SigningKey"] = "1234567890123456789012345678901234567890123456789012345678901234"
        };

        foreach (var value in values)
        {
            defaults[value.Key] = value.Value;
        }

        return new ConfigurationBuilder()
            .AddInMemoryCollection(defaults)
            .Build();
    }

    private static ServiceCollection CreateServices(IHostEnvironment? environment = null)
    {
        var services = new ServiceCollection();
        services.AddLogging();
        services.AddSingleton(environment ?? new TestHostEnvironment(Directory.GetCurrentDirectory()));
        return services;
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new PhysicalFileProvider(contentRootPath);
    }
}
