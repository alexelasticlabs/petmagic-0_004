namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminUserTemplateAnalyticsReaderHardeningTests
{
    [Fact]
    public void AnalyticsReader_ShouldNormalizeLegacyNullGenerationAndEventStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "AdminUserTemplateAnalyticsReader.cs"));

        Assert.Contains("x.TemplateTitle ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.EventType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Source ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.DeviceClass ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CountryCode ?? string.Empty", source, StringComparison.Ordinal);
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
