using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;
using PetMagic.Modules.Gamification.Domain.Constants;
using PetMagic.Modules.Gamification.Domain.Enums;
using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;

namespace PetMagic.Modules.Gamification.Infrastructure.Services;

public sealed class GamificationService(
    GamificationDbContext dbContext,
    IEconomyService? economyService = null) : IGamificationService
{
    public async Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid userId,
        Guid petId,
        Guid templateId,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var today = DateOnly.FromDateTime(now);

        var progress = await dbContext.PetProgresses
            .FirstOrDefaultAsync(x => x.UserId == userId && x.PetId == petId, cancellationToken);

        if (progress is null)
        {
            progress = new PetProgress
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                PetId = petId,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };
            dbContext.PetProgresses.Add(progress);
        }

        var isFirstOfDay = progress.LastGenerationAtUtc is null
            || DateOnly.FromDateTime(progress.LastGenerationAtUtc.Value) < today;

        var xpAwarded = XpThresholds.BaseXpPerGeneration;
        if (isTemplateOfTheDay)
        {
            xpAwarded += XpThresholds.BonusXpTemplateOfTheDay;
        }

        if (isFirstOfDay)
        {
            xpAwarded += XpThresholds.BonusXpFirstOfDay;
        }

        var previousLevel = progress.Level;
        progress.Xp += xpAwarded;
        progress.TotalGenerations += 1;
        progress.FavoriteTemplateId = templateId;
        progress.FirstGenerationAtUtc ??= now;
        progress.LastGenerationAtUtc = now;
        progress.Level = XpThresholds.GetLevel(progress.Xp);
        progress.EvolutionStage = EvolutionStage.FromLevel(progress.Level);
        progress.UpdatedAtUtc = now;

        var didLevelUp = progress.Level > previousLevel;
        string? newEvolutionStage = didLevelUp && EvolutionStage.FromLevel(progress.Level) != EvolutionStage.FromLevel(previousLevel)
            ? progress.EvolutionStage
            : null;

        await UpdateDailyStreakAsync(userId, today, isPremium, cancellationToken);
        await UpdateChallengeProgressAsync(userId, "generate_images", 1, cancellationToken);
        await UpdateChallengeProgressAsync(userId, "try_templates", 1, cancellationToken);

        var unlockedAchievements = await EvaluateAchievementsAsync(userId, cancellationToken);

        var totalSparkReward = 0;
        var unlockedAchievementResponses = new List<AchievementResponse>();
        if (unlockedAchievements.Count > 0)
        {
            var unlockedKeys = unlockedAchievements
                .Select(a => NormalizeAchievementKey(a.AchievementKey))
                .Where(key => key.Length > 0)
                .ToHashSet(StringComparer.Ordinal);
            var definitions = unlockedKeys.Count == 0
                ? new Dictionary<string, AchievementDefinition>(StringComparer.Ordinal)
                : (await dbContext.AchievementDefinitions
                        .Where(d => d.Key != null && d.Key != string.Empty && unlockedKeys.Contains(d.Key))
                        .ToListAsync(cancellationToken))
                    .Select(def => new
                    {
                        Definition = def,
                        Key = NormalizeAchievementKey(def.Key)
                    })
                    .Where(x => x.Key.Length > 0)
                    .GroupBy(x => x.Key, StringComparer.Ordinal)
                    .ToDictionary(x => x.Key, x => x.First().Definition, StringComparer.Ordinal);

            foreach (var achievement in unlockedAchievements.Where(a => !a.RewardCredited))
            {
                var normalizedAchievementKey = NormalizeAchievementKey(achievement.AchievementKey);
                if (normalizedAchievementKey.Length > 0 && definitions.TryGetValue(normalizedAchievementKey, out var def))
                {
                    totalSparkReward += def.RewardSpark;
                    unlockedAchievementResponses.Add(new AchievementResponse(
                        normalizedAchievementKey,
                        def.Category ?? "special",
                        def.Rarity ?? "common",
                        def.TitleKey ?? string.Empty,
                        def.DescriptionKey ?? string.Empty,
                        def.IconEmoji,
                        def.RequirementValue,
                        def.RequirementValue,
                        def.RewardSpark,
                        def.IsSecret,
                        true,
                        achievement.UnlockedAtUtc));
                }
                achievement.RewardCredited = true;
            }

            if (totalSparkReward > 0 && economyService is not null)
            {
                await economyService.CreditAsync(
                    new CreditBalanceCommand(userId, totalSparkReward, "achievement_reward", "Achievement unlock reward"),
                    cancellationToken);
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);

        return new GenerationProcessResult(
            xpAwarded,
            didLevelUp ? progress.Level : null,
            newEvolutionStage,
            didLevelUp,
            unlockedAchievementResponses,
            totalSparkReward);
    }

    public async Task<PetProgressResponse?> GetPetProgressAsync(Guid userId, Guid petId, CancellationToken cancellationToken)
    {
        var progress = await dbContext.PetProgresses
            .FirstOrDefaultAsync(x => x.UserId == userId && x.PetId == petId, cancellationToken);

        if (progress is null)
        {
            return null;
        }

        var daysActive = progress.FirstGenerationAtUtc.HasValue
            ? (int)(DateTime.UtcNow - progress.FirstGenerationAtUtc.Value).TotalDays + 1
            : 0;

        return new PetProgressResponse(
            progress.PetId,
            progress.Xp,
            progress.Level,
            progress.EvolutionStage ?? "egg",
            progress.TotalGenerations,
            XpThresholds.GetXpForNextLevel(progress.Level),
            XpThresholds.GetXpForCurrentLevel(progress.Level),
            daysActive,
            progress.FavoriteTemplateId,
            progress.LastGenerationAtUtc);
    }

    public async Task<IReadOnlyList<AchievementResponse>> GetAchievementsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var definitions = await dbContext.AchievementDefinitions
            .OrderBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

        var userAchievements = (await dbContext.UserAchievements
                .Where(x => x.UserId == userId)
                .ToListAsync(cancellationToken))
            .Select(achievement => new
            {
                Achievement = achievement,
                Key = NormalizeAchievementKey(achievement.AchievementKey)
            })
            .Where(x => x.Key.Length > 0)
            .GroupBy(x => x.Key, StringComparer.Ordinal)
            .ToDictionary(
                x => x.Key,
                x => x.OrderByDescending(item => item.Achievement.UnlockedAtUtc).First().Achievement,
                StringComparer.Ordinal);

        var userProgress = await GetUserProgressCountersAsync(userId, cancellationToken);

        return definitions.Select(def =>
        {
            var normalizedKey = NormalizeAchievementKey(def.Key);
            userAchievements.TryGetValue(normalizedKey, out var earned);
            var currentProgress = CalculateProgress(def.RequirementType, userProgress);

            return new AchievementResponse(
                normalizedKey,
                def.Category ?? "special",
                def.Rarity ?? "common",
                def.TitleKey ?? string.Empty,
                def.DescriptionKey ?? string.Empty,
                def.IconEmoji,
                def.RequirementValue,
                Math.Min(currentProgress, def.RequirementValue),
                def.RewardSpark,
                def.IsSecret,
                earned is not null,
                earned?.UnlockedAtUtc);
        }).ToList();
    }

    public async Task<IReadOnlyList<AchievementResponse>> GetRecentAchievementsAsync(Guid userId, int count, CancellationToken cancellationToken)
    {
        var recent = await dbContext.UserAchievements
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.UnlockedAtUtc)
            .Take(count)
            .ToListAsync(cancellationToken);

        var keys = recent
            .Select(x => NormalizeAchievementKey(x.AchievementKey))
            .Where(key => key.Length > 0)
            .ToHashSet(StringComparer.Ordinal);
        var definitions = keys.Count == 0
            ? new Dictionary<string, AchievementDefinition>(StringComparer.Ordinal)
            : (await dbContext.AchievementDefinitions
                    .Where(x => x.Key != null && x.Key != string.Empty && keys.Contains(x.Key))
                    .ToListAsync(cancellationToken))
                .Select(def => new
                {
                    Definition = def,
                    Key = NormalizeAchievementKey(def.Key)
                })
                .Where(x => x.Key.Length > 0)
                .GroupBy(x => x.Key, StringComparer.Ordinal)
                .ToDictionary(x => x.Key, x => x.First().Definition, StringComparer.Ordinal);

        return recent.Select(earned =>
        {
            var normalizedKey = NormalizeAchievementKey(earned.AchievementKey);
            definitions.TryGetValue(normalizedKey, out var def);
            return new AchievementResponse(
                normalizedKey,
                def?.Category ?? "special",
                def?.Rarity ?? "common",
                def?.TitleKey ?? normalizedKey,
                def?.DescriptionKey ?? string.Empty,
                def?.IconEmoji,
                def?.RequirementValue ?? 0,
                def?.RequirementValue ?? 0,
                def?.RewardSpark ?? 0,
                def?.IsSecret ?? false,
                true,
                earned.UnlockedAtUtc);
        }).ToList();
    }

    public async Task<StreakResponse?> GetStreakAsync(Guid userId, CancellationToken cancellationToken)
    {
        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (streak is null)
        {
            return null;
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        if (today.DayOfWeek == DayOfWeek.Sunday)
        {
            startOfWeek = today.AddDays(-6);
        }

        var activeDays = await dbContext.DailyStreaks
            .Where(x => x.UserId == userId)
            .Select(x => x.LastActiveDate)
            .ToListAsync(cancellationToken);

        var activeDaysThisWeek = new List<DateOnly>();
        if (streak.CurrentStreak > 0)
        {
            for (var d = 0; d < 7; d++)
            {
                var date = startOfWeek.AddDays(d);
                if (date <= today && date >= today.AddDays(-streak.CurrentStreak + 1))
                {
                    activeDaysThisWeek.Add(date);
                }
            }
        }

        return new StreakResponse(
            streak.CurrentStreak,
            streak.LongestStreak,
            streak.StreakFreezesAvailable,
            streak.FreezesResetAt.HasValue ? 2 : 1,
            streak.LastActiveDate,
            activeDaysThisWeek);
    }

    public async Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken)
    {
        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (streak is null || streak.StreakFreezesAvailable <= 0)
        {
            return new UseFreezeResult(false, streak?.StreakFreezesAvailable ?? 0);
        }

        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        streak.StreakFreezesAvailable -= 1;
        streak.StreakFreezeUsedAt = today;
        streak.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);

        return new UseFreezeResult(true, streak.StreakFreezesAvailable);
    }

    public async Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);

        var challenges = await dbContext.WeeklyChallenges
            .Where(x => x.WeekStartDate == startOfWeek)
            .OrderBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

        if (challenges.Count == 0)
        {
            await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(dbContext, startOfWeek, cancellationToken);
            challenges = await dbContext.WeeklyChallenges
                .Where(x => x.WeekStartDate == startOfWeek)
                .OrderBy(x => x.SortOrder)
                .ToListAsync(cancellationToken);
        }

        var challengeIds = challenges.Select(x => x.Id).ToHashSet();
        var progressMap = await dbContext.UserChallengeProgresses
            .Where(x => x.UserId == userId && challengeIds.Contains(x.ChallengeId))
            .ToDictionaryAsync(x => x.ChallengeId, cancellationToken);

        return challenges.Select(c =>
        {
            progressMap.TryGetValue(c.Id, out var progress);
            return new ChallengeResponse(
                c.Id,
                c.ChallengeType ?? string.Empty,
                c.TargetValue,
                progress?.CurrentValue ?? 0,
                c.TitleKey ?? string.Empty,
                c.DescriptionKey ?? string.Empty,
                c.IconEmoji,
                c.RewardSpark,
                progress?.Completed ?? false,
                progress?.RewardCredited ?? false);
        }).ToList();
    }

    public async Task<GamificationSummaryResponse> GetSummaryAsync(Guid userId, CancellationToken cancellationToken)
    {
        var streak = await GetStreakAsync(userId, cancellationToken);
        var recentAchievements = await GetRecentAchievementsAsync(userId, 5, cancellationToken);
        var challenges = await GetCurrentChallengesAsync(userId, cancellationToken);

        var topPets = await dbContext.PetProgresses
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.Level)
            .ThenByDescending(x => x.Xp)
            .Take(3)
            .ToListAsync(cancellationToken);

        return new GamificationSummaryResponse(
            streak,
            recentAchievements,
            challenges,
            topPets.Select(p => new PetProgressResponse(
                p.PetId, p.Xp, p.Level, p.EvolutionStage ?? "egg", p.TotalGenerations,
                XpThresholds.GetXpForNextLevel(p.Level),
                XpThresholds.GetXpForCurrentLevel(p.Level),
                p.FirstGenerationAtUtc.HasValue ? (int)(DateTime.UtcNow - p.FirstGenerationAtUtc.Value).TotalDays + 1 : 0,
                p.FavoriteTemplateId, p.LastGenerationAtUtc)).ToList());
    }

    public async Task RecordCreationSharedAsync(Guid userId, CancellationToken cancellationToken)
    {
        await UpdateChallengeProgressAsync(userId, "share_creations", 1, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task UpdateDailyStreakAsync(Guid userId, DateOnly today, bool isPremium, CancellationToken cancellationToken)
    {
        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (streak is null)
        {
            streak = new DailyStreak
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                CurrentStreak = 1,
                LongestStreak = 1,
                LastActiveDate = today,
                StreakFreezesAvailable = isPremium ? 2 : 1,
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            };
            dbContext.DailyStreaks.Add(streak);
            return;
        }

        if (streak.LastActiveDate == today)
        {
            return;
        }

        var expectedPrevious = today.AddDays(-1);
        if (streak.LastActiveDate == expectedPrevious)
        {
            streak.CurrentStreak += 1;
        }
        else if (streak.StreakFreezesAvailable > 0)
        {
            streak.StreakFreezesAvailable -= 1;
            streak.CurrentStreak += 1;
            streak.StreakFreezeUsedAt = today;
        }
        else
        {
            streak.CurrentStreak = 1;
        }

        if (streak.CurrentStreak > streak.LongestStreak)
        {
            streak.LongestStreak = streak.CurrentStreak;
        }

        streak.LastActiveDate = today;
        streak.UpdatedAtUtc = DateTime.UtcNow;

        ResetWeeklyFreezesIfNeeded(streak, today, isPremium);
    }

    private static void ResetWeeklyFreezesIfNeeded(DailyStreak streak, DateOnly today, bool isPremium)
    {
        if (streak.FreezesResetAt.HasValue)
        {
            var daysSinceReset = today.DayNumber - streak.FreezesResetAt.Value.DayNumber;
            if (daysSinceReset < 7)
            {
                return;
            }
        }

        if (today.DayOfWeek == DayOfWeek.Monday)
        {
            streak.StreakFreezesAvailable = isPremium ? 2 : 1;
            streak.FreezesResetAt = today;
        }
    }

    private async Task UpdateChallengeProgressAsync(Guid userId, string challengeType, int increment, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);

        var challenge = await dbContext.WeeklyChallenges
            .FirstOrDefaultAsync(x => x.WeekStartDate == startOfWeek && x.ChallengeType == challengeType, cancellationToken);

        if (challenge is null)
        {
            await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(dbContext, startOfWeek, cancellationToken);
            challenge = await dbContext.WeeklyChallenges
                .FirstOrDefaultAsync(x => x.WeekStartDate == startOfWeek && x.ChallengeType == challengeType, cancellationToken);

            if (challenge is null)
            {
                return;
            }
        }

        var progress = await dbContext.UserChallengeProgresses
            .FirstOrDefaultAsync(x => x.UserId == userId && x.ChallengeId == challenge.Id, cancellationToken);

        if (progress is null)
        {
            progress = new UserChallengeProgress
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                ChallengeId = challenge.Id
            };
            dbContext.UserChallengeProgresses.Add(progress);
        }

        if (progress.Completed)
        {
            return;
        }

        progress.CurrentValue += increment;
        if (progress.CurrentValue >= challenge.TargetValue)
        {
            progress.Completed = true;
            progress.CompletedAtUtc = DateTime.UtcNow;
        }
    }

    private async Task<List<UserAchievement>> EvaluateAchievementsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var definitions = await dbContext.AchievementDefinitions.ToListAsync(cancellationToken);
        var existingKeys = (await dbContext.UserAchievements
                .Where(x => x.UserId == userId)
                .Select(x => x.AchievementKey)
                .ToListAsync(cancellationToken))
            .Select(NormalizeAchievementKey)
            .Where(key => key.Length > 0)
            .ToHashSet(StringComparer.Ordinal);

        var userProgress = await GetUserProgressCountersAsync(userId, cancellationToken);
        var newlyUnlocked = new List<UserAchievement>();
        var now = DateTime.UtcNow;

        foreach (var def in definitions)
        {
            var normalizedKey = NormalizeAchievementKey(def.Key);
            if (normalizedKey.Length == 0 || existingKeys.Contains(normalizedKey))
            {
                continue;
            }

            var currentValue = CalculateProgress(def.RequirementType, userProgress);
            if (currentValue >= def.RequirementValue)
            {
                var achievement = new UserAchievement
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    AchievementKey = normalizedKey,
                    UnlockedAtUtc = now
                };
                dbContext.UserAchievements.Add(achievement);
                newlyUnlocked.Add(achievement);
            }
        }

        return newlyUnlocked;
    }

    private async Task<UserProgressCounters> GetUserProgressCountersAsync(Guid userId, CancellationToken cancellationToken)
    {
        var totalGenerations = await dbContext.PetProgresses
            .Where(x => x.UserId == userId)
            .SumAsync(x => x.TotalGenerations, cancellationToken);

        var petCount = await dbContext.PetProgresses
            .CountAsync(x => x.UserId == userId, cancellationToken);

        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        var maxEvolutionStage = await dbContext.PetProgresses
            .Where(x => x.UserId == userId)
            .Select(x => (int?)x.Level)
            .MaxAsync(cancellationToken) ?? 0;

        return new UserProgressCounters
        {
            TotalGenerations = totalGenerations,
            PetCount = petCount,
            StreakDays = streak?.CurrentStreak ?? 0,
            MaxPetLevel = maxEvolutionStage
        };
    }

    private static int CalculateProgress(string requirementType, UserProgressCounters counters) => requirementType switch
    {
        "generation_count" => counters.TotalGenerations,
        "streak_days" => counters.StreakDays,
        "pet_count" => counters.PetCount,
        "pet_level" => counters.MaxPetLevel,
        _ => 0
    };

    private static string NormalizeAchievementKey(string? value) => value?.Trim() ?? string.Empty;

    private sealed class UserProgressCounters
    {
        public int TotalGenerations { get; set; }
        public int PetCount { get; set; }
        public int StreakDays { get; set; }
        public int MaxPetLevel { get; set; }
    }
}
