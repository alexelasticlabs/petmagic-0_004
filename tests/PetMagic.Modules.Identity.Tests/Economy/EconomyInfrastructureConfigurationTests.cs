using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
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
}
