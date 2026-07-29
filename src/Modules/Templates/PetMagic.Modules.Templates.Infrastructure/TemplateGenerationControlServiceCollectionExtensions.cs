using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationControlServiceCollectionExtensions
{
    internal static IServiceCollection AddTemplateGenerationControlFoundation(
        this IServiceCollection services,
        bool runProviderMonitor,
        bool schedulerV2Enabled)
    {
        services.AddScoped<TemplateGenerationControlService>();
        services.AddScoped<ITemplateGenerationControlService>(serviceProvider =>
            serviceProvider.GetRequiredService<TemplateGenerationControlService>());
        services.AddScoped<ITemplateGenerationRuntimePolicyProvider>(serviceProvider =>
            serviceProvider.GetRequiredService<TemplateGenerationControlService>());
        services.AddScoped<IFalProviderRuntimeSnapshotService, FalProviderRuntimeSnapshotService>();
        if (schedulerV2Enabled)
        {
            services.AddScoped<ITemplateGenerationProviderAttemptStore, TemplateGenerationProviderAttemptStore>();
        }
        services.AddHttpClient(
                FalProviderRuntimeSnapshotService.HttpClientName,
                client => client.Timeout = TimeSpan.FromSeconds(15))
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false
            });
        if (runProviderMonitor)
        {
            services.AddHostedService<FalProviderRuntimeSnapshotMonitor>();
        }

        return services;
    }
}
