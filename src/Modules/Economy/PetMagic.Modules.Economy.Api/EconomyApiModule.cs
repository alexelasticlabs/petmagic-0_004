using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Economy.Api.Endpoints;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Application.Validation;

namespace PetMagic.Modules.Economy.Api;

public static class EconomyApiModule
{
    public static IServiceCollection AddEconomyApiModule(this IServiceCollection services)
    {
        services.AddScoped<IValidator<ClaimWeeklyGrantCommand>, ClaimWeeklyGrantCommandValidator>();
        services.AddScoped<IValidator<ClaimAdRewardCommand>, ClaimAdRewardCommandValidator>();
        services.AddScoped<IValidator<SpendBalanceCommand>, SpendBalanceCommandValidator>();
        services.AddScoped<IValidator<CreditBalanceCommand>, CreditBalanceCommandValidator>();
        services.AddScoped<IValidator<CreatePackPurchaseCommand>, CreatePackPurchaseCommandValidator>();
        services.AddScoped<IValidator<CreatePremiumCheckoutCommand>, CreatePremiumCheckoutCommandValidator>();
        services.AddScoped<IValidator<CreatePremiumBillingPortalCommand>, CreatePremiumBillingPortalCommandValidator>();
        services.AddScoped<IValidator<CancelPremiumSubscriptionCommand>, CancelPremiumSubscriptionCommandValidator>();
        services.AddScoped<IValidator<AdminRefundPurchaseCommand>, AdminRefundPurchaseCommandValidator>();
        services.AddScoped<IValidator<VerifyPremiumStorePurchaseCommand>, VerifyPremiumStorePurchaseCommandValidator>();
        services.AddScoped<IValidator<VerifyPremiumStripeSubscriptionCommand>, VerifyPremiumStripeSubscriptionCommandValidator>();
        services.AddScoped<IValidator<VerifyPackStorePurchaseCommand>, VerifyPackStorePurchaseCommandValidator>();
        services.AddScoped<IValidator<RegisterEconomyPushTokenCommand>, RegisterEconomyPushTokenCommandValidator>();
        services.AddScoped<IValidator<UnregisterEconomyPushTokenCommand>, UnregisterEconomyPushTokenCommandValidator>();
        services.AddScoped<IValidator<CreatePaymentMethodSetupCommand>, CreatePaymentMethodSetupCommandValidator>();
        services.AddScoped<IValidator<RemovePaymentMethodCommand>, RemovePaymentMethodCommandValidator>();
        services.AddScoped<IValidator<StripeWebhookCommand>, StripeWebhookCommandValidator>();
        services.AddScoped<IValidator<AppStoreServerNotificationCommand>, AppStoreServerNotificationCommandValidator>();
        services.AddScoped<IValidator<GooglePlayDeveloperNotificationCommand>, GooglePlayDeveloperNotificationCommandValidator>();
        services.AddScoped<IValidator<UpdateCurrencyPackCommand>, UpdateCurrencyPackCommandValidator>();
        services.AddScoped<IValidator<UpdateSubscriptionPlanCommand>, UpdateSubscriptionPlanCommandValidator>();
        services.AddScoped<IValidator<UpdatePaymentProviderConfigurationCommand>, UpdatePaymentProviderConfigurationCommandValidator>();
        services.AddScoped<IValidator<ApplyRedeemCodeCommand>, ApplyRedeemCodeCommandValidator>();
        services.AddScoped<IValidator<ApplyReferralCodeCommand>, ApplyReferralCodeCommandValidator>();
        services.AddScoped<IValidator<CreateRedeemCodeCommand>, CreateRedeemCodeCommandValidator>();
        services.AddScoped<IValidator<UpdateRedeemCodeCommand>, UpdateRedeemCodeCommandValidator>();

        return services;
    }

    public static IApplicationBuilder MapEconomyApiModule(this WebApplication app)
    {
        app.MapEconomyEndpoints();
        app.MapAdminEconomyEndpoints();
        return app;
    }
}
