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
    public void WorkerProductionLoggingConfiguration_ShouldUseInformationJsonConsoleAndStderrForErrors()
    {
        var configurationPath = RepositoryPath(
            "src",
            "Host",
            "PetMagic.Host.GenerationWorker",
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
    public void LoggingGuide_ShouldDocumentOperationalPolicy()
    {
        var guidePath = RepositoryPath("docs", "observability", "logging.md");
        var guide = File.ReadAllText(guidePath);

        Assert.Contains("# PetMagic Logging", guide, StringComparison.Ordinal);
        Assert.Contains("## Log Levels", guide, StringComparison.Ordinal);
        Assert.Contains("## Correlation ID", guide, StringComparison.Ordinal);
        Assert.Contains("## HTTP Request Logs", guide, StringComparison.Ordinal);
        Assert.Contains("## Worker Logs", guide, StringComparison.Ordinal);
        Assert.Contains("## Payments", guide, StringComparison.Ordinal);
        Assert.Contains("## Admin Audit Log", guide, StringComparison.Ordinal);
        Assert.Contains("## Sensitive Data", guide, StringComparison.Ordinal);
        Assert.Contains("## Local Debug", guide, StringComparison.Ordinal);
        Assert.Contains("X-Correlation-ID", guide, StringComparison.Ordinal);
        Assert.Contains("LoggingOptions:SlowRequestThresholdMs", guide, StringComparison.Ordinal);
    }

    [Fact]
    public void HostBootstrapLoggers_ShouldUseStructuredConsoleAndStderrBeforeConfigurationLoads()
    {
        foreach (var programPath in new[]
        {
            RepositoryPath("src", "Host", "PetMagic.Host.Api", "Program.cs"),
            RepositoryPath("src", "Host", "PetMagic.Host.GenerationWorker", "Program.cs")
        })
        {
            var source = File.ReadAllText(programPath);

            Assert.Contains("using Serilog.Formatting.Json;", source, StringComparison.Ordinal);
            Assert.Contains(".Enrich.WithProperty(\"Environment\", ResolveBootstrapEnvironment())", source, StringComparison.Ordinal);
            Assert.Contains(
                ".WriteTo.Console(new JsonFormatter(), standardErrorFromLevel: LogEventLevel.Error)",
                source,
                StringComparison.Ordinal);
        }
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

        var lineNumber = 0;
        foreach (var line in File.ReadLines(path))
        {
            lineNumber++;
            if (SensitiveLogTemplateRegex().IsMatch(line))
            {
                yield return $"{RelativeRepositoryPath(path)}:{lineNumber} logs a sensitive transport field";
            }

            if (SensitiveUrlPlaceholderRegex().IsMatch(line))
            {
                yield return $"{RelativeRepositoryPath(path)}:{lineNumber} logs a URL or URI placeholder";
            }
        }
    }

    private static string RepositoryPath(params string[] segments)
    {
        return Path.Combine([FindRepositoryRoot(), .. segments]);
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

        throw new DirectoryNotFoundException("Could not locate repository root.");
    }

    private static string RelativeRepositoryPath(string path)
    {
        return Path.GetRelativePath(RepositoryPath(), path);
    }

    [GeneratedRegex(@"\bLog(?:Trace|Debug|Information|Warning|Error|Critical)\s*\(\s*(?:\w+\s*,\s*)?\$@?""", RegexOptions.CultureInvariant)]
    private static partial Regex InterpolatedLoggerTemplateRegex();

    [GeneratedRegex(@"\bLog(?:Trace|Debug|Information|Warning|Error|Critical)\s*\(.*\b(Payload|RequestBody|ResponseBody|Authorization|AccessToken|RefreshToken|Password|Secret|WebhookPayload|SignedUrl)\b", RegexOptions.CultureInvariant)]
    private static partial Regex SensitiveLogTemplateRegex();

    [GeneratedRegex(@"\bLog(?:Trace|Debug|Information|Warning|Error|Critical)\s*\(.*\{[A-Za-z0-9_]*(Url|Uri)\}", RegexOptions.CultureInvariant)]
    private static partial Regex SensitiveUrlPlaceholderRegex();
}
