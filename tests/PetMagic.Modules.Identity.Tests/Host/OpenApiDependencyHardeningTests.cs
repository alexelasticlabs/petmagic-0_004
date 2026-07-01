namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class OpenApiDependencyHardeningTests
{
    [Fact]
    public void CentralPackages_ShouldPinPatchedMicrosoftOpenApiVersion()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "Directory.Packages.props"));

        Assert.Contains("<PackageVersion Include=\"Microsoft.OpenApi\" Version=\"2.7.5\" />", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj")]
    [InlineData("src/Modules/Economy/PetMagic.Modules.Economy.Api/PetMagic.Modules.Economy.Api.csproj")]
    [InlineData("src/Modules/Gamification/PetMagic.Modules.Gamification.Api/PetMagic.Modules.Gamification.Api.csproj")]
    [InlineData("src/Modules/Identity/PetMagic.Modules.Identity.Api/PetMagic.Modules.Identity.Api.csproj")]
    [InlineData("src/Modules/SupportChat/PetMagic.Modules.SupportChat.Api/PetMagic.Modules.SupportChat.Api.csproj")]
    [InlineData("src/Modules/Templates/PetMagic.Modules.Templates.Api/PetMagic.Modules.Templates.Api.csproj")]
    public void ApiProjects_ShouldReferenceMicrosoftOpenApiDirectly(string relativePath)
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            relativePath.Replace('/', Path.DirectorySeparatorChar)));

        Assert.Contains("<PackageReference Include=\"Microsoft.OpenApi\" />", source, StringComparison.Ordinal);
    }

    [Theory]
    [InlineData("src/Host/PetMagic.Host.Api/PetMagic.Host.Api.csproj")]
    [InlineData("src/Host/PetMagic.Host.GenerationWorker/PetMagic.Host.GenerationWorker.csproj")]
    [InlineData("src/Modules/Identity/PetMagic.Modules.Identity.Infrastructure/PetMagic.Modules.Identity.Infrastructure.csproj")]
    public void CleanProjects_ShouldNotKeepObsoleteNuGetVulnerabilitySuppressions(string relativePath)
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            relativePath.Replace('/', Path.DirectorySeparatorChar)));

        Assert.DoesNotContain("NU1902", source, StringComparison.Ordinal);
        Assert.DoesNotContain("NU1903", source, StringComparison.Ordinal);
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
