using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Gamification.Api.Endpoints;

namespace PetMagic.Modules.Gamification.Api;

public static class GamificationApiModule
{
    public static IServiceCollection AddGamificationApiModule(this IServiceCollection services)
    {
        return services;
    }

    public static IApplicationBuilder MapGamificationApiModule(this WebApplication app)
    {
        app.MapGamificationEndpoints();
        app.MapAdminGamificationEndpoints();
        return app;
    }
}
