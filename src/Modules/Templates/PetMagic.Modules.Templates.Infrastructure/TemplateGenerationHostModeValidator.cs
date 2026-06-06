using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace PetMagic.Modules.Templates.Infrastructure;

public static class TemplateGenerationHostModeValidator
{
    public static void RequireGenerationWorkerMode(
        IConfiguration configuration,
        IHostEnvironment environment,
        string hostName,
        bool expectedEnabled)
    {
        if (!environment.IsProduction())
        {
            return;
        }

        var configuredValue = configuration["Templates:GenerationWorkerEnabled"];
        if (!TryReadBool(configuredValue, defaultValue: true, out var enabled))
        {
            throw new InvalidOperationException(
                $"{hostName} requires Templates:GenerationWorkerEnabled to be a boolean value in Production.");
        }

        if (enabled == expectedEnabled)
        {
            return;
        }

        var expectedValue = expectedEnabled ? "true" : "false";
        throw new InvalidOperationException(
            $"{hostName} requires Templates:GenerationWorkerEnabled={expectedValue} in Production.");
    }

    private static bool TryReadBool(string? rawValue, bool defaultValue, out bool value)
    {
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            value = defaultValue;
            return true;
        }

        return bool.TryParse(rawValue, out value);
    }
}
