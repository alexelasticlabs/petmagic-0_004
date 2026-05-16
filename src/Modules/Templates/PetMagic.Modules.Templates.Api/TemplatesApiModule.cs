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
        services.AddScoped<IValidator<CreateImageTemplateCommand>, CreateImageTemplateCommandValidator>();
        services.AddScoped<IValidator<UpdateImageTemplateCommand>, UpdateImageTemplateCommandValidator>();
        services.AddScoped<IValidator<CreateVideoTemplateCommand>, CreateVideoTemplateCommandValidator>();
        services.AddScoped<IValidator<UpdateVideoTemplateCommand>, UpdateVideoTemplateCommandValidator>();
        services.AddScoped<IValidator<ChangeTemplateStatusCommand>, ChangeTemplateStatusCommandValidator>();

        return services;
    }

    public static IApplicationBuilder MapTemplatesApiModule(this WebApplication app)
    {
        app.MapAdminTemplateEndpoints();
        app.MapPublicTemplateEndpoints();
        return app;
    }
}
