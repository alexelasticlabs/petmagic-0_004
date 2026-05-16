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
        services.AddScoped<IValidator<CreatePackPurchaseCommand>, CreatePackPurchaseCommandValidator>();
        services.AddScoped<IValidator<ConfirmPackPurchaseCommand>, ConfirmPackPurchaseCommandValidator>();
        services.AddScoped<IValidator<StripeWebhookCommand>, StripeWebhookCommandValidator>();

        return services;
    }

    public static IApplicationBuilder MapEconomyApiModule(this WebApplication app)
    {
        app.MapEconomyEndpoints();
        return app;
    }
}
