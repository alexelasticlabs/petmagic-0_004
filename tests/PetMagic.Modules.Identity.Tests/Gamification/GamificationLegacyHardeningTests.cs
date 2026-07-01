using System.Reflection;

using PetMagic.Modules.Gamification.Application.Contracts;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationLegacyHardeningTests
{
    [Fact]
    public void GamificationService_ShouldNormalizeLegacyNullAchievementAndChallengeStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Services",
            "GamificationService.cs"));

        Assert.Contains("var normalizedKey = NormalizeAchievementKey(def.Key);", source, StringComparison.Ordinal);
        Assert.Contains("var normalizedAchievementKey = NormalizeAchievementKey(achievement.AchievementKey);", source, StringComparison.Ordinal);
        Assert.Contains("def.Category ?? \"special\"", source, StringComparison.Ordinal);
        Assert.Contains("def.Rarity ?? \"common\"", source, StringComparison.Ordinal);
        Assert.Contains("def.TitleKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("def.DescriptionKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("var normalizedKey = NormalizeAchievementKey(earned.AchievementKey);", source, StringComparison.Ordinal);
        Assert.Contains("c.ChallengeType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("c.TitleKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("c.DescriptionKey ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void GamificationService_ShouldGuardDictionaryLookupsAgainstLegacyNullAchievementKeys()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Services",
            "GamificationService.cs"));

        Assert.Contains("private static string NormalizeAchievementKey(string? value) => value?.Trim() ?? string.Empty;", source, StringComparison.Ordinal);
        Assert.Contains("Select(a => NormalizeAchievementKey(a.AchievementKey))", source, StringComparison.Ordinal);
        Assert.Contains("Select(NormalizeAchievementKey)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ToDictionaryAsync(x => x.AchievementKey", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ToDictionaryAsync(d => d.Key", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ToDictionaryAsync(x => x.Key", source, StringComparison.Ordinal);
    }

    [Fact]
    public void GamificationService_ShouldNormalizeLegacyNullEvolutionStage()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Services",
            "GamificationService.cs"));

        Assert.Contains("progress.EvolutionStage ?? \"egg\"", source, StringComparison.Ordinal);
        Assert.Contains("p.EvolutionStage ?? \"egg\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void GamificationAdminService_ShouldNormalizeLegacyNullAdminStrings()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Services",
            "GamificationAdminService.cs"));

        Assert.Contains("var normalizedKey = NormalizeAchievementKey(def.Key);", source, StringComparison.Ordinal);
        Assert.Contains("def.Category ?? \"special\"", source, StringComparison.Ordinal);
        Assert.Contains("def.Rarity ?? \"common\"", source, StringComparison.Ordinal);
        Assert.Contains("def.TitleKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("def.DescriptionKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("def.RequirementType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("challenge.ChallengeType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("challenge.TitleKey ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("challenge.DescriptionKey ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void GamificationAdminService_ShouldGuardUnlockedCountsAgainstLegacyNullAchievementKeys()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Gamification",
            "PetMagic.Modules.Gamification.Infrastructure",
            "Services",
            "GamificationAdminService.cs"));

        Assert.Contains("private static string NormalizeAchievementKey(string? value) => value?.Trim() ?? string.Empty;", source, StringComparison.Ordinal);
        Assert.Contains("Key = NormalizeAchievementKey(row.AchievementKey)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ToDictionaryAsync(x => x.Key, x => x.Count", source, StringComparison.Ordinal);
    }

    [Fact]
    public void GamificationAdminPetMapper_ShouldNormalizeLegacyNullEvolutionStage()
    {
        var method = typeof(GamificationAdminService).GetMethod(
            "MapPetProgress",
            BindingFlags.NonPublic | BindingFlags.Static);

        var response = Assert.IsType<PetProgressResponse>(method!.Invoke(null, [
            new PetProgress
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                PetId = Guid.NewGuid(),
                Xp = 10,
                Level = 1,
                EvolutionStage = null!,
                TotalGenerations = 1,
                CreatedAtUtc = DateTime.UtcNow.AddDays(-1),
                UpdatedAtUtc = DateTime.UtcNow,
            }
        ]));

        Assert.Equal("egg", response.EvolutionStage);
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
