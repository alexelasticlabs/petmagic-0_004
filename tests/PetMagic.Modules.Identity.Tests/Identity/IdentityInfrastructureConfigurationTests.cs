using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

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
    public void AddIdentityInfrastructure_ShouldReadExternalAuthAudiencesFromEnvironment()
    {
        SetEnvironmentVariables(new Dictionary<string, string?>
        {
            ["GOOGLE_CLIENT_ID"] = "google-web-client-id",
            ["GOOGLE_CLIENT_SECRET"] = "google-client-secret",
            ["GOOGLE_AUDIENCES"] = " google-web-client-id,google-ios-client-id ,, google-android-client-id ",
            ["APPLE_CLIENT_ID"] = "com.petmagic.app",
            ["APPLE_CLIENT_SECRET"] = "apple-client-secret",
            ["APPLE_AUTHORIZATION_ENDPOINT"] = "https://appleid.apple.com/auth/authorize",
            ["APPLE_TOKEN_ENDPOINT"] = "https://appleid.apple.com/auth/token",
            ["APPLE_AUDIENCES"] = " com.petmagic.app,com.petmagic.service "
        });

        try
        {
            var services = CreateServices();
            var configuration = CreateConfiguration([]);

            services.AddIdentityInfrastructure(configuration);

            using var provider = services.BuildServiceProvider();
            var options = provider.GetRequiredService<ExternalAuthOptions>();

            Assert.Equal(
                ["google-web-client-id", "google-ios-client-id", "google-android-client-id"],
                options.Google.Audiences);
            Assert.Equal(["com.petmagic.app", "com.petmagic.service"], options.Apple.Audiences);
        }
        finally
        {
            ClearEnvironmentVariables(
                "GOOGLE_CLIENT_ID",
                "GOOGLE_CLIENT_SECRET",
                "GOOGLE_AUDIENCES",
                "APPLE_CLIENT_ID",
                "APPLE_CLIENT_SECRET",
                "APPLE_AUTHORIZATION_ENDPOINT",
                "APPLE_TOKEN_ENDPOINT",
                "APPLE_AUDIENCES");
        }
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldPreferConfiguredAudienceArraysOverEnvironment()
    {
        Environment.SetEnvironmentVariable("GOOGLE_AUDIENCES", "google-env-client-id");
        Environment.SetEnvironmentVariable("APPLE_AUDIENCES", "apple.env.service");

        try
        {
            var services = CreateServices();
            var configuration = CreateConfiguration(new Dictionary<string, string?>
            {
                ["ExternalAuth:Google:ClientId"] = "google-web-client-id",
                ["ExternalAuth:Google:ClientSecret"] = "google-client-secret",
                ["ExternalAuth:Google:Audiences:0"] = "google-web-client-id",
                ["ExternalAuth:Google:Audiences:1"] = " google-ios-client-id ",
                ["ExternalAuth:Apple:ClientId"] = "com.petmagic.app",
                ["ExternalAuth:Apple:ClientSecret"] = "apple-client-secret",
                ["ExternalAuth:Apple:AuthorizationEndpoint"] = "https://appleid.apple.com/auth/authorize",
                ["ExternalAuth:Apple:TokenEndpoint"] = "https://appleid.apple.com/auth/token",
                ["ExternalAuth:Apple:Audiences:0"] = "com.petmagic.app",
                ["ExternalAuth:Apple:Audiences:1"] = " com.petmagic.service "
            });

            services.AddIdentityInfrastructure(configuration);

            using var provider = services.BuildServiceProvider();
            var options = provider.GetRequiredService<ExternalAuthOptions>();

            Assert.Equal(["google-web-client-id", "google-ios-client-id"], options.Google.Audiences);
            Assert.Equal(["com.petmagic.app", "com.petmagic.service"], options.Apple.Audiences);
        }
        finally
        {
            ClearEnvironmentVariables("GOOGLE_AUDIENCES", "APPLE_AUDIENCES");
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

    [Theory]
    [InlineData("ExternalAuth:Apple:AuthorizationEndpoint", "http://appleid.apple.com/auth/authorize", "must use HTTPS")]
    [InlineData("ExternalAuth:Apple:AuthorizationEndpoint", "https://localhost/auth/authorize", "must not point to a local or private network host")]
    [InlineData("ExternalAuth:Apple:AuthorizationEndpoint", "https://[fc00::1]/auth/authorize", "must not point to a local or private network host")]
    [InlineData("ExternalAuth:Apple:TokenEndpoint", "https://user:secret@appleid.apple.com/auth/token", "must not contain credentials")]
    [InlineData("ExternalAuth:Apple:TokenEndpoint", "https://appleid.apple.com/auth/token?client_secret=leak", "must not contain credentials")]
    public void AddIdentityInfrastructure_ShouldRejectUnsafeAppleExternalAuthEndpoints(
        string setting,
        string endpoint,
        string expectedMessage)
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["ExternalAuth:Apple:ClientId"] = "com.petmagic.app",
            ["ExternalAuth:Apple:ClientSecret"] = "apple-client-secret",
            ["ExternalAuth:Apple:AuthorizationEndpoint"] = "https://appleid.apple.com/auth/authorize",
            ["ExternalAuth:Apple:TokenEndpoint"] = "https://appleid.apple.com/auth/token",
            [setting] = endpoint
        });

        var exception = Assert.Throws<InvalidOperationException>(() => services.AddIdentityInfrastructure(configuration));

        Assert.Contains(setting, exception.Message);
        Assert.Contains(expectedMessage, exception.Message);
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
    public void AddIdentityInfrastructure_ShouldRejectPlaceholderJwtSigningKey_InProduction()
    {
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };
        var services = CreateServices(environment);
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Jwt:SigningKey"] = "SUPER_CHANGE_ME_IN_PROD_64_BYTES_MINIMUM___________"
        });

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddIdentityInfrastructure(configuration, environment));

        Assert.Contains("Jwt:SigningKey contains a placeholder value", exception.Message);
    }

    [Theory]
    [InlineData("Jwt:Issuer", "Jwt:Issuer must be configured outside development.")]
    [InlineData("Jwt:Audience", "Jwt:Audience must be configured outside development.")]
    public void AddIdentityInfrastructure_ShouldRejectMissingJwtIssuerOrAudience_InProduction(
        string setting,
        string expectedMessage)
    {
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Production
        };
        var services = CreateServices(environment);
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            [setting] = ""
        });

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddIdentityInfrastructure(configuration, environment));

        Assert.Contains(expectedMessage, exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldConfigureStrictJwtBearerValidation()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);

        services.AddIdentityInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<IOptionsMonitor<JwtBearerOptions>>()
            .Get(JwtBearerDefaults.AuthenticationScheme);

        Assert.True(options.TokenValidationParameters.ValidateIssuer);
        Assert.True(options.TokenValidationParameters.ValidateAudience);
        Assert.True(options.TokenValidationParameters.ValidateLifetime);
        Assert.True(options.TokenValidationParameters.ValidateIssuerSigningKey);
        Assert.Equal(TimeSpan.FromMinutes(1), options.TokenValidationParameters.ClockSkew);
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

    [Fact]
    public void AddIdentityInfrastructure_ShouldAllowLocalSmtpWithoutCredentials_InDevelopment()
    {
        var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
        {
            EnvironmentName = Environments.Development
        };
        var services = CreateServices(environment);
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Email:Host"] = "mailpit",
            ["Email:Port"] = "1025",
            ["Email:UseSsl"] = "false",
            ["Email:FromAddress"] = "no-reply@petmagic.app",
            ["Email:Username"] = "",
            ["Email:Password"] = ""
        });

        services.AddIdentityInfrastructure(configuration, environment);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<EmailOptions>();

        Assert.True(options.IsConfigured);
        Assert.False(options.HasCredentials);
        Assert.False(options.IsProductionConfigured);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldPreferEmailEnvironmentVariables()
    {
        SetEnvironmentVariables(new Dictionary<string, string?>
        {
            ["EMAIL_HOST"] = "mailpit",
            ["EMAIL_PORT"] = "1025",
            ["EMAIL_USE_SSL"] = "false",
            ["EMAIL_FROM_ADDRESS"] = "no-reply@petmagic.app"
        });

        try
        {
            var environment = new TestHostEnvironment(Directory.GetCurrentDirectory())
            {
                EnvironmentName = Environments.Development
            };
            var services = CreateServices(environment);
            var configuration = CreateConfiguration(new Dictionary<string, string?>
            {
                ["Email:Host"] = "smtp.example.com",
                ["Email:Port"] = "2525",
                ["Email:UseSsl"] = "true",
                ["Email:FromAddress"] = "appsettings@petmagic.app"
            });

            services.AddIdentityInfrastructure(configuration, environment);

            using var provider = services.BuildServiceProvider();
            var options = provider.GetRequiredService<EmailOptions>();

            Assert.Equal("mailpit", options.Host);
            Assert.Equal(1025, options.Port);
            Assert.False(options.UseSsl);
            Assert.Equal("no-reply@petmagic.app", options.FromAddress);
        }
        finally
        {
            ClearEnvironmentVariables(
                "EMAIL_HOST",
                "EMAIL_PORT",
                "EMAIL_USE_SSL",
                "EMAIL_FROM_ADDRESS");
        }
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldRejectSmtpWithoutCredentials_InProduction()
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
            ["Email:Host"] = "mailpit",
            ["Email:Port"] = "1025",
            ["Email:UseSsl"] = "false",
            ["Email:FromAddress"] = "no-reply@petmagic.app",
            ["Email:Username"] = "",
            ["Email:Password"] = ""
        });

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddIdentityInfrastructure(configuration, environment));

        Assert.Equal(
            "Email dispatch worker is enabled but SMTP configuration is incomplete.",
            exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldRejectSmtpWithoutTls_InProduction()
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
            ["Email:Host"] = "smtp.petmagic.app",
            ["Email:Port"] = "25",
            ["Email:UseSsl"] = "false",
            ["Email:FromAddress"] = "no-reply@petmagic.app",
            ["Email:Username"] = "smtp-user",
            ["Email:Password"] = "smtp-password"
        });

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddIdentityInfrastructure(configuration, environment));

        Assert.Equal(
            "Email:UseSsl must be enabled outside development when the email dispatch worker is enabled.",
            exception.Message);
    }

    [Fact]
    public void AddIdentityInfrastructure_ShouldUseShortLivedAvatarReadUrlsByDefault()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);

        services.AddIdentityInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<AvatarReadUrlSigningOptions>();

        Assert.Equal(60, options.ReadUrlTtlMinutes);
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

    private static void SetEnvironmentVariables(IReadOnlyDictionary<string, string?> values)
    {
        foreach (var (key, value) in values)
        {
            Environment.SetEnvironmentVariable(key, value);
        }
    }

    private static void ClearEnvironmentVariables(params string[] keys)
    {
        foreach (var key in keys)
        {
            Environment.SetEnvironmentVariable(key, null);
        }
    }

    private sealed class TestHostEnvironment(string contentRootPath) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = contentRootPath;

        public IFileProvider ContentRootFileProvider { get; set; } = new PhysicalFileProvider(contentRootPath);
    }
}
