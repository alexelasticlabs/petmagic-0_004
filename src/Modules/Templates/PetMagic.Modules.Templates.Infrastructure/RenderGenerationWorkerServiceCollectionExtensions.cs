using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class RenderGenerationWorkerServiceCollectionExtensions
{
    private static readonly Uri RenderApiBaseUri = new("https://api.render.com/v1/", UriKind.Absolute);

    public static IServiceCollection AddRenderGenerationWorkerControl(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(services);
        ArgumentNullException.ThrowIfNull(configuration);

        var section = configuration.GetSection(RenderGenerationWorkerOptions.SectionName);
        var options = new RenderGenerationWorkerOptions
        {
            ApiKey = ReadValue(section, configuration, "ApiKey", "RENDER_API_KEY"),
            ServiceId = ReadValue(section, configuration, "ServiceId", "RENDER_GENERATION_WORKER_SERVICE_ID"),
            ExpectedOwnerId = ReadValue(
                section,
                configuration,
                "ExpectedOwnerId",
                "RENDER_GENERATION_WORKER_EXPECTED_OWNER_ID"),
            ExpectedServiceName = ReadValue(
                section,
                configuration,
                "ExpectedServiceName",
                "RENDER_GENERATION_WORKER_EXPECTED_NAME"),
            ExpectedServiceType = ReadValue(
                    section,
                    configuration,
                    "ExpectedServiceType",
                    "RENDER_GENERATION_WORKER_EXPECTED_TYPE")
                is { Length: > 0 } expectedType
                    ? expectedType
                    : "background_worker",
            ExpectedRepository = ReadValue(
                section,
                configuration,
                "ExpectedRepository",
                "RENDER_GENERATION_WORKER_EXPECTED_REPOSITORY"),
            MinimumInstances = ReadBoundedInt(
                section["MinimumInstances"] ?? configuration["RENDER_GENERATION_WORKER_MIN_INSTANCES"],
                RenderGenerationWorkerOptions.DefaultMinimumInstances,
                minimum: 1,
                maximum: RenderGenerationWorkerOptions.DefaultMaximumInstances),
            MaximumInstances = ReadBoundedInt(
                section["MaximumInstances"] ?? configuration["RENDER_GENERATION_WORKER_MAX_INSTANCES"],
                RenderGenerationWorkerOptions.DefaultMaximumInstances,
                minimum: RenderGenerationWorkerOptions.DefaultMinimumInstances,
                maximum: RenderGenerationWorkerOptions.DefaultMaximumInstances)
        };

        if (options.MaximumInstances < options.MinimumInstances)
        {
            throw new InvalidOperationException(
                "Render generation worker maximum instances must be greater than or equal to minimum instances.");
        }

        services.AddSingleton(options);
        services.AddHttpClient(RenderGenerationWorkerClient.HttpClientName, client =>
            {
                client.BaseAddress = RenderApiBaseUri;
                client.Timeout = TimeSpan.FromSeconds(15);
            })
            .ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
            {
                AllowAutoRedirect = false,
                PooledConnectionLifetime = TimeSpan.FromMinutes(5)
            });
        services.AddSingleton<IRenderGenerationWorkerClient, RenderGenerationWorkerClient>();
        services.AddScoped<IAdminGenerationRenderControlService, AdminGenerationRenderControlService>();
        services.AddScoped<TemplateRenderScaleOperationProcessor>();
        services.AddHostedService<TemplateRenderScaleOperationWorker>();
        services.AddSingleton<RenderGenerationWorkerMonitor>();
        services.AddHostedService(serviceProvider =>
            serviceProvider.GetRequiredService<RenderGenerationWorkerMonitor>());

        return services;
    }

    private static string ReadValue(
        IConfigurationSection section,
        IConfiguration configuration,
        string sectionKey,
        string environmentKey)
    {
        var value = section[sectionKey];
        if (string.IsNullOrWhiteSpace(value))
        {
            value = configuration[environmentKey];
        }

        return value?.Trim() ?? string.Empty;
    }

    private static int ReadBoundedInt(string? value, int fallback, int minimum, int maximum) =>
        int.TryParse(value, out var parsed)
            ? Math.Clamp(parsed, minimum, maximum)
            : fallback;
}
