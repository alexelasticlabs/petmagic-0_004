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
    public static IServiceCollection AddEconomyInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        var section = configuration.GetSection(EconomyOptions.SectionName);
        var economyOptions = new EconomyOptions
        {
            WeeklyFreeSpark = ParseInt(section["WeeklyFreeSpark"], 100),
            WeeklyPremiumSpark = ParseInt(section["WeeklyPremiumSpark"], 250),
            AdRewardSpark = ParseInt(section["AdRewardSpark"], 15),
            AdRewardDailyLimit = ParseInt(section["AdRewardDailyLimit"], 5),
            StripeSecretKey = ReadValue(section, "StripeSecretKey", "STRIPE_SECRET_KEY") ?? string.Empty,
            StripeWebhookSecret = ReadValue(section, "StripeWebhookSecret", "STRIPE_WEBHOOK_SECRET") ?? string.Empty,
            StripeCheckoutSuccessUrl = section["StripeCheckoutSuccessUrl"] ?? "https://petmagic.app/payments/success?session_id={CHECKOUT_SESSION_ID}",
            StripeCheckoutCancelUrl = section["StripeCheckoutCancelUrl"] ?? "https://petmagic.app/payments/cancel",
            StripeBillingPortalReturnUrl = section["StripeBillingPortalReturnUrl"] ?? "https://petmagic.app/profile/premium",
            GooglePlayPackageName = section["GooglePlayPackageName"] ?? "com.petmagic.app",
            GooglePlayServiceAccountEmail = ReadValue(section, "GooglePlayServiceAccountEmail", "GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL") ?? string.Empty,
            GooglePlayPrivateKeyPem = NormalizePem(ReadValue(section, "GooglePlayPrivateKeyPem", "GOOGLE_PLAY_PRIVATE_KEY_PEM")),
            GooglePlayPubSubAudience = ReadValue(section, "GooglePlayPubSubAudience", "GOOGLE_PLAY_PUBSUB_AUDIENCE") ?? string.Empty,
            GooglePlayPubSubExpectedEmail = ReadValue(section, "GooglePlayPubSubExpectedEmail", "GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL") ?? string.Empty,
            AppStoreBundleId = section["AppStoreBundleId"] ?? "com.petmagic.app",
            AppStoreSharedSecret = ReadValue(section, "AppStoreSharedSecret", "APP_STORE_SHARED_SECRET") ?? string.Empty
        };

        services.AddSingleton<IOptions<EconomyOptions>>(Microsoft.Extensions.Options.Options.Create(economyOptions));

        services.AddDbContext<EconomyDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddScoped<IEconomyService, EconomyService>();
        services.AddScoped<IAdminUserEconomyAnalyticsReader, AdminUserEconomyAnalyticsReader>();
        services.AddSingleton<IGoogleStoreWebhookTokenVerifier, GoogleStoreWebhookTokenVerifier>();
        services.AddSingleton<IStoreWebhookSecurityValidator, StoreWebhookSecurityValidator>();
        services.AddSingleton<IPaymentGateway>(_ => new StripePaymentGateway(economyOptions));
        services.AddSingleton<IStoreSubscriptionVerifier>(serviceProvider =>
            new StoreSubscriptionVerifier(
                new HttpClient(),
                serviceProvider.GetRequiredService<IOptions<EconomyOptions>>()));

        return services;
    }

    private static int ParseInt(string? raw, int fallback)
    {
        return int.TryParse(raw, out var value) ? value : fallback;
    }

    private static string? ReadValue(IConfigurationSection section, string key, string environmentVariable)
    {
        var value = section[key];
        if (!string.IsNullOrWhiteSpace(value))
        {
            return value;
        }

        value = Environment.GetEnvironmentVariable(environmentVariable);
        return string.IsNullOrWhiteSpace(value) ? null : value;
    }

    private static string NormalizePem(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return string.Empty;
        }

        return raw.Replace("\\n", "\n", StringComparison.Ordinal);
    }

    public static async Task EnsureEconomySeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<EconomyDbContext>();
        await dbContext.Database.MigrateAsync();

        await SeedSubscriptionPlansAsync(dbContext);
        await SeedPaymentProviderConfigurationsAsync(dbContext);

        if (await dbContext.CurrencyPacks.AnyAsync())
        {
            dbContext.CurrencyPacks.RemoveRange(dbContext.CurrencyPacks);
            await dbContext.SaveChangesAsync();
        }

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

    private static async Task SeedPaymentProviderConfigurationsAsync(EconomyDbContext dbContext)
    {
        var now = DateTime.UtcNow;
        var defaultMode = "test";
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
                WarningMessage = "You will continue to Stripe Checkout to complete payment securely.",
                Mode = defaultMode,
                Notes = "Primary web checkout and customer portal provider.",
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
                WarningMessage = "You will continue to Stripe Checkout to complete payment securely. PetMagic does not store your card details.",
                Mode = defaultMode,
                Notes = "EU-only external checkout path for iOS pending legal review.",
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
                WarningMessage = "You will continue to Stripe Checkout to complete payment securely. PetMagic does not store your card details.",
                Mode = defaultMode,
                Notes = "EU-only alternative billing path for Android eligible regions.",
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            }
        };

        foreach (var config in configs)
        {
            var existing = await dbContext.PaymentProviderConfigurations.FirstOrDefaultAsync(
                x => x.Provider == config.Provider && x.Platform == config.Platform && x.Region == config.Region);

            if (existing is null)
            {
                dbContext.PaymentProviderConfigurations.Add(config);
                continue;
            }

            existing.IsEnabled = config.IsEnabled;
            existing.IsRecommended = config.IsRecommended;
            existing.IsSelectedByDefault = config.IsSelectedByDefault;
            existing.RequiresExternalWarning = config.RequiresExternalWarning;
            existing.RequiresStoreDisclosure = config.RequiresStoreDisclosure;
            existing.AllowedFromAppVersion = config.AllowedFromAppVersion;
            existing.ExternalCheckoutAllowed = config.ExternalCheckoutAllowed;
            existing.BonusTokensPercent = config.BonusTokensPercent;
            existing.DisplayLabel = config.DisplayLabel;
            existing.DisplaySubtitle = config.DisplaySubtitle;
            existing.WarningTitle = config.WarningTitle;
            existing.WarningMessage = config.WarningMessage;
            existing.Mode = config.Mode;
            existing.Notes = config.Notes;
            existing.UpdatedAtUtc = now;
        }

        await dbContext.SaveChangesAsync();
    }
}
