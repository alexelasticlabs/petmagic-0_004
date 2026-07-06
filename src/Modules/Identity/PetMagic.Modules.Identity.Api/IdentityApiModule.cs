using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Api.Authentication;
using PetMagic.Modules.Identity.Api.Endpoints;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Api;

public static class IdentityApiModule
{
    public static IServiceCollection AddIdentityApiModule(this IServiceCollection services)
    {
        services.AddSingleton<ExternalLoginCompletionStore>();
        services.AddSingleton<ExternalAccountLinkStore>();
        services.AddScoped<IValidator<RegisterUserCommand>, RegisterUserCommandValidator>();
        services.AddScoped<IValidator<AcceptLegalDocumentsCommand>, AcceptLegalDocumentsCommandValidator>();
        services.AddScoped<IValidator<LoginCommand>, LoginCommandValidator>();
        services.AddScoped<IValidator<UpdateCurrentUserProfileCommand>, UpdateCurrentUserProfileCommandValidator>();
        services.AddScoped<IValidator<ResendEmailVerificationCodeCommand>, ResendEmailVerificationCodeCommandValidator>();
        services.AddScoped<IValidator<VerifyEmailCodeCommand>, VerifyEmailCodeCommandValidator>();
        services.AddScoped<IValidator<RequestEmailConfirmationCommand>, RequestEmailConfirmationCommandValidator>();
        services.AddScoped<IValidator<ConfirmEmailCommand>, ConfirmEmailCommandValidator>();
        services.AddScoped<IValidator<RequestPasswordResetCommand>, RequestPasswordResetCommandValidator>();
        services.AddScoped<IValidator<VerifyPasswordResetCodeCommand>, VerifyPasswordResetCodeCommandValidator>();
        services.AddScoped<IValidator<ResetPasswordCommand>, ResetPasswordCommandValidator>();
        services.AddScoped<IValidator<ConfirmPasswordResetCommand>, ConfirmPasswordResetCommandValidator>();
        services.AddScoped<IValidator<ConfirmCurrentPasswordChangeCommand>, ConfirmCurrentPasswordChangeCommandValidator>();
        services.AddScoped<IValidator<RefreshTokenCommand>, RefreshTokenCommandValidator>();
        services.AddScoped<IValidator<LogoutCommand>, LogoutCommandValidator>();
        services.AddScoped<IValidator<ExternalLoginCallbackCommand>, ExternalLoginCallbackCommandValidator>();
        services.AddScoped<IValidator<GoogleNativeLoginCommand>, GoogleNativeLoginCommandValidator>();
        services.AddScoped<IValidator<GoogleSocialLoginCommand>, GoogleSocialLoginCommandValidator>();
        services.AddScoped<IValidator<AppleSocialLoginCommand>, AppleSocialLoginCommandValidator>();
        services.AddScoped<IValidator<SendBulkEmailCommand>, SendBulkEmailCommandValidator>();
        services.AddScoped<IValidator<AssignRoleCommand>, AssignRoleCommandValidator>();
        services.AddScoped<IValidator<RevokeRoleCommand>, RevokeRoleCommandValidator>();
        services.AddScoped<IValidator<SetUserActiveStatusCommand>, SetUserActiveStatusCommandValidator>();
        services.AddScoped<IValidator<AdminAdjustUserWalletCommand>, AdminAdjustUserWalletCommandValidator>();
        services.AddScoped<IValidator<DeleteAdminUserCommand>, DeleteAdminUserCommandValidator>();

        return services;
    }

    public static IApplicationBuilder MapIdentityApiModule(this WebApplication app)
    {
        app.MapAuthEndpoints();
        app.MapLegalEndpoints();
        app.MapAdminUserEndpoints();
        return app;
    }
}
