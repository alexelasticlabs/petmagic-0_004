using System.Reflection;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Gamification.Domain.Constants;
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
        var generationId = Guid.NewGuid();

        await service.ProcessGenerationCompletedAsync(
            generationId,
            userId,
            petId,
            templateId,
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);
        await service.ProcessGenerationCompletedAsync(
            generationId,
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
        var generationId = Guid.NewGuid();

        await service.RecordCreationSharedAsync(generationId, userId, CancellationToken.None);
        await service.RecordCreationSharedAsync(generationId, userId, CancellationToken.None);

        var challenges = await service.GetCurrentChallengesAsync(userId, CancellationToken.None);

        Assert.Equal(1, challenges.Single(x => x.ChallengeType == "share_creations").CurrentValue);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldCountDistinctTemplatesForTryTemplatesChallenge()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();

        await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(), userId, petId, templateId, false, false, CancellationToken.None);
        await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(), userId, petId, templateId, false, false, CancellationToken.None);

        var challenges = await service.GetCurrentChallengesAsync(userId, CancellationToken.None);
        Assert.Equal(2, challenges.Single(x => x.ChallengeType == "generate_images").CurrentValue);
        Assert.Equal(1, challenges.Single(x => x.ChallengeType == "try_templates").CurrentValue);
    }

    [Fact]
    public async Task RetriedGamificationEvents_ShouldUseOriginalOccurrenceDayAndWeek()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var service = new GamificationService(dbContext);
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var templateId = Guid.NewGuid();
        var occurredAtUtc = DateTime.SpecifyKind(DateTime.UtcNow.Date.AddDays(-8).AddHours(12), DateTimeKind.Utc);

        var first = await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(), userId, petId, templateId, occurredAtUtc, false, false, CancellationToken.None);
        var second = await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(), userId, petId, templateId, occurredAtUtc.AddHours(1), false, false, CancellationToken.None);
        await service.RecordCreationSharedAsync(
            Guid.NewGuid(), userId, occurredAtUtc.AddHours(2), CancellationToken.None);

        Assert.Equal(XpThresholds.BaseXpPerGeneration + XpThresholds.BonusXpFirstOfDay, first.XpAwarded);
        Assert.Equal(XpThresholds.BaseXpPerGeneration, second.XpAwarded);
        var expectedWeekStart = occurredAtUtc.Date.AddDays(-(((int)occurredAtUtc.DayOfWeek + 6) % 7));
        var expectedWeek = DateOnly.FromDateTime(expectedWeekStart);
        Assert.All(await dbContext.GenerationEvents.ToListAsync(), x => Assert.Equal(expectedWeek, x.WeekStartDate));
        Assert.Equal(expectedWeek, (await dbContext.ShareEvents.SingleAsync()).WeekStartDate);
        Assert.Equal(occurredAtUtc.AddHours(1), (await dbContext.PetProgresses.SingleAsync()).LastGenerationAtUtc);
        Assert.Equal(
            1,
            await dbContext.UserChallengeProgresses
                .Join(
                    dbContext.WeeklyChallenges,
                    progress => progress.ChallengeId,
                    challenge => challenge.Id,
                    (progress, challenge) => new { progress, challenge })
                .Where(x => x.challenge.WeekStartDate == expectedWeek
                    && x.challenge.ChallengeType == "share_creations")
                .Select(x => x.progress.CurrentValue)
                .SingleAsync());
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
            Guid.NewGuid(),
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
    public async Task ProcessGenerationCompletedAsync_ShouldConfirmAchievementRewardWithStableIdempotencyKey()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        dbContext.AchievementDefinitions.Add(CreateAchievementDefinition());
        await dbContext.SaveChangesAsync();
        var userId = Guid.NewGuid();
        var economyService = RecordingEconomyServiceProxy.Create(succeed: true, out var economyProxy);
        var service = new GamificationService(dbContext, economyService);

        var result = await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            userId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var credit = Assert.Single(economyProxy.CreditCommands);
        Assert.Equal("achievement_reward", credit.Source);
        Assert.Equal("achievement:first_magic", credit.IdempotencyKey);
        Assert.Equal(10, result.TotalSparkReward);
        Assert.True(await dbContext.UserAchievements
            .Where(x => x.UserId == userId && x.AchievementKey == "first_magic")
            .Select(x => x.RewardCredited)
            .SingleAsync());
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldNotPersistRewardCredited_WhenWalletCreditFails()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        dbContext.AchievementDefinitions.Add(CreateAchievementDefinition());
        await dbContext.SaveChangesAsync();
        var economyService = RecordingEconomyServiceProxy.Create(succeed: false, out var economyProxy);
        var service = new GamificationService(dbContext, economyService);

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None));

        Assert.Equal("achievement:first_magic", Assert.Single(economyProxy.CreditCommands).IdempotencyKey);
        dbContext.ChangeTracker.Clear();
        Assert.Empty(await dbContext.UserAchievements.ToListAsync());
        Assert.Empty(await dbContext.PetProgresses.ToListAsync());
        Assert.Empty(await dbContext.DailyStreaks.ToListAsync());
        Assert.Empty(await dbContext.UserChallengeProgresses.ToListAsync());
    }

    [Fact]
    public async Task UseStreakFreezeAsync_ShouldConsumeSingleFreezeAtomically()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"petmagic-gamification-{Guid.NewGuid():N}.db");
        var connectionString = $"Data Source={databasePath};Default Timeout=10;Pooling=False";
        try
        {
            var options = new DbContextOptionsBuilder<GamificationDbContext>()
                .UseSqlite(connectionString)
                .Options;
            var userId = Guid.NewGuid();
            await using (var setup = new GamificationDbContext(options))
            {
                await setup.Database.EnsureCreatedAsync();
                setup.DailyStreaks.Add(new DailyStreak
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    CurrentStreak = 3,
                    LongestStreak = 3,
                    LastActiveDate = DateOnly.FromDateTime(DateTime.UtcNow).AddDays(-2),
                    StreakFreezesAvailable = 1,
                    CreatedAtUtc = DateTime.UtcNow,
                    UpdatedAtUtc = DateTime.UtcNow
                });
                await setup.SaveChangesAsync();
            }

            await using var firstContext = new GamificationDbContext(options);
            await using var secondContext = new GamificationDbContext(options);
            var firstService = new GamificationService(firstContext);
            var secondService = new GamificationService(secondContext);
            var start = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);

            var first = Task.Run(async () =>
            {
                await start.Task;
                return await firstService.UseStreakFreezeAsync(userId, CancellationToken.None);
            });
            var second = Task.Run(async () =>
            {
                await start.Task;
                return await secondService.UseStreakFreezeAsync(userId, CancellationToken.None);
            });
            start.SetResult(true);

            var results = await Task.WhenAll(first, second);

            Assert.Single(results, result => result.Success);
            Assert.All(results, result => Assert.Equal(0, result.FreezesRemaining));
            await using var verify = new GamificationDbContext(options);
            var streak = await verify.DailyStreaks.SingleAsync(x => x.UserId == userId);
            Assert.Equal(DateOnly.FromDateTime(DateTime.UtcNow).AddDays(-1), streak.LastActiveDate);
            Assert.Equal(4, streak.CurrentStreak);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }

    [Fact]
    public async Task UseStreakFreezeAsync_ShouldResetExpiredWeeklyAllowanceBeforeConsume()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var currentWeekStart = today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
        var userId = Guid.NewGuid();
        var streak = CreateStreak(userId, today.AddDays(-2), currentStreak: 4, freezes: 0);
        streak.FreezesResetAt = currentWeekStart.AddDays(-7);
        dbContext.DailyStreaks.Add(streak);
        await dbContext.SaveChangesAsync();
        var service = new GamificationService(dbContext);

        var result = await service.UseStreakFreezeAsync(userId, CancellationToken.None);

        Assert.True(result.Success);
        Assert.Equal(0, result.FreezesRemaining);
        Assert.Equal(currentWeekStart, streak.FreezesResetAt);
        Assert.Equal(today.AddDays(-1), streak.LastActiveDate);
        Assert.Equal(5, streak.CurrentStreak);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldUseOneFreezeForExactlyOneMissedDay()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var userId = Guid.NewGuid();
        dbContext.DailyStreaks.Add(CreateStreak(userId, today.AddDays(-2), currentStreak: 3, freezes: 1));
        await dbContext.SaveChangesAsync();
        var service = new GamificationService(dbContext);

        await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            userId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var streak = await service.GetStreakAsync(userId, CancellationToken.None);
        Assert.NotNull(streak);
        Assert.Equal(5, streak.CurrentStreak);
        Assert.Equal(0, streak.FreezesAvailable);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldResetStreakAfterMultipleMissedDays()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var userId = Guid.NewGuid();
        dbContext.DailyStreaks.Add(CreateStreak(userId, today.AddDays(-3), currentStreak: 8, freezes: 1));
        await dbContext.SaveChangesAsync();
        var service = new GamificationService(dbContext);

        await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            userId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var streak = await service.GetStreakAsync(userId, CancellationToken.None);
        Assert.NotNull(streak);
        Assert.Equal(1, streak.CurrentStreak);
        Assert.Equal(1, streak.FreezesAvailable);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldResetFreezeAllowanceOnFirstActivityOfNewWeek()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var currentWeekStart = today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
        var userId = Guid.NewGuid();
        var streak = CreateStreak(userId, today.AddDays(-1), currentStreak: 4, freezes: 0);
        streak.FreezesResetAt = currentWeekStart.AddDays(-7);
        dbContext.DailyStreaks.Add(streak);
        await dbContext.SaveChangesAsync();
        var service = new GamificationService(dbContext);

        await service.ProcessGenerationCompletedAsync(
            Guid.NewGuid(),
            userId,
            Guid.NewGuid(),
            Guid.NewGuid(),
            isTemplateOfTheDay: false,
            isPremium: false,
            CancellationToken.None);

        var response = await service.GetStreakAsync(userId, CancellationToken.None);
        Assert.NotNull(response);
        Assert.Equal(1, response.FreezesAvailable);
        Assert.Equal(1, response.FreezesPerWeek);
    }

    [Fact]
    public async Task ProcessGenerationCompletedAsync_ShouldCreditCompletedChallengesIdempotently()
    {
        await using var dbContext = CreateDbContext();
        await dbContext.Database.EnsureCreatedAsync();
        var userId = Guid.NewGuid();
        var petId = Guid.NewGuid();
        var economyService = RecordingEconomyServiceProxy.Create(succeed: true, out var economyProxy);
        var service = new GamificationService(dbContext, economyService);

        for (var i = 0; i < 5; i++)
        {
            await service.ProcessGenerationCompletedAsync(
                Guid.NewGuid(),
                userId,
                petId,
                Guid.NewGuid(),
                isTemplateOfTheDay: false,
                isPremium: false,
                CancellationToken.None);
        }

        var challengeCredits = economyProxy.CreditCommands
            .Where(x => x.Source == "challenge_reward")
            .ToList();
        Assert.Equal(2, challengeCredits.Count);
        Assert.All(challengeCredits, x =>
            Assert.StartsWith("challenge:", Assert.IsType<string>(x.IdempotencyKey)));
        Assert.Equal(45, challengeCredits.Sum(x => x.Amount));
        var challenges = await service.GetCurrentChallengesAsync(userId, CancellationToken.None);
        Assert.True(challenges.Single(x => x.ChallengeType == "generate_images").RewardClaimed);
        Assert.True(challenges.Single(x => x.ChallengeType == "try_templates").RewardClaimed);
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

    private static AchievementDefinition CreateAchievementDefinition() => new()
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
    };

    private static DailyStreak CreateStreak(
        Guid userId,
        DateOnly lastActiveDate,
        int currentStreak,
        int freezes) => new()
    {
        Id = Guid.NewGuid(),
        UserId = userId,
        CurrentStreak = currentStreak,
        LongestStreak = currentStreak,
        LastActiveDate = lastActiveDate,
        StreakFreezesAvailable = freezes,
        WeeklyFreezeAllowance = 1,
        FreezesResetAt = lastActiveDate.AddDays(-(((int)lastActiveDate.DayOfWeek + 6) % 7)),
        CreatedAtUtc = DateTime.UtcNow.AddDays(-currentStreak),
        UpdatedAtUtc = DateTime.UtcNow
    };

    private class RecordingEconomyServiceProxy : DispatchProxy
    {
        private bool succeed;

        public List<CreditBalanceCommand> CreditCommands { get; } = [];

        public static IEconomyService Create(bool succeed, out RecordingEconomyServiceProxy proxy)
        {
            var service = Create<IEconomyService, RecordingEconomyServiceProxy>();
            proxy = (RecordingEconomyServiceProxy)(object)service;
            proxy.succeed = succeed;
            return service;
        }

        protected override object Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            if (targetMethod?.Name == nameof(IEconomyService.CreditAsync)
                && args is [CreditBalanceCommand command, CancellationToken])
            {
                CreditCommands.Add(command);
                return Task.FromResult(succeed
                    ? Result.Success(new WalletOperationResponse(
                        command.UserId,
                        command.Amount,
                        command.Amount,
                        command.Source,
                        DateTime.UtcNow,
                        null,
                        0))
                    : Result.Failure<WalletOperationResponse>(new Error("economy.credit_failed", "credit failed")));
            }

            throw new NotSupportedException(
                $"Unexpected IEconomyService call in gamification test proxy: {targetMethod?.Name ?? "<unknown>"}");
        }
    }
}
