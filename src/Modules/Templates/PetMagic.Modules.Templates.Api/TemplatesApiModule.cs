using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Api.Endpoints;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Application.Validation;

namespace PetMagic.Modules.Templates.Api;

public static class TemplatesApiModule
{
    public static IServiceCollection AddTemplatesApiModule(this IServiceCollection services)
    {
        services.AddMemoryCache();
        services.AddScoped<IValidator<CreateTemplateCategoryCommand>, CreateTemplateCategoryCommandValidator>();
        services.AddScoped<IValidator<UpdateTemplateCategoryCommand>, UpdateTemplateCategoryCommandValidator>();
        services.AddScoped<IValidator<ChangeTemplateCategoryArchiveStateCommand>, ChangeTemplateCategoryArchiveStateCommandValidator>();
        services.AddScoped<IValidator<CreateImageTemplateCommand>, CreateImageTemplateCommandValidator>();
        services.AddScoped<IValidator<UpdateImageTemplateCommand>, UpdateImageTemplateCommandValidator>();
        services.AddScoped<IValidator<CreateVideoTemplateCommand>, CreateVideoTemplateCommandValidator>();
        services.AddScoped<IValidator<UpdateVideoTemplateCommand>, UpdateVideoTemplateCommandValidator>();
        services.AddScoped<IValidator<ChangeTemplateStatusCommand>, ChangeTemplateStatusCommandValidator>();
        services.AddScoped<IValidator<StartTemplateGenerationCommand>, StartTemplateGenerationCommandValidator>();
        services.AddScoped<IValidator<StartTemplateGenerationFromResultCommand>, StartTemplateGenerationFromResultCommandValidator>();
        services.AddScoped<IValidator<StartSimilarTemplateGenerationCommand>, StartSimilarTemplateGenerationCommandValidator>();
        services.AddScoped<IValidator<RegisterTemplatePushTokenCommand>, RegisterTemplatePushTokenCommandValidator>();
        services.AddScoped<IValidator<UnregisterTemplatePushTokenCommand>, UnregisterTemplatePushTokenCommandValidator>();
        services.AddScoped<IValidator<SubmitFeedbackCommand>, SubmitFeedbackCommandValidator>();
        services.AddScoped<IValidator<UpdateFeedbackAdminCommand>, UpdateFeedbackAdminCommandValidator>();
        services.AddScoped<IValidator<RefundFeedbackCreditsCommand>, RefundFeedbackCreditsCommandValidator>();
        services.AddHttpClient(FalWebhookSignatureVerifier.HttpClientName);
        services.AddScoped<IFalWebhookSignatureVerifier, FalWebhookSignatureVerifier>();

        return services;
    }

    public static IApplicationBuilder MapTemplatesApiModule(this WebApplication app)
    {
        app.MapAdminTemplateCategoryEndpoints();
        app.MapAdminTemplateEndpoints();
        app.MapFeedbackEndpoints();
        app.MapPublicTemplateEndpoints();
        app.MapPetEndpoints();
        app.MapTemplateGenerationEndpoints();
        return app;
    }
}
