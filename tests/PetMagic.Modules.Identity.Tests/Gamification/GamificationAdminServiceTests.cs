using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;
using PetMagic.Modules.Gamification.Infrastructure.Services;

namespace PetMagic.Modules.Identity.Tests.Gamification;

public sealed class GamificationAdminServiceTests
{
    [Fact]
    public async Task GetAdminDashboardMetricsAsync_ShouldReportCurrentWeekUsage()
    {
        await using var dbContext = CreateDbContext();
        var weekStart = GetCurrentWeekStart();
        var userId = Guid.NewGuid();

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
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.PetProgresses.Add(new PetProgress
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PetId = Guid.NewGuid(),
            Xp = 120,
            Level = 3,
            EvolutionStage = "baby",
            TotalGenerations = 4,
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        dbContext.DailyStreaks.Add(new DailyStreak
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            CurrentStreak = 3,
            LongestStreak = 3,
            LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow),
            CreatedAtUtc = DateTime.UtcNow,
            UpdatedAtUtc = DateTime.UtcNow
        });
        var challengeId = Guid.NewGuid();
        dbContext.WeeklyChallenges.Add(new WeeklyChallenge
        {
            Id = challengeId,
            WeekStartDate = weekStart,
            ChallengeType = "generate_images",
            TargetValue = 5,
            TitleKey = "gamificationChallengeGenerateImages",
            DescriptionKey = "gamificationChallengeGenerateImagesDesc",
            RewardSpark = 25,
            SortOrder = 0,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.UserChallengeProgresses.Add(new UserChallengeProgress
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            ChallengeId = challengeId,
            CurrentValue = 5,
            Completed = true,
            CompletedAtUtc = DateTime.UtcNow
        });
        dbContext.UserAchievements.Add(new UserAchievement
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            AchievementKey = "first_magic",
            UnlockedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var service = CreateAdminService(dbContext);

        var result = await service.GetAdminDashboardMetricsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(1, result.Value.TotalUsersWithProgress);
        Assert.Equal(1, result.Value.TotalPetsTracked);
        Assert.Equal(1, result.Value.TotalAchievementDefinitions);
        Assert.Equal(1, result.Value.TotalAchievementsUnlocked);
        Assert.Equal(1, result.Value.UsersWithActiveStreak);
        Assert.Equal(1, result.Value.CurrentWeekChallenges);
        Assert.Equal(1, result.Value.CurrentWeekChallengeParticipants);
        Assert.Equal(1, result.Value.CurrentWeekChallengeCompletions);
    }

    [Fact]
    public async Task ListAdminAchievementsAsync_ShouldIncludeUnlockedUserCounts()
    {
        await using var dbContext = CreateDbContext();
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
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        dbContext.UserAchievements.AddRange(
            new UserAchievement
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                AchievementKey = "first_magic",
                UnlockedAtUtc = DateTime.UtcNow
            },
            new UserAchievement
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                AchievementKey = "first_magic",
                UnlockedAtUtc = DateTime.UtcNow
            });
        await dbContext.SaveChangesAsync();

        var service = CreateAdminService(dbContext);

        var result = await service.ListAdminAchievementsAsync(CancellationToken.None);

        var achievement = Assert.Single(result.Value);
        Assert.Equal("first_magic", achievement.Key);
        Assert.Equal(2, achievement.UnlockedUsersCount);
    }

    [Fact]
    public async Task GetAdminUserOverviewAndResetStreakAsync_ShouldExposeUserStateAndAllowReset()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();

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
            SortOrder = 1,
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync();

        var userService = new GamificationService(dbContext);
        await userService.ProcessGenerationCompletedAsync(
            userId,
            petId,
            templateId,
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var service = CreateAdminService(dbContext);

        var overview = await service.GetAdminUserOverviewAsync(userId, CancellationToken.None);
        var resetResult = await service.ResetAdminUserStreakAsync(userId, CancellationToken.None);

        Assert.True(overview.IsSuccess);
        Assert.Equal(userId, overview.Value.UserId);
        Assert.NotNull(overview.Value.Streak);
        Assert.Single(overview.Value.Pets);
        Assert.Single(overview.Value.Achievements, x => x.Key == "first_magic" && x.IsUnlocked);
        Assert.NotEmpty(overview.Value.CurrentChallenges);
        Assert.True(resetResult.IsSuccess);
        Assert.Null(await dbContext.DailyStreaks.FirstOrDefaultAsync(x => x.UserId == userId));
    }

    private static GamificationAdminService CreateAdminService(GamificationDbContext dbContext)
    {
        var userService = new GamificationService(dbContext);
        return new GamificationAdminService(dbContext, userService);
    }

    private static GamificationDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<GamificationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;

        return new GamificationDbContext(options);
    }

    private static DateOnly GetCurrentWeekStart()
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        return today.DayOfWeek == DayOfWeek.Sunday ? today.AddDays(-6) : startOfWeek;
    }
}
