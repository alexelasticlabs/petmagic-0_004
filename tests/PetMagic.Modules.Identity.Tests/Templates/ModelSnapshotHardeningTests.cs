namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class ModelSnapshotHardeningTests
{
    [Fact]
    public void SplitModelSnapshots_ShouldDeclareSingleDbContextAttributePerSnapshotGroup()
    {
        var repositoryRoot = FindRepositoryRoot();
        var migrationRoot = Path.Combine(repositoryRoot, "src", "Modules");
        var snapshotFiles = Directory.GetFiles(
            migrationRoot,
            "*DbContextModelSnapshot*.cs",
            SearchOption.AllDirectories);

        var violations = snapshotFiles
            .GroupBy(GetSnapshotGroupName, StringComparer.Ordinal)
            .Select(group => new
            {
                SnapshotGroup = group.Key,
                AttributeCount = group.Sum(file => CountOccurrences(File.ReadAllText(file), "[DbContext(")),
                Files = group.Select(Path.GetFileName).OrderBy(name => name, StringComparer.Ordinal).ToArray(),
            })
            .Where(result => result.AttributeCount != 1)
            .Select(result => $"{result.SnapshotGroup}: found {result.AttributeCount} DbContext attributes in {string.Join(", ", result.Files)}")
            .ToArray();

        Assert.True(
            violations.Length == 0,
            "Each DbContext model snapshot group must declare exactly one [DbContext(...)] attribute. Violations: "
            + string.Join("; ", violations));
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

    private static string GetSnapshotGroupName(string filePath)
    {
        var fileName = Path.GetFileNameWithoutExtension(filePath);
        var separatorIndex = fileName.IndexOf('.');
        return separatorIndex >= 0 ? fileName[..separatorIndex] : fileName;
    }

    private static int CountOccurrences(string source, string pattern)
    {
        var count = 0;
        var offset = 0;

        while (offset < source.Length)
        {
            var index = source.IndexOf(pattern, offset, StringComparison.Ordinal);
            if (index < 0)
            {
                break;
            }

            count++;
            offset = index + pattern.Length;
        }

        return count;
    }
}
