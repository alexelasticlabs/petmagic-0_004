using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

public static class EconomyInfrastructureServiceCollectionExtensions
{
    private static readonly TimeSpan ExternalHttpClientTimeout = TimeSpan.FromSeconds(30);

    public static IServiceCollection AddEconomyInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration,
        bool isProduction = false)
    {
        var section = configuration.GetSection(EconomyOptions.SectionName);
        var legacyStripeSecretKey = ReadValue(section, "StripeSecretKey", "STRIPE_SECRET_KEY") ?? string.Empty;
        var legacyStripePublishableKey = ReadValue(section, "StripePublishableKey", "STRIPE_PUBLISHABLE_KEY") ?? string.Empty;
        var legacyStripeWebhookSecret = ReadValue(section, "StripeWebhookSecret", "STRIPE_WEBHOOK_SECRET") ?? string.Empty;

        var economyOptions = new EconomyOptions
        {
            WeeklyFreeSpark = ParseInt(section["WeeklyFreeSpark"], 100),
            WeeklyPremiumSpark = ParseInt(section["WeeklyPremiumSpark"], 40),
            AdRewardSpark = ParseInt(section["AdRewardSpark"], 15),
            AdRewardDailyLimit = ParseInt(section["AdRewardDailyLimit"], 5),
            StripeSecretKey = legacyStripeSecretKey,
            StripePublishableKey = legacyStripePublishableKey,
            StripeTestSecretKey = ReadValue(
                section,
                "StripeTestSecretKey",
                "STRIPE_TEST_SECRET_KEY",
                "STRIPE_SECRET_KEY_TEST") ?? legacyStripeSecretKey,
            StripeTestPublishableKey = ReadValue(
                section,
                "StripeTestPublishableKey",
                "STRIPE_TEST_PUBLISHABLE_KEY",
                "STRIPE_PUBLISHABLE_KEY_TEST") ?? legacyStripePublishableKey,
            StripeLiveSecretKey = ReadValue(
                section,
                "StripeLiveSecretKey",
                "STRIPE_LIVE_SECRET_KEY",
                "STRIPE_SECRET_KEY_LIVE") ?? legacyStripeSecretKey,
            StripeLivePublishableKey = ReadValue(
                section,
                "StripeLivePublishableKey",
                "STRIPE_LIVE_PUBLISHABLE_KEY",
                "STRIPE_PUBLISHABLE_KEY_LIVE") ?? legacyStripePublishableKey,
            StripeWebhookSecret = legacyStripeWebhookSecret,
            StripeTestWebhookSecret = ReadValue(
                section,
                "StripeTestWebhookSecret",
                "STRIPE_TEST_WEBHOOK_SECRET",
                "STRIPE_WEBHOOK_SECRET_TEST") ?? legacyStripeWebhookSecret,
            StripeLiveWebhookSecret = ReadValue(
                section,
                "StripeLiveWebhookSecret",
                "STRIPE_LIVE_WEBHOOK_SECRET",
                "STRIPE_WEBHOOK_SECRET_LIVE") ?? legacyStripeWebhookSecret,
            StripeCheckoutSuccessUrl = ReadValue(
                section,
                "StripeCheckoutSuccessUrl",
                "STRIPE_CHECKOUT_SUCCESS_URL") ?? "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = ReadValue(
                section,
                "StripeCheckoutCancelUrl",
                "STRIPE_CHECKOUT_CANCEL_URL") ?? "https://petmagic.app/payments/cancel",
            StripeBillingPortalReturnUrl = ReadValue(
                section,
                "StripeBillingPortalReturnUrl",
                "STRIPE_BILLING_PORTAL_RETURN_URL") ?? "https://petmagic.app/profile/premium",
            GooglePlayPackageName = section["GooglePlayPackageName"] ?? "com.petmagic.app",
            GooglePlayServiceAccountEmail = ReadValue(section, "GooglePlayServiceAccountEmail", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL") ?? string.Empty,
            GooglePlayPrivateKeyPem = NormalizePem(ReadValue(section, "GooglePlayPrivateKeyPem", "GOOGLE_PLAY_PRIVATE_KEY_PEM")),
            GooglePlayEnvironment = ReadValue(section, "GooglePlayEnvironment", "GOOGLE_PLAY_ENVIRONMENT") ?? "production",
            GooglePlayPubSubAudience = ReadValue(section, "GooglePlayPubSubAudience", "GOOGLE_PLAY_PUBSUB_AUDIENCE") ?? string.Empty,
            GooglePlayPubSubExpectedEmail = ReadValue(section, "GooglePlayPubSubExpectedEmail", "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL") ?? string.Empty,
            AppStoreBundleId = section["AppStoreBundleId"] ?? "com.petmagic.app",
            AppStoreSharedSecret = ReadValue(section, "AppStoreSharedSecret", "APP_STORE_SHARED_SECRET") ?? string.Empty,
            AppStoreEnvironment = ReadValue(section, "AppStoreEnvironment", "APP_STORE_ENVIRONMENT") ?? "production",
            FirebasePushEnabled =
                bool.TryParse(
                    ReadValue(
                        section,
                        "FirebasePushEnabled",
                        "ECONOMY_FIREBASE_PUSH_ENABLED",
                        "FIREBASE_PUSH_ENABLED"),
                    out var firebasePushEnabled)
                && firebasePushEnabled,
            FirebaseProjectId = ReadValue(
                section,
                "FirebaseProjectId",
                "ECONOMY_FIREBASE_PROJECT_ID",
                "FIREBASE_PROJECT_ID") ?? string.Empty,
            FirebaseServiceAccountJson = ReadValue(
                section,
                "FirebaseServiceAccountJson",
                "ECONOMY_FIREBASE_SERVICE_ACCOUNT_JSON",
                "FIREBASE_SERVICE_ACCOUNT_JSON") ?? string.Empty,
            FirebaseServiceAccountJsonPath = ReadValue(
                section,
                "FirebaseServiceAccountJsonPath",
                "ECONOMY_FIREBASE_SERVICE_ACCOUNT_JSON_PATH",
                "FIREBASE_SERVICE_ACCOUNT_JSON_PATH") ?? string.Empty
        };

        ValidateProductionConfiguration(economyOptions, isProduction);

        services.AddSingleton<IOptions<EconomyOptions>>(Microsoft.Extensions.Options.Options.Create(economyOptions));

        services.AddDbContextPool<EconomyDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddScoped<EconomyAdminConfigurationService>();
        services.AddScoped<EconomyAdminRedeemCodeService>();
        services.AddScoped<IEconomyService, EconomyService>();
        services.AddScoped<IEconomyAdminService>(sp =>
            (IEconomyAdminService)sp.GetRequiredService<IEconomyService>());
        services.AddScoped<IAdminUserEconomyAnalyticsReader, AdminUserEconomyAnalyticsReader>();
        services.AddSingleton<IGoogleStoreWebhookTokenVerifier, GoogleStoreWebhookTokenVerifier>();
        services.AddSingleton<IStoreWebhookSecurityValidator, StoreWebhookSecurityValidator>();
        services.AddHttpClient(StripePaymentGateway.HttpClientName, ConfigureExternalHttpClient);
        services.AddHttpClient(StoreSubscriptionVerifier.HttpClientName, ConfigureExternalHttpClient);
        services.AddHttpClient(FcmEconomyPushNotificationSender.HttpClientName, ConfigureExternalHttpClient);
        services.AddSingleton<IPaymentGateway>(serviceProvider =>
            new StripePaymentGateway(
                economyOptions,
                serviceProvider.GetRequiredService<IHttpClientFactory>()));
        services.AddScoped<IEconomyPushTokenService, EconomyPushTokenService>();
        services.AddScoped<NoopEconomyPushNotificationSender>();
        services.AddScoped<FcmEconomyPushNotificationSender>();
        services.AddScoped<IEconomyPushNotificationSender>(serviceProvider =>
            economyOptions.IsFirebasePushConfigured
                ? serviceProvider.GetRequiredService<FcmEconomyPushNotificationSender>()
                : serviceProvider.GetRequiredService<NoopEconomyPushNotificationSender>());
        services.AddSingleton<IStoreSubscriptionVerifier>(serviceProvider =>
            new StoreSubscriptionVerifier(
                serviceProvider.GetRequiredService<IHttpClientFactory>(),
                serviceProvider.GetRequiredService<IOptions<EconomyOptions>>(),
                serviceProvider.GetRequiredService<IStoreWebhookSecurityValidator>()));

        return services;
    }

    private static void ConfigureExternalHttpClient(HttpClient client) =>
        client.Timeout = ExternalHttpClientTimeout;

    private static int ParseInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var value) ? value : fallback;
    }

    private static string? ReadValue(IConfigurationSection section, string key, params string[] environmentVariables)
    {
        var value = section[key];
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        foreach (var environmentVariable in environmentVariables)
        {
            value = Environment.GetEnvironmentVariable(environmentVariable);
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return null;
    }

    private static string NormalizePem(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        return raw.Replace("\\n", "\n", StringComparison.Ordinal);
    }

    private static void ValidateProductionConfiguration(EconomyOptions options, bool isProduction)
    {
        if (!isProduction)
        {
            return;
        }

        var stripeSecretKey = FirstNonEmpty(options.StripeLiveSecretKey, options.StripeSecretKey);
        var stripePublishableKey = FirstNonEmpty(options.StripeLivePublishableKey, options.StripePublishableKey);
        var stripeWebhookSecret = FirstNonEmpty(options.StripeLiveWebhookSecret, options.StripeWebhookSecret);

        RequireProductionSecret(stripeSecretKey, "Stripe live secret key", "STRIPE_LIVE_SECRET_KEY or STRIPE_SECRET_KEY");
        RequireProductionSecret(stripePublishableKey, "Stripe live publishable key", "STRIPE_LIVE_PUBLISHABLE_KEY or STRIPE_PUBLISHABLE_KEY");
        RequireProductionSecret(stripeWebhookSecret, "Stripe live webhook secret", "STRIPE_LIVE_WEBHOOK_SECRET or STRIPE_WEBHOOK_SECRET");

        if (!HasAnyPrefix(stripeSecretKey!, "sk_live_", "rk_live_"))
        {
            throw new InvalidOperationException("Stripe live secret key must use a live Stripe key prefix in Production.");
        }

        if (!stripePublishableKey!.StartsWith("pk_live_", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Stripe live publishable key must use a live Stripe key prefix in Production.");
        }

        if (!stripeWebhookSecret!.StartsWith("whsec_", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Stripe webhook secret must use the whsec_ prefix in Production.");
        }

        RequireProductionSecret(options.AppStoreSharedSecret, "App Store shared secret", "APP_STORE_SHARED_SECRET");
        RequireProductionSecret(options.AppStoreBundleId, "App Store bundle id", "Economy:AppStoreBundleId");

        RequireProductionSecret(options.GooglePlayPackageName, "Google Play package name", "Economy:GooglePlayPackageName");
        RequireProductionSecret(options.GooglePlayServiceAccountEmail, "Google Play service account email", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL");
        RequireProductionSecret(options.GooglePlayPrivateKeyPem, "Google Play private key", "GOOGLE_PLAY_PRIVATE_KEY_PEM");
        RequireProductionSecret(options.GooglePlayPubSubAudience, "Google Play Pub/Sub audience", "GOOGLE_PLAY_PUBSUB_AUDIENCE");
        RequireProductionSecret(options.GooglePlayPubSubExpectedEmail, "Google Play Pub/Sub expected email", "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL");

        if (!options.GooglePlayPrivateKeyPem.Contains("BEGIN PRIVATE KEY", StringComparison.Ordinal))
        {
            throw new InvalidOperationException("Google Play private key must be a PEM private key in Production.");
        }

        if (options.FirebasePushEnabled && !options.IsFirebasePushConfigured)
        {
            throw new InvalidOperationException("Economy Firebase push is enabled but Firebase project id or service account configuration is missing.");
        }

        if (options.FirebasePushEnabled)
        {
            RequireProductionSecret(options.FirebaseProjectId, "Firebase project id", "ECONOMY_FIREBASE_PROJECT_ID or FIREBASE_PROJECT_ID");
        }
    }

    private static void RequireProductionSecret(string? value, string settingName, string configurationHint)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            throw new InvalidOperationException($"{settingName} must be configured in Production. Set {configurationHint}.");
        }

        if (LooksLikePlaceholder(value))
        {
            throw new InvalidOperationException($"{settingName} contains a placeholder/test value and must be replaced in Production.");
        }
    }

    private static bool LooksLikePlaceholder(string value)
    {
        return value.Contains("CHANGE_ME", StringComparison.OrdinalIgnoreCase)
            || value.Contains("DEV_ONLY", StringComparison.OrdinalIgnoreCase)
            || value.Contains("PetMagicDemo", StringComparison.OrdinalIgnoreCase)
            || value.Contains("PetMagic_Dev", StringComparison.OrdinalIgnoreCase)
            || value.Contains("test_stripe", StringComparison.OrdinalIgnoreCase)
            || value.Contains("test_webhook", StringComparison.OrdinalIgnoreCase)
            || value.StartsWith("sk_test_", StringComparison.Ordinal)
            || value.StartsWith("pk_test_", StringComparison.Ordinal);
    }

    private static bool HasAnyPrefix(string value, params string[] prefixes)
    {
        return prefixes.Any(prefix => value.StartsWith(prefix, StringComparison.Ordinal));
    }

    private static string? FirstNonEmpty(params string?[] values)
    {
        return values.FirstOrDefault(value => !string.IsNullOrWhiteSpace(value));
    }

    private static bool IsProductionEnvironment()
    {
        var environmentName = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
            ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
        return string.Equals(environmentName, "Production", StringComparison.OrdinalIgnoreCase);
    }

    public static async Task EnsureEconomySeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<EconomyDbContext>();
        await dbContext.Database.MigrateAsync();

        await SeedSubscriptionPlansAsync(dbContext);
        await SeedPaymentProviderConfigurationsAsync(
            dbContext,
            IsProductionEnvironment() ? "live" : "test");

        if (!await dbContext.CurrencyPacks.AnyAsync())
        {
            dbContext.CurrencyPacks.AddRange(
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "starter",
                DisplayName = "Tiny Treat",
                CurrencyCode = "USD",
                PriceAmount = 6.99m,
                GrantedSpark = 20,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 1
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "creator",
                DisplayName = "Happy Pack",
                CurrencyCode = "USD",
                PriceAmount = 14.99m,
                GrantedSpark = 45,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 2
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "viral",
                DisplayName = "Magic Boost",
                CurrencyCode = "USD",
                PriceAmount = 29.99m,
                GrantedSpark = 100,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 3
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "starter",
                DisplayName = "Tiny Treat",
                CurrencyCode = "EUR",
                PriceAmount = 6.29m,
                GrantedSpark = 20,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 1
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "creator",
                DisplayName = "Happy Pack",
                CurrencyCode = "EUR",
                PriceAmount = 13.49m,
                GrantedSpark = 45,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 2
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "viral",
                DisplayName = "Magic Boost",
                CurrencyCode = "EUR",
                PriceAmount = 26.99m,
                GrantedSpark = 100,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 3
            });

        await dbContext.SaveChangesAsync();
        }
    }

    private static async Task SeedSubscriptionPlansAsync(EconomyDbContext dbContext)
    {
        var now = DateTime.UtcNow;
        var plans = new[]
        {
            new SubscriptionPlan
            {
                Id = "monthly",
                Name = "PetMagic Premium Monthly",
                BillingPeriod = "monthly",
                PriceAmount = 14.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 500,
                IsRecommended = false,
                IsActive = true,
                AppleProductId = "com.petmagic.app.premium.monthly",
                GoogleProductId = "com.petmagic.app.premium.monthly",
                DisplayOrder = 1,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new SubscriptionPlan
            {
                Id = "yearly",
                Name = "PetMagic Premium Yearly",
                BillingPeriod = "yearly",
                PriceAmount = 99.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 1000,
                IsRecommended = true,
                IsActive = true,
                AppleProductId = "com.petmagic.app.premium.yearly",
                GoogleProductId = "com.petmagic.app.premium.yearly",
                DisplayOrder = 2,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            }
        };

        foreach (var plan in plans)
        {
            var existing = await dbContext.SubscriptionPlans.FirstOrDefaultAsync(x => x.Id == plan.Id);
            if (existing is null)
            {
                dbContext.SubscriptionPlans.Add(plan);
                continue;
            }

            existing.Name = plan.Name;
            existing.BillingPeriod = plan.BillingPeriod;
            existing.PriceAmount = plan.PriceAmount;
            existing.CurrencyCode = plan.CurrencyCode;
            existing.MonthlyTokenLimit = plan.MonthlyTokenLimit;
            existing.IsRecommended = plan.IsRecommended;
            existing.IsActive = plan.IsActive;
            existing.AppleProductId = plan.AppleProductId;
            existing.GoogleProductId = plan.GoogleProductId;
            existing.DisplayOrder = plan.DisplayOrder;
            existing.UpdatedAtUtc = now;
        }

        await dbContext.SaveChangesAsync();
    }

    private static async Task SeedPaymentProviderConfigurationsAsync(EconomyDbContext dbContext, string defaultMode)
    {
        var now = DateTime.UtcNow;
        var configs = new[]
        {
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "app_store",
                Platform = "ios",
                Region = "*",
                IsEnabled = true,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = false,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = false,
                BonusTokensPercent = 0,
                DisplayLabel = "App Store",
                DisplaySubtitle = "Store-native checkout for iPhone and iPad.",
                Mode = defaultMode,
                Notes = "Default App Store in-app subscription flow.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "google_play",
                Platform = "android",
                Region = "*",
                IsEnabled = true,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = false,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = false,
                BonusTokensPercent = 0,
                DisplayLabel = "Google Play",
                DisplaySubtitle = "Store-native checkout for Android devices.",
                Mode = defaultMode,
                Notes = "Default Google Play Billing flow.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "web",
                Region = "*",
                IsEnabled = true,
                IsRecommended = true,
                IsSelectedByDefault = true,
                RequiresExternalWarning = false,
                RequiresStoreDisclosure = false,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = true,
                BonusTokensPercent = 0,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Recommended · secure card checkout",
                WarningTitle = "Payment via Stripe",
                WarningMessage = "Stripe billing is completed inside PetMagic with native payment sheet.",
                Mode = defaultMode,
                Notes = "Primary Stripe billing provider.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "ios",
                Region = "*",
                IsEnabled = true,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = true,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = true,
                BonusTokensPercent = 0,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Pay securely via Stripe",
                WarningTitle = "Payment via Stripe",
                WarningMessage = "Stripe billing is completed inside PetMagic with native payment sheet.",
                Mode = defaultMode,
                Notes = "Global Stripe billing route for iOS.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "ios",
                Region = "EU",
                IsEnabled = true,
                IsRecommended = true,
                IsSelectedByDefault = true,
                RequiresExternalWarning = true,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "1.0.0",
                ExternalCheckoutAllowed = true,
                BonusTokensPercent = 10,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Recommended · secure card payment",
                WarningTitle = "Payment via Stripe",
                WarningMessage = "Stripe billing is completed inside PetMagic with native payment sheet. Provider terms and support may differ from App Store or Google Play.",
                Mode = defaultMode,
                Notes = "EU Stripe alternative billing route for iOS.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "android",
                Region = "EU",
                IsEnabled = true,
                IsRecommended = true,
                IsSelectedByDefault = true,
                RequiresExternalWarning = true,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "1.0.0",
                ExternalCheckoutAllowed = true,
                BonusTokensPercent = 10,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Recommended · secure card payment",
                WarningTitle = "Payment via Stripe",
                WarningMessage = "Stripe billing is completed inside PetMagic with native payment sheet. Provider terms and support may differ from App Store or Google Play.",
                Mode = defaultMode,
                Notes = "EU Stripe alternative billing route for Android.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "android",
                Region = "*",
                IsEnabled = true,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = true,
                RequiresStoreDisclosure = false,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = true,
                BonusTokensPercent = 0,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Pay securely via Stripe",
                WarningTitle = "Payment via Stripe",
                WarningMessage = "Stripe billing is completed inside PetMagic with native payment sheet.",
                Mode = defaultMode,
                Notes = "Global Stripe billing route for Android.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            }
        };

        foreach (var config in configs)
        {
            var existing = await dbContext.PaymentProviderConfigurations.FirstOrDefaultAsync(
                x => x.Provider == config.Provider && x.Platform == config.Platform && x.Region == config.Region);

            if (existing is not null)
            {
                continue;
            }

            dbContext.PaymentProviderConfigurations.Add(config);
        }

        await dbContext.SaveChangesAsync();
    }
}
