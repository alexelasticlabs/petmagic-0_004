using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyInfrastructureConfigurationTests
{
    [Fact]
    public void AddEconomyInfrastructure_ShouldRejectMissingStripeSecrets_InProduction()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains("Stripe live secret key", exception.Message);
    }

    [Fact]
    public void AddEconomyInfrastructure_ShouldRejectStripeTestKeys_InProduction()
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings["Economy:StripeLiveSecretKey"] = StripeTestSecretKey;
        var configuration = CreateConfiguration(settings);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains("placeholder/test value", exception.Message);
    }

    [Fact]
    public void AddEconomyInfrastructure_ShouldAcceptProductionSecrets_WhenConfigured()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(CreateProductionSettings());

        services.AddEconomyInfrastructure(configuration, isProduction: true);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<IOptions<EconomyOptions>>().Value;

        Assert.Equal(StripeLiveSecretKey, options.StripeLiveSecretKey);
        Assert.Equal(StripeLivePublishableKey, options.StripeLivePublishableKey);
        Assert.Equal(StripeWebhookSecret, options.StripeLiveWebhookSecret);
    }

    [Theory]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "http://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://localhost/payments/success?session_id={CHECKOUT_SESSION_ID}")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://10.0.0.5/payments/success?session_id={CHECKOUT_SESSION_ID}")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://user:secret@petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}#secret")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}&token=secret")]
    [InlineData("Economy:StripeCheckoutSuccessUrl", "https://petmagic.app/payments/success")]
    [InlineData("Economy:StripeCheckoutCancelUrl", "http://petmagic.app/payments/cancel")]
    [InlineData("Economy:StripeCheckoutCancelUrl", "https://127.0.0.1/payments/cancel")]
    [InlineData("Economy:StripeCheckoutCancelUrl", "https://petmagic.app/payments/cancel?token=secret")]
    [InlineData("Economy:StripeBillingPortalReturnUrl", "http://petmagic.app/profile/premium")]
    [InlineData("Economy:StripeBillingPortalReturnUrl", "https://169.254.169.254/profile/premium")]
    [InlineData("Economy:StripeBillingPortalReturnUrl", "https://petmagic.app/profile/premium?token=secret")]
    public void AddEconomyInfrastructure_ShouldRejectUnsafeStripeRedirectUrls_InProduction(
        string setting,
        string redirectUrl)
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings[setting] = redirectUrl;
        var configuration = CreateConfiguration(settings);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains(setting, exception.Message);
    }

    [Theory]
    [InlineData("http://petmagic.app/google-play/webhook")]
    [InlineData("https://localhost/google-play/webhook")]
    [InlineData("https://10.0.0.5/google-play/webhook")]
    [InlineData("https://169.254.169.254/google-play/webhook")]
    [InlineData("https://user:secret@petmagic.app/google-play/webhook")]
    [InlineData("https://petmagic.app/google-play/webhook?token=secret")]
    [InlineData("https://petmagic.app/google-play/webhook#secret")]
    public void AddEconomyInfrastructure_ShouldRejectUnsafeGooglePlayPubSubAudience_InProduction(string audience)
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings["Economy:GooglePlayPubSubAudience"] = audience;
        var configuration = CreateConfiguration(settings);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains("Economy:GooglePlayPubSubAudience", exception.Message);
    }

    [Theory]
    [InlineData("not-an-email")]
    [InlineData("pubsub system.gserviceaccount.com")]
    [InlineData("https://system.gserviceaccount.com/pubsub")]
    public void AddEconomyInfrastructure_ShouldRejectInvalidGooglePlayPubSubExpectedEmail_InProduction(string expectedEmail)
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings["Economy:GooglePlayPubSubExpectedEmail"] = expectedEmail;
        var configuration = CreateConfiguration(settings);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains("Economy:GooglePlayPubSubExpectedEmail", exception.Message);
    }

    [Theory]
    [InlineData("petmagic/messages:send")]
    [InlineData("petmagic?alt=media")]
    [InlineData("petmagic#fragment")]
    [InlineData("petmagic app")]
    [InlineData("https://fcm.googleapis.com/v1/projects/petmagic")]
    [InlineData("user@petmagic")]
    public void AddEconomyInfrastructure_ShouldRejectUnsafeFirebaseProjectId_InProduction(string projectId)
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings["Economy:FirebasePushEnabled"] = "true";
        settings["Economy:FirebaseProjectId"] = projectId;
        settings["Economy:FirebaseServiceAccountJson"] = """{"type":"service_account"}""";
        var configuration = CreateConfiguration(settings);

        var exception = Assert.Throws<InvalidOperationException>(
            () => services.AddEconomyInfrastructure(configuration, isProduction: true));

        Assert.Contains("Economy:FirebaseProjectId", exception.Message);
    }

    [Fact]
    public void AddEconomyInfrastructure_ShouldAllowSafeFirebaseProjectId_InProduction()
    {
        var services = CreateServices();
        var settings = CreateProductionSettings();
        settings["Economy:FirebasePushEnabled"] = "true";
        settings["Economy:FirebaseProjectId"] = "petmagic-prod-123";
        settings["Economy:FirebaseServiceAccountJson"] = """{"type":"service_account"}""";
        var configuration = CreateConfiguration(settings);

        services.AddEconomyInfrastructure(configuration, isProduction: true);

        using var provider = services.BuildServiceProvider();
        var options = provider.GetRequiredService<IOptions<EconomyOptions>>().Value;

        Assert.Equal("petmagic-prod-123", options.FirebaseProjectId);
    }

    [Fact]
    public void AddEconomyInfrastructure_ShouldConfigureExternalHttpClientTimeouts()
    {
        var services = CreateServices();
        var configuration = CreateConfiguration([]);

        services.AddEconomyInfrastructure(configuration);

        using var provider = services.BuildServiceProvider();
        var httpClientFactory = provider.GetRequiredService<IHttpClientFactory>();

        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient(StripePaymentGateway.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient(StoreSubscriptionVerifier.HttpClientName).Timeout);
        Assert.Equal(TimeSpan.FromSeconds(30), httpClientFactory.CreateClient("EconomyFcm").Timeout);
    }

    [Fact]
    public void EconomyFcmHttpClient_ShouldNotFollowRedirects()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyInfrastructureServiceCollectionExtensions.cs"));

        Assert.Contains("services.AddHttpClient(FcmEconomyPushNotificationSender.HttpClientName, ConfigureExternalHttpClient)", source, StringComparison.Ordinal);
        Assert.Contains(".ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler", source, StringComparison.Ordinal);
        Assert.Contains("AllowAutoRedirect = false", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData(true, true)]
    [InlineData(false, false)]
    public void AddEconomyInfrastructure_ShouldGateOutboxWorkerOnlyByDispatcherSetting(
        bool dispatcherEnabled,
        bool expectedWorkerRegistration)
    {
        var services = CreateServices();
        var configuration = CreateConfiguration(new Dictionary<string, string?>
        {
            ["Economy:PushOutboxDispatcherEnabled"] = dispatcherEnabled.ToString(),
            ["Economy:FirebasePushEnabled"] = "false"
        });

        services.AddEconomyInfrastructure(configuration);

        var workerRegistered = services.Any(descriptor =>
            descriptor.ServiceType == typeof(IHostedService)
            && descriptor.ImplementationType == typeof(EconomyPushOutboxWorker));
        Assert.Equal(expectedWorkerRegistration, workerRegistered);
    }

    private static string StripeTestSecretKey => "sk_" + "test_should_not_start";

    private static string StripeLiveSecretKey => "sk_" + "live_petmagic_secret";

    private static string StripeLivePublishableKey => "pk_" + "live_petmagic_publishable";

    private static string StripeWebhookSecret => "whsec_" + "petmagic_webhook";

    private static Dictionary<string, string?> CreateProductionSettings()
    {
        return new Dictionary<string, string?>
        {
            ["Economy:StripeLiveSecretKey"] = StripeLiveSecretKey,
            ["Economy:StripeLivePublishableKey"] = StripeLivePublishableKey,
            ["Economy:StripeLiveWebhookSecret"] = StripeWebhookSecret,
            ["Economy:AppStoreSharedSecret"] = "app-store-shared-secret",
            ["Economy:AppStoreBundleId"] = "com.petmagic.app",
            ["Economy:GooglePlayPackageName"] = "com.petmagic.app",
            ["Economy:GooglePlayServiceAccountEmail"] = "billing@petmagic.iam.gserviceaccount.com",
            ["Economy:GooglePlayPrivateKeyPem"] = "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----",
            ["Economy:GooglePlayPubSubAudience"] = "https://petmagic.app/google-play/webhook",
            ["Economy:GooglePlayPubSubExpectedEmail"] = "pubsub@system.gserviceaccount.com"
        };
    }

    private static IConfiguration CreateConfiguration(IEnumerable<KeyValuePair<string, string?>> values)
    {
        var defaults = new Dictionary<string, string?>
        {
            ["ConnectionStrings:DefaultConnection"] = "Host=localhost;Database=petmagic_tests;Username=test;Password=test"
        };

        foreach (var value in values)
        {
            defaults[value.Key] = value.Value;
        }

        return new ConfigurationBuilder()
            .AddInMemoryCollection(defaults)
            .Build();
    }

    private static ServiceCollection CreateServices()
    {
        var services = new ServiceCollection();
        services.AddLogging();
        return services;
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Repository root was not found.");
    }
}
