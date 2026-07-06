namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateStoragePathResolutionSourceTests
{
    [Fact]
    public void TemplateGenerationStoragePathResolution_ShouldRejectTraversalAndMalformedBaseUrls()
    {
        var source = File.ReadAllText(SourcePath("TemplateGenerationService.StoragePathResolution.cs"));

        Assert.Contains("TryNormalizeManagedStoragePath", source, StringComparison.Ordinal);
        Assert.Contains("candidate[localBaseUrl.Length] == '/'", source, StringComparison.Ordinal);
        Assert.Contains("candidate[r2BaseUrl.Length] != '/'", source, StringComparison.Ordinal);
        Assert.Contains("ManagedPathSegments.IsUnsafe(segment)", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "return storageKey.StartsWith($\"{objectKeyPrefix}/\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
    }

    private static string SourcePath(string fileName)
    {
        return Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            fileName);
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
}
