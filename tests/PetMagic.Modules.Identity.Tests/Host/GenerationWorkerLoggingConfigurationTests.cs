using System.Text.Json;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class GenerationWorkerLoggingConfigurationTests
{
    [Fact]
    public void ProductionLoggingConfiguration_ShouldUseInformationJsonConsoleAndStderrForErrors()
    {
        var configurationPath = Path.GetFullPath(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
            "appsettings.Production.json"));

        using var document = JsonDocument.Parse(File.ReadAllText(configurationPath));
        var serilog = document.RootElement.GetProperty("Serilog");
        var minimumLevel = serilog.GetProperty("MinimumLevel");
        var overrides = minimumLevel.GetProperty("Override");
        var consoleArgs = serilog.GetProperty("WriteTo")[0].GetProperty("Args");

        Assert.Equal("Information", minimumLevel.GetProperty("Default").GetString());
        Assert.Equal("Warning", overrides.GetProperty("System").GetString());
        Assert.Equal("Warning", overrides.GetProperty("Microsoft").GetString());
        Assert.Equal("Serilog.Formatting.Json.JsonFormatter, Serilog", consoleArgs.GetProperty("formatter").GetString());
        Assert.Equal("Error", consoleArgs.GetProperty("standardErrorFromLevel").GetString());
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
