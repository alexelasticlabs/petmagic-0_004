using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

using Npgsql;

using PetMagic.BuildingBlocks.Security;
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
        services.AddMemoryCache();
        services.AddHttpContextAccessor();

        var section = configuration.GetSection(EconomyOptions.SectionName);
        var economyOptions = new EconomyOptions
        {
            WeeklyFreeSpark = ParseInt(section["WeeklyFreeSpark"], 100),
            WeeklyPremiumSpark = ParseInt(section["WeeklyPremiumSpark"], 40),
            AdRewardSpark = ParseInt(section["AdRewardSpark"], 15),
            AdRewardDailyLimit = ParseInt(section["AdRewardDailyLimit"], 5),
            StripeTestSecretKey = ReadValue(
                section,
                "StripeTestSecretKey",
                "STRIPE_TEST_SECRET_KEY",
                "STRIPE_SECRET_KEY_TEST") ?? string.Empty,
            StripeTestPublishableKey = ReadValue(
                section,
                "StripeTestPublishableKey",
                "STRIPE_TEST_PUBLISHABLE_KEY",
                "STRIPE_PUBLISHABLE_KEY_TEST") ?? string.Empty,
            StripeLiveSecretKey = ReadValue(
                section,
                "StripeLiveSecretKey",
                "STRIPE_LIVE_SECRET_KEY",
                "STRIPE_SECRET_KEY_LIVE") ?? string.Empty,
            StripeLivePublishableKey = ReadValue(
                section,
                "StripeLivePublishableKey",
                "STRIPE_LIVE_PUBLISHABLE_KEY",
                "STRIPE_PUBLISHABLE_KEY_LIVE") ?? string.Empty,
            StripeTestWebhookSecret = ReadValue(
                section,
                "StripeTestWebhookSecret",
                "STRIPE_TEST_WEBHOOK_SECRET",
                "STRIPE_WEBHOOK_SECRET_TEST") ?? string.Empty,
            StripeLiveWebhookSecret = ReadValue(
                section,
                "StripeLiveWebhookSecret",
                "STRIPE_LIVE_WEBHOOK_SECRET",
                "STRIPE_WEBHOOK_SECRET_LIVE") ?? string.Empty,
            StripePremiumMonthlyPriceId = ReadValue(
                section,
                "StripePremiumMonthlyPriceId",
                "STRIPE_PREMIUM_MONTHLY_PRICE_ID") ?? string.Empty,
            StripePremiumYearlyPriceId = ReadValue(
                section,
                "StripePremiumYearlyPriceId",
                "STRIPE_PREMIUM_YEARLY_PRICE_ID") ?? string.Empty,
            StripeCheckoutSuccessUrl = ReadEnvironmentFirstValue(
                configuration,
                section,
                "StripeCheckoutSuccessUrl",
                "STRIPE_CHECKOUT_SUCCESS_URL") ?? "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = ReadEnvironmentFirstValue(
                configuration,
                section,
                "StripeCheckoutCancelUrl",
                "STRIPE_CHECKOUT_CANCEL_URL") ?? "https://petmagic.app/payments/cancel",
            StripeBillingPortalReturnUrl = ReadEnvironmentFirstValue(
                configuration,
                section,
                "StripeBillingPortalReturnUrl",
                "STRIPE_BILLING_PORTAL_RETURN_URL") ?? "https://petmagic.app/profile/premium",
            GooglePlayPackageName = ReadValue(section, "GooglePlayPackageName", "GOOGLE_PLAY_PACKAGE_NAME") ?? "com.petmagic.app",
            GooglePlayPremiumMonthlyProductId = ReadValue(
                section,
                "GooglePlayPremiumMonthlyProductId",
                "GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID") ?? "com.petmagic.app.premium.monthly",
            GooglePlayPremiumYearlyProductId = ReadValue(
                section,
                "GooglePlayPremiumYearlyProductId",
                "GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID") ?? "com.petmagic.app.premium.yearly",
            GooglePlayServiceAccountEmail = ReadValue(section, "GooglePlayServiceAccountEmail", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL") ?? string.Empty,
            GooglePlayPrivateKeyPem = NormalizePem(ReadValue(section, "GooglePlayPrivateKeyPem", "GOOGLE_PLAY_PRIVATE_KEY_PEM")),
            GooglePlayEnvironment = ReadValue(section, "GooglePlayEnvironment", "GOOGLE_PLAY_ENVIRONMENT") ?? "production",
            GooglePlayPubSubAudience = ReadValue(section, "GooglePlayPubSubAudience", "GOOGLE_PLAY_PUBSUB_AUDIENCE") ?? string.Empty,
            GooglePlayPubSubExpectedEmail = ReadValue(section, "GooglePlayPubSubExpectedEmail", "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL") ?? string.Empty,
            AppStoreBundleId = ReadValue(section, "AppStoreBundleId", "APP_STORE_BUNDLE_ID") ?? "com.petmagic.app",
            AppStorePremiumMonthlyProductId = ReadValue(
                section,
                "AppStorePremiumMonthlyProductId",
                "APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID") ?? "com.petmagic.app.premium.monthly",
            AppStorePremiumYearlyProductId = ReadValue(
                section,
                "AppStorePremiumYearlyProductId",
                "APP_STORE_PREMIUM_YEARLY_PRODUCT_ID") ?? "com.petmagic.app.premium.yearly",
            AppStoreSharedSecret = ReadValue(section, "AppStoreSharedSecret", "APP_STORE_SHARED_SECRET") ?? string.Empty,
            AppStoreEnvironment = ReadValue(section, "AppStoreEnvironment", "APP_STORE_ENVIRONMENT") ?? "production",
            MaxStoreReceiptAgeHours = ParseInt(section["MaxStoreReceiptAgeHours"], 24),
            StoreAccountBindingMode = ReadValue(
                section,
                "StoreAccountBindingMode",
                "STORE_ACCOUNT_BINDING_MODE") ?? "compatibility",
            EconomyReconciliationEnabled = ParseBool(
                ReadValue(section, "EconomyReconciliationEnabled", "ECONOMY_RECONCILIATION_ENABLED"),
                true),
            EconomyReconciliationIntervalMinutes = ParseInt(
                ReadValue(section, "EconomyReconciliationIntervalMinutes", "ECONOMY_RECONCILIATION_INTERVAL_MINUTES"),
                15),
            EconomyReconciliationPendingOrderMinutes = ParseInt(
                ReadValue(section, "EconomyReconciliationPendingOrderMinutes", "ECONOMY_RECONCILIATION_PENDING_ORDER_MINUTES"),
                30),
            EconomyReconciliationLookbackDays = ParseInt(
                ReadValue(section, "EconomyReconciliationLookbackDays", "ECONOMY_RECONCILIATION_LOOKBACK_DAYS"),
                30),
            EconomyReconciliationRetryDelayMinutes = ParseInt(
                ReadValue(section, "EconomyReconciliationRetryDelayMinutes", "ECONOMY_RECONCILIATION_RETRY_DELAY_MINUTES"),
                30),
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
                "FIREBASE_SERVICE_ACCOUNT_JSON_PATH") ?? string.Empty,
            PushOutboxDispatcherEnabled = ParseBool(
                ReadValue(section, "PushOutboxDispatcherEnabled", "ECONOMY_PUSH_OUTBOX_DISPATCHER_ENABLED"),
                true)
        };

        ValidateProductionConfiguration(economyOptions, isProduction);
        ValidateStoreAccountBindingMode(economyOptions.StoreAccountBindingMode);

        services.AddSingleton<IOptions<EconomyOptions>>(Microsoft.Extensions.Options.Options.Create(economyOptions));

        services.AddDbContextPool<EconomyDbContext>((serviceProvider, options) =>
        {
            var sharedDataSource = serviceProvider.GetService<NpgsqlDataSource>();
            if (sharedDataSource is null)
            {
                options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
            }
            else
            {
                options.UseNpgsql(sharedDataSource);
            }
        });

        services.AddScoped<EconomyAdminAuditOutbox>();
        services.AddScoped<EconomyAdminConfigurationService>();
        services.AddScoped<EconomyAdminRedeemCodeService>();
        services.AddScoped<IEconomyService, EconomyService>();
        services.AddScoped<IEconomyAdminService>(sp =>
            (IEconomyAdminService)sp.GetRequiredService<IEconomyService>());
        services.AddScoped<IUserEconomyResourceOwnershipReader, UserEconomyResourceOwnershipReader>();
        services.AddScoped<IAdminUserEconomyAnalyticsReader, AdminUserEconomyAnalyticsReader>();
        services.AddSingleton<IGoogleStoreWebhookTokenVerifier, GoogleStoreWebhookTokenVerifier>();
        services.AddSingleton<IStoreWebhookSecurityValidator, StoreWebhookSecurityValidator>();
        services.AddHttpClient(StripePaymentGateway.HttpClientName, ConfigureExternalHttpClient);
        services.AddHttpClient(StoreSubscriptionVerifier.HttpClientName, ConfigureExternalHttpClient);
        services.AddHttpClient(FcmEconomyPushNotificationSender.HttpClientName, ConfigureExternalHttpClient)
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false
            });
        services.AddSingleton<IPaymentGateway>(serviceProvider =>
            new StripePaymentGateway(
                economyOptions,
                serviceProvider.GetRequiredService<IHttpClientFactory>()));
        services.AddScoped<IEconomyPushTokenService, EconomyPushTokenService>();
        services.AddScoped<FcmEconomyPushNotificationSender>();
        services.AddScoped<IEconomyPushDeliverySender>(serviceProvider =>
            serviceProvider.GetRequiredService<FcmEconomyPushNotificationSender>());
        services.AddScoped<IEconomyPushNotificationSender, EconomyPushNotificationOutbox>();
        services.AddScoped<EconomyPushOutboxProcessor>();
        if (economyOptions.PushOutboxDispatcherEnabled)
        {
            services.AddHostedService<EconomyPushOutboxWorker>();
        }
        services.AddHostedService<EconomyReconciliationWorker>();
        services.AddSingleton<IStoreSubscriptionVerifier>(serviceProvider =>
            new StoreSubscriptionVerifier(
                serviceProvider.GetRequiredService<IHttpClientFactory>(),
                serviceProvider.GetRequiredService<IOptions<EconomyOptions>>(),
                serviceProvider.GetRequiredService<IStoreWebhookSecurityValidator>()));

        return services;
    }

    /// <summary>
    /// Registers only the durable wallet and subscription readers required by the
    /// generation worker. Payment, store verification, push delivery, and economy
    /// reconciliation capabilities are deliberately unavailable in this host so
    /// their production credentials never need to be mounted into the worker.
    /// </summary>
    public static IServiceCollection AddEconomyGenerationWorkerInfrastructure(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var section = configuration.GetSection(EconomyOptions.SectionName);
        var economyOptions = new EconomyOptions
        {
            WeeklyFreeSpark = ParseInt(section["WeeklyFreeSpark"], 100),
            WeeklyPremiumSpark = ParseInt(section["WeeklyPremiumSpark"], 40),
            AdRewardSpark = ParseInt(section["AdRewardSpark"], 15),
            AdRewardDailyLimit = ParseInt(section["AdRewardDailyLimit"], 5),
            ReferralBonusSpark = ParseInt(section["ReferralBonusSpark"], 15),
            EconomyReconciliationEnabled = false,
            FirebasePushEnabled = false,
            PushOutboxDispatcherEnabled = false
        };

        services.AddMemoryCache();
        services.AddSingleton<IOptions<EconomyOptions>>(
            Microsoft.Extensions.Options.Options.Create(economyOptions));
        services.AddDbContextPool<EconomyDbContext>((serviceProvider, options) =>
        {
            var sharedDataSource = serviceProvider.GetService<NpgsqlDataSource>();
            if (sharedDataSource is null)
            {
                options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
            }
            else
            {
                options.UseNpgsql(sharedDataSource);
            }
        });

        services.AddSingleton<IPaymentGateway, GenerationWorkerUnavailablePaymentGateway>();
        services.AddSingleton<IStoreSubscriptionVerifier, GenerationWorkerUnavailableStoreSubscriptionVerifier>();
        services.AddScoped<IEconomyService, EconomyService>();

        return services;
    }

    private static void ConfigureExternalHttpClient(HttpClient client) =>
        client.Timeout = ExternalHttpClientTimeout;

    private static void ValidateStoreAccountBindingMode(string? value)
    {
        if (string.Equals(value, "compatibility", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "enforce", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        throw new InvalidOperationException(
            "Economy:StoreAccountBindingMode must be either 'compatibility' or 'enforce'.");
    }

    private static int ParseInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var value) ? value : fallback;
    }

    private static bool ParseBool(string? raw, bool fallback)
    {
        return bool.TryParse(raw, out var value) ? value : fallback;
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

    private static string? ReadEnvironmentFirstValue(
        IConfiguration configuration,
        IConfigurationSection section,
        string key,
        params string[] environmentVariables)
    {
        foreach (var environmentVariable in environmentVariables)
        {
            var value = configuration[environmentVariable]
                ?? Environment.GetEnvironmentVariable(environmentVariable);
            if (!string.IsNullOrWhiteSpace(value))
            {
                return value;
            }
        }

        return section[key];
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

        var stripeSecretKey = options.StripeLiveSecretKey;
        var stripePublishableKey = options.StripeLivePublishableKey;
        var stripeWebhookSecret = options.StripeLiveWebhookSecret;

        RequireProductionSecret(stripeSecretKey, "Stripe live secret key", "STRIPE_LIVE_SECRET_KEY");
        RequireProductionSecret(stripePublishableKey, "Stripe live publishable key", "STRIPE_LIVE_PUBLISHABLE_KEY");
        RequireProductionSecret(stripeWebhookSecret, "Stripe live webhook secret", "STRIPE_LIVE_WEBHOOK_SECRET");

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

        ValidateProductionStripeRedirectUrl(
            options.StripeCheckoutSuccessUrl,
            "Economy:StripeCheckoutSuccessUrl",
            allowCheckoutSessionPlaceholder: true);
        ValidateProductionStripeRedirectUrl(
            options.StripeCheckoutCancelUrl,
            "Economy:StripeCheckoutCancelUrl",
            allowCheckoutSessionPlaceholder: false);
        ValidateProductionStripeRedirectUrl(
            options.StripeBillingPortalReturnUrl,
            "Economy:StripeBillingPortalReturnUrl",
            allowCheckoutSessionPlaceholder: false);

        RequireProductionSecret(options.AppStoreSharedSecret, "App Store shared secret", "APP_STORE_SHARED_SECRET");
        RequireProductionSecret(options.AppStoreBundleId, "App Store bundle id", "Economy:AppStoreBundleId");
        RequireProductionSecret(options.AppStorePremiumMonthlyProductId, "App Store monthly premium product id", "APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID");
        RequireProductionSecret(options.AppStorePremiumYearlyProductId, "App Store yearly premium product id", "APP_STORE_PREMIUM_YEARLY_PRODUCT_ID");

        RequireProductionSecret(options.GooglePlayPackageName, "Google Play package name", "Economy:GooglePlayPackageName");
        RequireProductionSecret(options.GooglePlayPremiumMonthlyProductId, "Google Play monthly premium product id", "GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID");
        RequireProductionSecret(options.GooglePlayPremiumYearlyProductId, "Google Play yearly premium product id", "GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID");
        RequireProductionSecret(options.GooglePlayServiceAccountEmail, "Google Play service account email", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL");
        RequireProductionSecret(options.GooglePlayPrivateKeyPem, "Google Play private key", "GOOGLE_PLAY_PRIVATE_KEY_PEM");
        RequireProductionSecret(options.GooglePlayPubSubAudience, "Google Play Pub/Sub audience", "GOOGLE_PLAY_PUBSUB_AUDIENCE");
        RequireProductionSecret(options.GooglePlayPubSubExpectedEmail, "Google Play Pub/Sub expected email", "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL");
        ValidateProductionPublicHttpsUrl(options.GooglePlayPubSubAudience, "Economy:GooglePlayPubSubAudience");
        ValidateProductionEmailAddress(options.GooglePlayPubSubExpectedEmail, "Economy:GooglePlayPubSubExpectedEmail");

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
            ValidateProductionFirebaseProjectId(options.FirebaseProjectId, "Economy:FirebaseProjectId");
        }
    }

    private static void ValidateProductionStripeRedirectUrl(
        string? redirectUrl,
        string settingName,
        bool allowCheckoutSessionPlaceholder)
    {
        if (string.IsNullOrWhiteSpace(redirectUrl))
        {
            throw new InvalidOperationException($"{settingName} must be configured in Production.");
        }

        if (!Uri.TryCreate(redirectUrl, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"{settingName} must be an absolute HTTPS URL in Production.");
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"{settingName} must use HTTPS in Production.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Fragment))
        {
            throw new InvalidOperationException($"{settingName} must not contain credentials or fragments in Production.");
        }

        if (!allowCheckoutSessionPlaceholder && !string.IsNullOrEmpty(uri.Query))
        {
            throw new InvalidOperationException($"{settingName} must not contain query strings in Production.");
        }

        var decodedQuery = Uri.UnescapeDataString(uri.Query);
        if (allowCheckoutSessionPlaceholder
            && !string.Equals(decodedQuery, "?session_id={CHECKOUT_SESSION_ID}", StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"{settingName} must contain only session_id={{CHECKOUT_SESSION_ID}} as the query string in Production.");
        }

        if (SafeNetworkTargetPolicy.IsPrivateNetworkTarget(uri))
        {
            throw new InvalidOperationException($"{settingName} must not point to a local or private network host in Production.");
        }
    }

    private static void ValidateProductionPublicHttpsUrl(string value, string settingName)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"{settingName} must be an absolute HTTPS URL in Production.");
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"{settingName} must use HTTPS in Production.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo)
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment))
        {
            throw new InvalidOperationException($"{settingName} must not contain credentials, query strings, or fragments in Production.");
        }

        if (SafeNetworkTargetPolicy.IsPrivateNetworkTarget(uri))
        {
            throw new InvalidOperationException($"{settingName} must not point to a local or private network host in Production.");
        }
    }

    private static void ValidateProductionEmailAddress(string value, string settingName)
    {
        try
        {
            var parsed = new System.Net.Mail.MailAddress(value);
            if (!string.Equals(parsed.Address, value.Trim(), StringComparison.OrdinalIgnoreCase))
            {
                throw new FormatException();
            }
        }
        catch (FormatException)
        {
            throw new InvalidOperationException($"{settingName} must be a valid email address in Production.");
        }
    }

    private static void ValidateProductionFirebaseProjectId(string value, string settingName)
    {
        if (!FirebaseProjectIdPolicy.IsSafeProjectId(value))
        {
            throw new InvalidOperationException($"{settingName} must be a Firebase project id, not a URL or path, in Production.");
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
        var economyOptions = scope.ServiceProvider.GetRequiredService<IOptions<EconomyOptions>>().Value;
        await dbContext.Database.MigrateAsync();

        await SeedSubscriptionPlansAsync(dbContext, economyOptions);
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
                PriceAmount = 0.99m,
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
                PriceAmount = 1.49m,
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
                PriceAmount = 1.99m,
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
                PriceAmount = 0.99m,
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
                PriceAmount = 1.49m,
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
                PriceAmount = 1.99m,
                GrantedSpark = 100,
                BonusSpark = 0,
                IsActive = true,
                SortOrder = 3
            });

        await dbContext.SaveChangesAsync();
        }
    }

    private static async Task SeedSubscriptionPlansAsync(
        EconomyDbContext dbContext,
        EconomyOptions options)
    {
        var now = DateTime.UtcNow;
        var plans = new[]
        {
            new SubscriptionPlan
            {
                Id = "monthly",
                Name = "PetMagic Premium Monthly",
                BillingPeriod = "monthly",
                PriceAmount = 0.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 40,
                IsRecommended = false,
                IsActive = true,
                AppleProductId = options.AppStorePremiumMonthlyProductId,
                GoogleProductId = options.GooglePlayPremiumMonthlyProductId,
                StripePriceId = options.StripePremiumMonthlyPriceId,
                DisplayOrder = 1,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new SubscriptionPlan
            {
                Id = "yearly",
                Name = "PetMagic Premium Yearly",
                BillingPeriod = "yearly",
                PriceAmount = 1.99m,
                CurrencyCode = "USD",
                MonthlyTokenLimit = 40,
                IsRecommended = false,
                IsActive = true,
                AppleProductId = options.AppStorePremiumYearlyProductId,
                GoogleProductId = options.GooglePlayPremiumYearlyProductId,
                StripePriceId = options.StripePremiumYearlyPriceId,
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
            if (string.IsNullOrWhiteSpace(existing.AppleProductId))
            {
                existing.AppleProductId = plan.AppleProductId;
            }

            if (string.IsNullOrWhiteSpace(existing.GoogleProductId))
            {
                existing.GoogleProductId = plan.GoogleProductId;
            }

            if (!string.IsNullOrWhiteSpace(plan.StripePriceId))
            {
                existing.StripePriceId = plan.StripePriceId;
            }
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
                WarningMessage = "Stripe billing opens in secure Stripe-hosted Checkout. PetMagic updates access after Stripe confirms payment.",
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
                IsEnabled = false,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = false,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "0.0.0",
                ExternalCheckoutAllowed = false,
                BonusTokensPercent = 0,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Unavailable until Apple external-purchase requirements are implemented.",
                Mode = defaultMode,
                Notes = "Disabled until Apple external-purchase entitlement and transaction-reporting flow are implemented.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            },
            new PaymentProviderConfiguration
            {
                Id = Guid.NewGuid(),
                Provider = "stripe",
                Platform = "ios",
                Region = "EU",
                IsEnabled = false,
                IsRecommended = false,
                IsSelectedByDefault = false,
                RequiresExternalWarning = false,
                RequiresStoreDisclosure = true,
                AllowedFromAppVersion = "1.0.0",
                ExternalCheckoutAllowed = false,
                BonusTokensPercent = 0,
                DisplayLabel = "Stripe",
                DisplaySubtitle = "Unavailable until Apple external-purchase requirements are implemented.",
                Mode = defaultMode,
                Notes = "Disabled until Apple external-purchase entitlement and transaction-reporting flow are implemented.",
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
                WarningMessage = "Stripe billing opens in secure Stripe-hosted Checkout. Provider terms and support may differ from App Store or Google Play.",
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
                WarningMessage = "Stripe billing opens in secure Stripe-hosted Checkout. PetMagic updates access after Stripe confirms payment.",
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
                NormalizeSeededStripeCheckoutCopy(existing, config, now);
                continue;
            }

            dbContext.PaymentProviderConfigurations.Add(config);
        }

        await dbContext.SaveChangesAsync();
    }

    private static void NormalizeSeededStripeCheckoutCopy(
        PaymentProviderConfiguration existing,
        PaymentProviderConfiguration seeded,
        DateTime now)
    {
        if (!string.Equals(existing.Provider, "stripe", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        if (!ContainsNativePaymentSheetCopy(existing.WarningMessage)
            && !ContainsNativePaymentSheetCopy(existing.DisplaySubtitle)
            && !ContainsNativePaymentSheetCopy(existing.Notes))
        {
            return;
        }

        existing.DisplaySubtitle = seeded.DisplaySubtitle;
        existing.WarningTitle = seeded.WarningTitle;
        existing.WarningMessage = seeded.WarningMessage;
        existing.Notes = seeded.Notes;
        existing.UpdatedAtUtc = now;
    }

    private static bool ContainsNativePaymentSheetCopy(string? value)
    {
        return (value ?? string.Empty).Contains("native payment sheet", StringComparison.OrdinalIgnoreCase)
            || (value ?? string.Empty).Contains("native payment sheets", StringComparison.OrdinalIgnoreCase);
    }
}
