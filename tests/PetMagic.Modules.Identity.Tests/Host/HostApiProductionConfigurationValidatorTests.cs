using System.Text.Json;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;

using PetMagic.Host.Api.Security;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class HostApiProductionConfigurationValidatorTests
{
    [Fact]
    public void BaseApiAppSettings_ShouldNotCarryLocalMediaOrCorsDefaults()
    {
        var root = FindRepositoryRoot();
        var appsettingsPath = Path.Combine(root, "src", "Host", "PetMagic.Host.Api", "appsettings.json");
        using var document = JsonDocument.Parse(File.ReadAllText(appsettingsPath));
        var appsettings = document.RootElement;

        Assert.Equal(string.Empty, appsettings
            .GetProperty("Identity")
            .GetProperty("AvatarStorage")
            .GetProperty("PublicBaseUrl")
            .GetString());
        Assert.Equal(string.Empty, appsettings
            .GetProperty("SupportChat")
            .GetProperty("AttachmentStorage")
            .GetProperty("PublicBaseUrl")
            .GetString());
        Assert.Equal(string.Empty, appsettings
            .GetProperty("Templates")
            .GetProperty("PublicBaseUrl")
            .GetString());
        Assert.Empty(appsettings
            .GetProperty("Cors")
            .GetProperty("AllowedOrigins")
            .EnumerateArray());
        Assert.False(appsettings.TryGetProperty("OpenTelemetry", out _));
    }

    [Fact]
    public void BaseGenerationWorkerAppSettings_ShouldNotCarryLocalOtlpEndpoint()
    {
        var root = FindRepositoryRoot();
        var appsettingsPath = Path.Combine(root, "src", "Host", "PetMagic.Host.GenerationWorker", "appsettings.json");
        using var document = JsonDocument.Parse(File.ReadAllText(appsettingsPath));

        Assert.False(document.RootElement.TryGetProperty("OpenTelemetry", out _));
    }

    [Theory]
    [InlineData("http://localhost:3000")]
    [InlineData("https://localhost")]
    [InlineData("https://127.0.0.2")]
    [InlineData("https://10.0.0.5")]
    [InlineData("https://172.16.0.5")]
    [InlineData("https://192.168.1.10")]
    [InlineData("https://169.254.169.254")]
    [InlineData("https://100.64.0.5")]
    [InlineData("https://[::1]")]
    [InlineData("https://[::]")]
    [InlineData("https://[fe80::1]")]
    [InlineData("https://[fc00::1]")]
    [InlineData("https://[fd00::1]")]
    [InlineData("http://admin.petmagic.app")]
    [InlineData("*")]
    [InlineData("")]
    [InlineData("https://admin.petmagic.app/path")]
    [InlineData("https://admin.petmagic.app?token=secret")]
    [InlineData("https://user:pass@admin.petmagic.app")]
    [InlineData("https://admin.petmagic.app#fragment")]
    [InlineData("https://example.com")]
    [InlineData("https://admin.example.com")]
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

    [Theory]
    [InlineData("")]
    [InlineData("*")]
    [InlineData("*.petmagic.app")]
    [InlineData("localhost")]
    [InlineData("127.0.0.1")]
    [InlineData("10.0.0.5")]
    [InlineData("192.168.1.10")]
    [InlineData("api.petmagic.app:5000")]
    [InlineData("https://api.petmagic.app")]
    [InlineData("api.petmagic.app/path")]
    [InlineData("replace_with_backend_host")]
    [InlineData("example.com")]
    [InlineData("api.example.com")]
    public void ValidateAllowedHosts_ShouldRejectMissingWildcardLocalOrMalformedHostsOutsideDevelopment(string allowedHosts)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                ["AllowedHosts"] = allowedHosts
            });

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateAllowedHosts(configuration, environment));

        Assert.Contains("AllowedHosts", exception.Message);
    }

    [Fact]
    public void ValidateAllowedHosts_ShouldAllowPublicHostsOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                ["AllowedHosts"] = "api.petmagic.app;admin-api.petmagic.app"
            });

        HostApiProductionConfigurationValidator.ValidateAllowedHosts(configuration, environment);
    }

    [Fact]
    public void ValidateAllowedHosts_ShouldAllowLocalWildcardInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);
        var configuration = CreateConfiguration(
            defaultConnectionString: "",
            additionalValues: new Dictionary<string, string?>
            {
                ["AllowedHosts"] = "*"
            });

        HostApiProductionConfigurationValidator.ValidateAllowedHosts(configuration, environment);
    }

    [Theory]
    [InlineData("")]
    [InlineData("Host=replace_with_host;Database=petmagic;Username=petmagic;Password=replace_with_password")]
    [InlineData("Host=<db-host>;Database=petmagic;Username=petmagic;Password=secret")]
    public void ValidateDefaultConnectionString_ShouldRejectMissingOrPlaceholderOutsideDevelopment(string connectionString)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(connectionString);

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateDefaultConnectionString(configuration, environment));

        Assert.Contains("ConnectionStrings:DefaultConnection", exception.Message);
    }

    [Fact]
    public void ValidateDefaultConnectionString_ShouldAllowConfiguredConnectionOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration("Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret");

        HostApiProductionConfigurationValidator.ValidateDefaultConnectionString(configuration, environment);
    }

    [Fact]
    public void ValidateDefaultConnectionString_ShouldAllowEmptyConnectionInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);
        var configuration = CreateConfiguration("");

        HostApiProductionConfigurationValidator.ValidateDefaultConnectionString(configuration, environment);
    }

    [Theory]
    [InlineData("")]
    [InlineData("CHANGE_ME_IN_PRODUCTION_64_BYTES_MINIMUM_SECRET_KEY_HERE_123456")]
    [InlineData("short-production-secret")]
    public void ValidateJwtSigningKey_ShouldRejectMissingPlaceholderOrShortKeysOutsideDevelopment(string signingKey)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            jwtSigningKey: signingKey);

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateJwtSigningKey(configuration, environment));

        Assert.Contains("Jwt:SigningKey", exception.Message);
    }

    [Fact]
    public void ValidateJwtSigningKey_ShouldAllowStrongConfiguredKeyOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            jwtSigningKey: new string('s', 64));

        HostApiProductionConfigurationValidator.ValidateJwtSigningKey(configuration, environment);
    }

    [Fact]
    public void ValidateJwtSigningKey_ShouldAllowEmptyKeyInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);
        var configuration = CreateConfiguration(
            defaultConnectionString: "",
            jwtSigningKey: "");

        HostApiProductionConfigurationValidator.ValidateJwtSigningKey(configuration, environment);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("https")]
    [InlineData("petmagic://")]
    public void ValidateExternalAuthMobileRedirectScheme_ShouldRejectMissingOrUnsafeSchemeOutsideDevelopment(
        string? scheme)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                ["ExternalAuth:MobileRedirectScheme"] = scheme
            });

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateExternalAuthMobileRedirectScheme(
                configuration,
                environment));

        Assert.Contains("ExternalAuth:MobileRedirectScheme", exception.Message);
    }

    [Fact]
    public void ValidateExternalAuthMobileRedirectScheme_ShouldAllowExplicitFlavorSchemeOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                ["ExternalAuth:MobileRedirectScheme"] = "petmagic-staging"
            });

        HostApiProductionConfigurationValidator.ValidateExternalAuthMobileRedirectScheme(
            configuration,
            environment);
    }

    [Fact]
    public void ValidateExternalAuthMobileRedirectScheme_ShouldAllowLocalDefaultInDevelopment()
    {
        HostApiProductionConfigurationValidator.ValidateExternalAuthMobileRedirectScheme(
            CreateConfiguration(defaultConnectionString: ""),
            CreateEnvironment(Environments.Development));
    }

    [Theory]
    [InlineData("Identity:AvatarStorage:PublicBaseUrl")]
    [InlineData("SupportChat:AttachmentStorage:PublicBaseUrl")]
    [InlineData("Templates:PublicBaseUrl")]
    public void ValidatePublicMediaBaseUrls_ShouldRejectMissingRequiredUrlsOutsideDevelopment(string settingName)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            publicBaseUrls: new Dictionary<string, string?>
            {
                ["Identity:AvatarStorage:PublicBaseUrl"] = "https://api.petmagic.app",
                ["SupportChat:AttachmentStorage:PublicBaseUrl"] = "https://api.petmagic.app/support-media",
                ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates"
            });
        configuration[settingName] = "";

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidatePublicMediaBaseUrls(configuration, environment));

        Assert.Contains(settingName, exception.Message);
    }

    [Theory]
    [InlineData("http://api.petmagic.app")]
    [InlineData("https://localhost:5000")]
    [InlineData("https://127.0.0.1:5000")]
    [InlineData("https://127.0.0.2:5000")]
    [InlineData("https://10.0.0.5:5000")]
    [InlineData("https://172.16.0.5:5000")]
    [InlineData("https://192.168.1.10:5000")]
    [InlineData("https://169.254.169.254:5000")]
    [InlineData("https://100.64.0.5:5000")]
    [InlineData("https://[::1]:5000")]
    [InlineData("https://[::]:5000")]
    [InlineData("https://[fe80::1]:5000")]
    [InlineData("https://[fc00::1]:5000")]
    [InlineData("https://[fd00::1]:5000")]
    [InlineData("https://user:pass@api.petmagic.app")]
    [InlineData("https://api.petmagic.app/media?token=secret")]
    [InlineData("https://api.petmagic.app/media#assets")]
    [InlineData("https://replace_with_media_host")]
    [InlineData("https://example.com/media")]
    [InlineData("https://cdn.example.com/media")]
    public void ValidatePublicMediaBaseUrls_ShouldRejectUnsafeUrlsOutsideDevelopment(string publicBaseUrl)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            publicBaseUrls: new Dictionary<string, string?>
            {
                ["Identity:AvatarStorage:PublicBaseUrl"] = publicBaseUrl,
                ["SupportChat:AttachmentStorage:PublicBaseUrl"] = "https://api.petmagic.app/support-media",
                ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates"
            });

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidatePublicMediaBaseUrls(configuration, environment));

        Assert.Contains("Identity:AvatarStorage:PublicBaseUrl", exception.Message);
    }

    [Fact]
    public void ValidatePublicMediaBaseUrls_ShouldAllowHttpsUrlsOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            publicBaseUrls: new Dictionary<string, string?>
            {
                ["Identity:AvatarStorage:PublicBaseUrl"] = "https://api.petmagic.app",
                ["SupportChat:AttachmentStorage:PublicBaseUrl"] = "https://api.petmagic.app/support-media",
                ["Templates:PublicBaseUrl"] = "https://cdn.petmagic.app/templates",
                ["Templates:R2:PublicBaseUrl"] = "https://cdn.petmagic.app/r2"
            });

        HostApiProductionConfigurationValidator.ValidatePublicMediaBaseUrls(configuration, environment);
    }

    [Fact]
    public void ValidatePublicMediaBaseUrls_ShouldAllowLocalUrlsInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);
        var configuration = CreateConfiguration(
            defaultConnectionString: "",
            publicBaseUrls: new Dictionary<string, string?>
            {
                ["Identity:AvatarStorage:PublicBaseUrl"] = "http://localhost:5000",
                ["SupportChat:AttachmentStorage:PublicBaseUrl"] = "http://localhost:5000",
                ["Templates:PublicBaseUrl"] = "http://localhost:5000"
            });

        HostApiProductionConfigurationValidator.ValidatePublicMediaBaseUrls(configuration, environment);
    }

    [Theory]
    [InlineData("NEXT_PUBLIC_STRIPE_SECRET_KEY")]
    [InlineData("NEXT_PUBLIC_STRIPE_WEBHOOK_SECRET")]
    [InlineData("NEXT_PUBLIC_FAL_AI_API_KEY")]
    [InlineData("NEXT_PUBLIC_R2_ACCESS_KEY")]
    [InlineData("NEXT_PUBLIC_R2_SECRET_KEY")]
    [InlineData("NEXT_PUBLIC_GOOGLE_CLIENT_SECRET")]
    [InlineData("NEXT_PUBLIC_APPLE_CLIENT_SECRET")]
    [InlineData("NEXT_PUBLIC_JWT_SIGNING_KEY")]
    [InlineData("NEXT_PUBLIC_BOOTSTRAP_ADMIN_PASSWORD")]
    [InlineData("NEXT_PUBLIC_GOOGLE_PLAY_PRIVATE_KEY_PEM")]
    [InlineData("NEXT_PUBLIC_APP_STORE_SHARED_SECRET")]
    [InlineData("NEXT_PUBLIC_FIREBASE_SERVICE_ACCOUNT_JSON")]
    public void ValidateNoPublicServerSecrets_ShouldRejectPublicServerSecretKeysOutsideDevelopment(string key)
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                [key] = "configured"
            });

        var exception = Assert.Throws<InvalidOperationException>(() =>
            HostApiProductionConfigurationValidator.ValidateNoPublicServerSecrets(configuration, environment));

        Assert.Contains("Public client configuration", exception.Message);
        Assert.Contains(key, exception.Message);
    }

    [Fact]
    public void ValidateNoPublicServerSecrets_ShouldAllowPublicApiBaseUrlOutsideDevelopment()
    {
        var environment = CreateEnvironment(Environments.Production);
        var configuration = CreateConfiguration(
            defaultConnectionString: "Host=db.petmagic.internal;Database=petmagic;Username=petmagic_app;Password=strong-secret",
            additionalValues: new Dictionary<string, string?>
            {
                ["NEXT_PUBLIC_API_BASE_URL"] = "https://api.petmagic.app"
            });

        HostApiProductionConfigurationValidator.ValidateNoPublicServerSecrets(configuration, environment);
    }

    [Fact]
    public void ValidateNoPublicServerSecrets_ShouldAllowLocalPublicSecretsInDevelopment()
    {
        var environment = CreateEnvironment(Environments.Development);
        var configuration = CreateConfiguration(
            defaultConnectionString: "",
            additionalValues: new Dictionary<string, string?>
            {
                ["NEXT_PUBLIC_STRIPE_SECRET_KEY"] = "local-misconfiguration"
            });

        HostApiProductionConfigurationValidator.ValidateNoPublicServerSecrets(configuration, environment);
    }

    private static TestHostEnvironment CreateEnvironment(string environmentName)
    {
        return new TestHostEnvironment
        {
            EnvironmentName = environmentName
        };
    }

    private static IConfigurationRoot CreateConfiguration(
        string defaultConnectionString,
        string? jwtSigningKey = null,
        Dictionary<string, string?>? publicBaseUrls = null,
        Dictionary<string, string?>? additionalValues = null)
    {
        var values = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = defaultConnectionString,
            ["Jwt:SigningKey"] = jwtSigningKey
        };

        if (publicBaseUrls is not null)
        {
            foreach (var (key, value) in publicBaseUrls)
            {
                values[key] = value;
            }
        }

        if (additionalValues is not null)
        {
            foreach (var (key, value) in additionalValues)
            {
                values[key] = value;
            }
        }

        return new ConfigurationBuilder()
            .AddInMemoryCollection(values)
            .Build();
    }

    private sealed class TestHostEnvironment : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = Environments.Development;

        public string ApplicationName { get; set; } = "PetMagic.Tests";

        public string ContentRootPath { get; set; } = Directory.GetCurrentDirectory();

        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, "PetMagic.slnx")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate repository root.");
    }
}
