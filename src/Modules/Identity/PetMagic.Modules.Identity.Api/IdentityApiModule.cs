using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using PetMagic.Modules.Identity.Api.Endpoints;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Api;

public static class IdentityApiModule
{
    public static IServiceCollection AddIdentityApiModule(this IServiceCollection services)
    {
        services.AddScoped<IValidator<RegisterUserCommand>, RegisterUserCommandValidator>();
        services.AddScoped<IValidator<LoginCommand>, LoginCommandValidator>();
        services.AddScoped<IValidator<RefreshTokenCommand>, RefreshTokenCommandValidator>();
        services.AddScoped<IValidator<LogoutCommand>, LogoutCommandValidator>();
        services.AddScoped<IValidator<ExternalLoginCallbackCommand>, ExternalLoginCallbackCommandValidator>();
        services.AddScoped<IValidator<AssignRoleCommand>, AssignRoleCommandValidator>();
        services.AddScoped<IValidator<RevokeRoleCommand>, RevokeRoleCommandValidator>();
        services.AddScoped<IValidator<SetPremiumStatusCommand>, SetPremiumStatusCommandValidator>();
        services.AddScoped<IValidator<SetUserActiveStatusCommand>, SetUserActiveStatusCommandValidator>();

        return services;
    }

    public static IApplicationBuilder MapIdentityApiModule(this WebApplication app)
    {
        app.MapAuthEndpoints();
        app.MapAdminUserEndpoints();
        return app;
    }
}
