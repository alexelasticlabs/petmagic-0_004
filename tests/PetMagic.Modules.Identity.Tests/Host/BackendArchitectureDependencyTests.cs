using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class BackendArchitectureDependencyTests
{
    private static readonly Regex ModuleProjectNamePattern = new(
        @"^PetMagic\.Modules\.(?<module>[^.]+)\.(?<layer>Domain|Application|Infrastructure|Api)$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    private static readonly Regex EfCoreTypePattern = new(
        @"\b(?:DbContext|DbSet)\b",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    [Fact]
    public void ModuleProjectReferences_ShouldRespectArchitectureBoundaries()
    {
        var repositoryRoot = FindRepositoryRoot();
        var modulesRoot = Path.Combine(repositoryRoot, "src", "Modules");
        var violations = new List<string>();

        foreach (var projectPath in Directory.EnumerateFiles(modulesRoot, "*.csproj", SearchOption.AllDirectories))
        {
            var projectName = Path.GetFileNameWithoutExtension(projectPath);
            var sourceMatch = ModuleProjectNamePattern.Match(projectName);
            Assert.True(sourceMatch.Success, $"Unexpected module project name: {projectName}");

            var sourceModule = sourceMatch.Groups["module"].Value;
            var sourceLayer = sourceMatch.Groups["layer"].Value;
            var project = XDocument.Load(projectPath);

            if (sourceLayer != "Infrastructure")
            {
                foreach (var packageReference in project.Descendants("PackageReference"))
                {
                    var packageName = packageReference.Attribute("Include")?.Value;
                    if (packageName?.StartsWith("Microsoft.EntityFrameworkCore", StringComparison.Ordinal) == true)
                    {
                        violations.Add($"{projectName} -> {packageName}: EF Core is restricted to Infrastructure");
                    }
                }
            }

            foreach (var reference in project.Descendants("ProjectReference"))
            {
                var include = reference.Attribute("Include")?.Value;
                Assert.False(string.IsNullOrWhiteSpace(include), $"ProjectReference without Include in {projectName}");

                var normalizedInclude = include!.Replace('\\', '/');
                var targetName = Path.GetFileNameWithoutExtension(normalizedInclude);
                if (string.Equals(targetName, "PetMagic.BuildingBlocks", StringComparison.Ordinal))
                {
                    if (sourceLayer == "Domain")
                    {
                        violations.Add($"{projectName} -> {targetName}: Domain must have no project dependencies");
                    }

                    continue;
                }

                var targetMatch = ModuleProjectNamePattern.Match(targetName);
                if (!targetMatch.Success)
                {
                    violations.Add($"{projectName} -> {targetName}: unknown module project shape");
                    continue;
                }

                var targetModule = targetMatch.Groups["module"].Value;
                var targetLayer = targetMatch.Groups["layer"].Value;
                if (!IsAllowedReference(sourceModule, sourceLayer, targetModule, targetLayer))
                {
                    violations.Add($"{projectName} -> {targetName}");
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            "Forbidden module project references:" + Environment.NewLine + string.Join(Environment.NewLine, violations));
    }

    [Fact]
    public void DomainApplicationAndApiSources_ShouldNotUsePersistenceImplementations()
    {
        var repositoryRoot = FindRepositoryRoot();
        var modulesRoot = Path.Combine(repositoryRoot, "src", "Modules");
        var violations = new List<string>();

        foreach (var projectDirectory in Directory.EnumerateDirectories(modulesRoot, "PetMagic.Modules.*", SearchOption.AllDirectories))
        {
            var projectName = Path.GetFileName(projectDirectory);
            var projectMatch = ModuleProjectNamePattern.Match(projectName);
            if (!projectMatch.Success || projectMatch.Groups["layer"].Value == "Infrastructure")
            {
                continue;
            }

            foreach (var sourcePath in Directory.EnumerateFiles(projectDirectory, "*.cs", SearchOption.AllDirectories)
                         .Where(path => !IsBuildOutputPath(path)))
            {
                var source = File.ReadAllText(sourcePath);
                if (source.Contains("using Microsoft.EntityFrameworkCore", StringComparison.Ordinal)
                    || source.Contains(".Infrastructure", StringComparison.Ordinal)
                    || EfCoreTypePattern.IsMatch(source))
                {
                    violations.Add(Path.GetRelativePath(repositoryRoot, sourcePath));
                }
            }
        }

        Assert.True(
            violations.Count == 0,
            "Persistence implementation leaked into Domain/Application/Api:" + Environment.NewLine
            + string.Join(Environment.NewLine, violations.Order(StringComparer.Ordinal)));
    }

    private static bool IsAllowedReference(
        string sourceModule,
        string sourceLayer,
        string targetModule,
        string targetLayer)
    {
        return sourceLayer switch
        {
            "Domain" => false,
            "Application" => sourceModule == targetModule && targetLayer == "Domain",
            "Api" => targetLayer == "Application",
            "Infrastructure" => targetLayer == "Application"
                || (sourceModule == targetModule && targetLayer == "Domain"),
            _ => false
        };
    }

    private static bool IsBuildOutputPath(string path)
    {
        var segments = path.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        return segments.Contains("bin", StringComparer.OrdinalIgnoreCase)
            || segments.Contains("obj", StringComparer.OrdinalIgnoreCase);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "PetMagic.slnx")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate the PetMagic repository root.");
    }
}
