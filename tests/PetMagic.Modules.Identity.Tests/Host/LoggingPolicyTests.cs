using System.Text.RegularExpressions;
using System.Text.Json;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed partial class LoggingPolicyTests
{
    [Fact]
    public void ApiProductionLoggingConfiguration_ShouldUseInformationJsonConsoleAndStderrForErrors()
    {
        var configurationPath = RepositoryPath(
            "src",
            "Host",
            "PetMagic.Host.Api",
            "appsettings.Production.json");

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

    [Fact]
    public void SourceLoggingPolicy_ShouldNotUseConsoleWriteLineOrInterpolatedLoggerTemplates()
    {
        var sourceRoot = RepositoryPath("src");
        var violations = Directory
            .EnumerateFiles(sourceRoot, "*.cs", SearchOption.AllDirectories)
            .Where(path => !path.Contains($"{Path.DirectorySeparatorChar}bin{Path.DirectorySeparatorChar}", StringComparison.Ordinal)
                && !path.Contains($"{Path.DirectorySeparatorChar}obj{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            .SelectMany(ReadViolations)
            .ToArray();

        Assert.Empty(violations);
    }

    private static IEnumerable<string> ReadViolations(string path)
    {
        var text = File.ReadAllText(path);
        if (text.Contains("Console.WriteLine", StringComparison.Ordinal)
            || text.Contains("Console.Error.WriteLine", StringComparison.Ordinal)
            || text.Contains("Console.Out.WriteLine", StringComparison.Ordinal))
        {
            yield return $"{RelativeRepositoryPath(path)} uses direct console output";
        }

        if (InterpolatedLoggerTemplateRegex().IsMatch(text))
        {
            yield return $"{RelativeRepositoryPath(path)} uses interpolated logger templates";
        }
    }

    private static string RepositoryPath(params string[] segments)
    {
        return Path.GetFullPath(Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            "..",
            "..",
            Path.Combine(segments)));
    }

    private static string RelativeRepositoryPath(string path)
    {
        return Path.GetRelativePath(RepositoryPath(), path);
    }

    [GeneratedRegex(@"\bLog(?:Trace|Debug|Information|Warning|Error|Critical)\s*\(\s*(?:\w+\s*,\s*)?\$@?""", RegexOptions.CultureInvariant)]
    private static partial Regex InterpolatedLoggerTemplateRegex();
}
