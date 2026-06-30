namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationSchemaSourceTests
{
    [Fact]
    public void AchievementDefinitionSchema_ShouldNotContainLegacyIconAssetPathColumn()
    {
        var repositoryRoot = FindRepositoryRoot();
        var entitySource = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Entities",
            "AchievementDefinition.cs"));
        var dbContextSource = File.ReadAllText(Path.Combine(
            repositoryRoot,
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Data",
            "GamificationDbContext.cs"));

        Assert.DoesNotContain("IconAssetPath", entitySource, StringComparison.Ordinal);
        Assert.DoesNotContain("IconAssetPath", dbContextSource, StringComparison.Ordinal);
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
