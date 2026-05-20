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
            AppStoreBundleId = section["AppStoreBundleId"] ?? "com.petmagic.app",
            AppStoreSharedSecret = ReadValue(section, "AppStoreSharedSecret", "APP_STORE_SHARED_SECRET") ?? string.Empty
        };

        services.AddSingleton<IOptions<EconomyOptions>>(Microsoft.Extensions.Options.Options.Create(economyOptions));

        services.AddDbContext<EconomyDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddScoped<IEconomyService, EconomyService>();
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

        if (await dbContext.CurrencyPacks.AnyAsync())
        {
            return;
        }

        dbContext.CurrencyPacks.AddRange(
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "starter",
                DisplayName = "Starter PawSpark",
                CurrencyCode = "USD",
                PriceAmount = 4.99m,
                GrantedSpark = 350,
                BonusSpark = 30,
                IsActive = true,
                SortOrder = 1
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "creator",
                DisplayName = "Creator PawSpark",
                CurrencyCode = "USD",
                PriceAmount = 9.99m,
                GrantedSpark = 800,
                BonusSpark = 120,
                IsActive = true,
                SortOrder = 2
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "viral",
                DisplayName = "Viral PawSpark",
                CurrencyCode = "USD",
                PriceAmount = 19.99m,
                GrantedSpark = 1800,
                BonusSpark = 420,
                IsActive = true,
                SortOrder = 3
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "starter",
                DisplayName = "Starter PawSpark",
                CurrencyCode = "EUR",
                PriceAmount = 4.59m,
                GrantedSpark = 350,
                BonusSpark = 30,
                IsActive = true,
                SortOrder = 1
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "creator",
                DisplayName = "Creator PawSpark",
                CurrencyCode = "EUR",
                PriceAmount = 9.19m,
                GrantedSpark = 800,
                BonusSpark = 120,
                IsActive = true,
                SortOrder = 2
            },
            new CurrencyPack
            {
                Id = Guid.NewGuid(),
                Code = "viral",
                DisplayName = "Viral PawSpark",
                CurrencyCode = "EUR",
                PriceAmount = 18.39m,
                GrantedSpark = 1800,
                BonusSpark = 420,
                IsActive = true,
                SortOrder = 3
            });

        await dbContext.SaveChangesAsync();
    }
}
