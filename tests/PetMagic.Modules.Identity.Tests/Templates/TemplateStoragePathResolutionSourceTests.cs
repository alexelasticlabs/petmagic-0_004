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
        Assert.Contains("string.Equals(segment, \".\", StringComparison.Ordinal)", source, StringComparison.Ordinal);
        Assert.Contains("string.Equals(segment, \"..\", StringComparison.Ordinal)", source, StringComparison.Ordinal);
        Assert.DoesNotContain(
            "return storageKey.StartsWith($\"{objectKeyPrefix}/\", StringComparison.OrdinalIgnoreCase)",
            source,
            StringComparison.Ordinal);
    }

    private static string SourcePath(string fileName)
    {
        return Path.Combine(
            AppContext.BaseDirectory,
            "..",
            "..",
            "..",
            "..",
            "..",
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            fileName);
    }
}
