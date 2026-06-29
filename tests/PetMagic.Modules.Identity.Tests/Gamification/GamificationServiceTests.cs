using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationServiceTests
{
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
