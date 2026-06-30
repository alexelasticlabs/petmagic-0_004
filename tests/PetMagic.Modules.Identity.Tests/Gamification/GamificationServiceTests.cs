using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationServiceTests
{
    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldTrackGenerateAndTryTemplateChallenges()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();

        await service.ProcessGenerationCompletedAsync(
            userId,
            petId,
            templateId,
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var challenges = await service.GetCurrentChallengesAsync(userId, CancellationToken.None);

        Assert.Equal(1, challenges.Single(x => x.ChallengeType == "generate_images").CurrentValue);
        Assert.Equal(1, challenges.Single(x => x.ChallengeType == "try_templates").CurrentValue);
    }

    [Fact]
    public async Task RecordCreationSharedAsync_ShouldTrackShareChallenge()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();

        await service.RecordCreationSharedAsync(userId, CancellationToken.None);

        var challenges = await service.GetCurrentChallengesAsync(userId, CancellationToken.None);

        Assert.Equal(1, challenges.Single(x => x.ChallengeType == "share_creations").CurrentValue);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldPersistFavoriteTemplateId()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();

        await service.ProcessGenerationCompletedAsync(
            userId,
            petId,
            templateId,
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var progress = await service.GetPetProgressAsync(userId, petId, CancellationToken.None);

        Assert.NotNull(progress);
        Assert.Equal(templateId, progress!.FavoriteTemplateId);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldReturnUnlockedAchievementMetadataFromDefinition()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        dbContext.AchievementDefinitions.Add(new AchievementDefinition
        {
            Id = Guid.NewGuid(),
            Key = "first_magic",
            Category = "generation",
            Rarity = "rare",
            TitleKey = "achievementFirstMagic",
            DescriptionKey = "achievementFirstMagicDesc",
            IconEmoji = "✨",
            RequirementType = "generation_count",
            RequirementValue = 1,
            RewardSpark = 10,
            IsSecret = false,
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = new GamificationService(dbContext);
        var result = await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var achievement = Assert.Single(result.UnlockedAchievements);
        Assert.Equal("first_magic", achievement.Key);
        Assert.Equal("generation", achievement.Category);
        Assert.Equal("rare", achievement.Rarity);
        Assert.Equal("achievementFirstMagic", achievement.TitleKey);
        Assert.Equal("achievementFirstMagicDesc", achievement.DescriptionKey);
        Assert.Equal("✨", achievement.IconEmoji);
        Assert.Equal(1, achievement.CurrentProgress);
        Assert.Equal(10, achievement.RewardSpark);
    }

    [Fact]
    public async Task GetAchievementsAsync_ForUserWithoutProgress_ShouldReturnDefinitionsWithZeroProgress()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        dbContext.AchievementDefinitions.Add(new AchievementDefinition
        {
            Id = Guid.NewGuid(),
            Key = "first_magic",
            Category = "generation",
            Rarity = "common",
            TitleKey = "achievementFirstMagic",
            DescriptionKey = "achievementFirstMagicDesc",
            IconEmoji = "✨",
            RequirementType = "generation_count",
            RequirementValue = 1,
            RewardSpark = 10,
            IsSecret = false,
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();

        var achievements = await service.GetAchievementsAsync(userId, CancellationToken.None);

        Assert.NotEmpty(achievements);
        var firstMagic = Assert.Single(achievements, x => x.Key == "first_magic");
        Assert.False(firstMagic.IsUnlocked);
        Assert.Equal(0, firstMagic.CurrentProgress);
    }

    private static GamificationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<GamificationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new GamificationDbContext(options);
    }
}
