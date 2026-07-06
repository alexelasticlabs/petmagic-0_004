using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Http;

using PetMagic.Host.GenerationWorker;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure;

using Serilog;
using Serilog.Events;
using Serilog.Formatting.Json;

LoadDotEnvFileIfPresent();

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Override("Microsoft", LogEventLevel.Warning)
    .Enrich.WithProperty("ApplicationName", "PetMagic.Host.GenerationWorker")
    .Enrich.WithProperty("Environment", ResolveBootstrapEnvironment())
    .WriteTo.Console(new JsonFormatter(), standardErrorFromLevel: LogEventLevel.Error)
    .CreateLogger();

try
{
    var builder = Host.CreateApplicationBuilder(args);

    TemplateGenerationHostModeValidator.RequireGenerationWorkerMode(
        builder.Configuration,
        builder.Environment,
        "PetMagic.Host.GenerationWorker",
        expectedEnabled: true);

    builder.Services.AddSerilog((_, loggerConfiguration) =>
    {
        loggerConfiguration
            .ReadFrom.Configuration(builder.Configuration)
            .Enrich.FromLogContext()
            .Enrich.WithProperty("ApplicationName", "PetMagic.Host.GenerationWorker")
            .Enrich.WithProperty("Environment", builder.Environment.EnvironmentName);
    });

    builder.Services.AddMemoryCache();
    builder.Services.AddTransient<WorkerCorrelationIdDelegatingHandler>();
    builder.Services.ConfigureAll<HttpClientFactoryOptions>(options =>
    {
        options.HttpMessageHandlerBuilderActions.Add(httpMessageHandlerBuilder =>
        {
            httpMessageHandlerBuilder.AdditionalHandlers.Add(
                httpMessageHandlerBuilder.Services.GetRequiredService<WorkerCorrelationIdDelegatingHandler>());
        });
    });

    builder.Services
        .AddEconomyInfrastructure(builder.Configuration, builder.Environment.IsProduction())
        .AddTemplatesInfrastructure(
            builder.Configuration,
            builder.Environment,
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent);

    builder.Services
        .AddOpenTelemetry()
        .ConfigureResource(resource => resource.AddService("PetMagic.Host.GenerationWorker"))
        .WithTracing(tracing =>
        {
            tracing.AddHttpClientInstrumentation();

            if (IsOtlpExporterConfigured(builder.Configuration))
            {
                tracing.AddOtlpExporter();
            }
        })
        .WithMetrics(metrics =>
        {
            metrics
                .AddHttpClientInstrumentation()
                .AddRuntimeInstrumentation()
                .AddMeter("PetMagic.Modules.Economy")
                .AddMeter("PetMagic.Modules.Templates");

            if (IsOtlpExporterConfigured(builder.Configuration))
            {
                metrics.AddOtlpExporter();
            }
        });

    var host = builder.Build();

    Directory.CreateDirectory(Path.Combine(host.Services.GetRequiredService<IHostEnvironment>().ContentRootPath, "wwwroot"));
    Directory.CreateDirectory(Path.Combine(host.Services.GetRequiredService<IHostEnvironment>().ContentRootPath, "wwwroot", "templates-media"));

    await host.RunAsync();
}
catch (Exception exception)
{
    Log.Fatal(exception, "PetMagic.Host.GenerationWorker stopped during startup or runtime.");
    throw;
}
finally
{
    Log.CloseAndFlush();
}

static void LoadDotEnvFileIfPresent()
{
    var environmentName = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
    if (!string.Equals(environmentName, Environments.Development, StringComparison.OrdinalIgnoreCase))
    {
        return;
    }

    var currentDirectory = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (currentDirectory is not null)
    {
        var envPath = Path.Combine(currentDirectory.FullName, ".env");
        if (!File.Exists(envPath))
        {
            currentDirectory = currentDirectory.Parent;
            continue;
        }

        foreach (var rawLine in File.ReadLines(envPath))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#'))
            {
                continue;
            }

            if (line.StartsWith("export ", StringComparison.Ordinal))
            {
                line = line["export ".Length..].TrimStart();
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            if (string.IsNullOrWhiteSpace(key) || Environment.GetEnvironmentVariable(key) is not null)
            {
                continue;
            }

            var value = line[(separatorIndex + 1)..].Trim();
            if (value.Length >= 2
                && ((value.StartsWith('"') && value.EndsWith('"'))
                    || (value.StartsWith('\'') && value.EndsWith('\''))))
            {
                value = value[1..^1];
            }

            Environment.SetEnvironmentVariable(key, value);
        }

        return;
    }
}

static string ResolveBootstrapEnvironment()
{
    return Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
        ?? Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
        ?? Environments.Production;
}

static bool IsOtlpExporterConfigured(IConfiguration configuration) =>
    !string.IsNullOrWhiteSpace(configuration["OpenTelemetry:Otlp:Endpoint"])
    || !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT"));
