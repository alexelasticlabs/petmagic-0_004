using System.Data;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

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
    public Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid generationId,
        Guid userId,
        Guid petId,
        Guid templateId,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken) => ProcessGenerationCompletedAsync(
            generationId,
            userId,
            petId,
            templateId,
            DateTime.UtcNow,
            isTemplateOfTheDay,
            isPremium,
            cancellationToken);

    public async Task<GenerationProcessResult> ProcessGenerationCompletedAsync(
        Guid generationId,
        Guid userId,
        Guid petId,
        Guid templateId,
        DateTime completedAtUtc,
        bool isTemplateOfTheDay,
        bool isPremium,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var occurredAtUtc = NormalizeUtcTimestamp(completedAtUtc);
        var today = DateOnly.FromDateTime(occurredAtUtc);
        var weekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);
        var dayStartUtc = DateTime.SpecifyKind(today.ToDateTime(TimeOnly.MinValue), DateTimeKind.Utc);
        var nextDayStartUtc = dayStartUtc.AddDays(1);
        await using var transaction = await BeginUserMutationTransactionAsync(userId, cancellationToken);
        if (await dbContext.GenerationEvents
            .AsNoTracking()
            .AnyAsync(x => x.GenerationId == generationId, cancellationToken))
        {
            return new GenerationProcessResult(0, null, null, false, [], 0);
        }

        var isFirstUseOfTemplateThisWeek = !await dbContext.GenerationEvents
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == userId
                    && x.WeekStartDate == weekStart
                    && x.TemplateId == templateId,
                cancellationToken);
        var isFirstOfDay = !await dbContext.GenerationEvents
            .AsNoTracking()
            .AnyAsync(
                x => x.UserId == userId
                    && x.PetId == petId
                    && x.OccurredAtUtc >= dayStartUtc
                    && x.OccurredAtUtc < nextDayStartUtc,
                cancellationToken);
        dbContext.GenerationEvents.Add(new GamificationGenerationEvent
        {
            GenerationId = generationId,
            UserId = userId,
            PetId = petId,
            TemplateId = templateId,
            WeekStartDate = weekStart,
            OccurredAtUtc = occurredAtUtc,
            ProcessedAtUtc = now
        });

        var progress = await dbContext.PetProgresses
            .FirstOrDefaultAsync(x => x.UserId == userId && x.PetId == petId, cancellationToken);

        if (progress is null)
        {
            progress = new PetProgress
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                PetId = petId,
                CreatedAtUtc = occurredAtUtc,
                UpdatedAtUtc = now
            };
            dbContext.PetProgresses.Add(progress);
        }

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
        if (progress.FirstGenerationAtUtc is null || occurredAtUtc < progress.FirstGenerationAtUtc.Value)
        {
            progress.FirstGenerationAtUtc = occurredAtUtc;
        }

        if (progress.LastGenerationAtUtc is null || occurredAtUtc >= progress.LastGenerationAtUtc.Value)
        {
            progress.FavoriteTemplateId = templateId;
            progress.LastGenerationAtUtc = occurredAtUtc;
        }
        progress.Level = XpThresholds.GetLevel(progress.Xp);
        progress.EvolutionStage = EvolutionStage.FromLevel(progress.Level);
        progress.UpdatedAtUtc = now;

        var didLevelUp = progress.Level > previousLevel;
        string? newEvolutionStage = didLevelUp && EvolutionStage.FromLevel(progress.Level) != EvolutionStage.FromLevel(previousLevel)
            ? progress.EvolutionStage
            : null;

        await UpdateDailyStreakAsync(userId, today, isPremium, cancellationToken);
        await UpdateChallengeProgressAsync(userId, "generate_images", 1, weekStart, occurredAtUtc, cancellationToken);
        if (isFirstUseOfTemplateThisWeek)
        {
            await UpdateChallengeProgressAsync(userId, "try_templates", 1, weekStart, occurredAtUtc, cancellationToken);
        }

        var unlockedAchievements = await EvaluateAchievementsAsync(userId, cancellationToken);

        var totalSparkReward = 0;
        var unlockedAchievementResponses = new List<AchievementResponse>();
        var persistedPendingRewards = await dbContext.UserAchievements
            .Where(x => x.UserId == userId && !x.RewardCredited)
            .ToListAsync(cancellationToken);
        var pendingRewardAchievements = persistedPendingRewards
            .Concat(unlockedAchievements)
            .DistinctBy(x => x.Id)
            .ToList();

        if (pendingRewardAchievements.Count > 0 || unlockedAchievements.Count > 0)
        {
            var rewardKeys = pendingRewardAchievements
                .Select(a => NormalizeAchievementKey(a.AchievementKey))
                .Where(key => key.Length > 0)
                .ToHashSet(StringComparer.Ordinal);
            var definitions = rewardKeys.Count == 0
                ? new Dictionary<string, AchievementDefinition>(StringComparer.Ordinal)
                : (await dbContext.AchievementDefinitions
                        .Where(d => d.Key != null && d.Key != string.Empty && rewardKeys.Contains(d.Key))
                        .ToListAsync(cancellationToken))
                    .Select(def => new
                    {
                        Definition = def,
                        Key = NormalizeAchievementKey(def.Key)
                    })
                    .Where(x => x.Key.Length > 0)
                    .GroupBy(x => x.Key, StringComparer.Ordinal)
                    .ToDictionary(x => x.Key, x => x.First().Definition, StringComparer.Ordinal);

            foreach (var achievement in pendingRewardAchievements.Where(a => !a.RewardCredited))
            {
                var normalizedAchievementKey = NormalizeAchievementKey(achievement.AchievementKey);
                if (normalizedAchievementKey.Length > 0 && definitions.TryGetValue(normalizedAchievementKey, out var def))
                {
                    if (def.RewardSpark <= 0)
                    {
                        achievement.RewardCredited = true;
                        continue;
                    }

                    if (economyService is null)
                    {
                        continue;
                    }

                    var creditResult = await economyService.CreditAsync(
                        new CreditBalanceCommand(
                            userId,
                            def.RewardSpark,
                            "achievement_reward",
                            "Achievement unlock reward",
                            IdempotencyKey: $"achievement:{normalizedAchievementKey}"),
                        cancellationToken);
                    if (creditResult.IsFailure)
                    {
                        throw new InvalidOperationException("Achievement reward credit could not be confirmed.");
                    }

                    totalSparkReward += def.RewardSpark;
                    achievement.RewardCredited = true;
                }
            }

            foreach (var achievement in unlockedAchievements)
            {
                var normalizedAchievementKey = NormalizeAchievementKey(achievement.AchievementKey);
                if (normalizedAchievementKey.Length == 0
                    || !definitions.TryGetValue(normalizedAchievementKey, out var def))
                {
                    continue;
                }

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
        }

        totalSparkReward += await CreditPendingChallengeRewardsAsync(userId, cancellationToken);

        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

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

        var freezesPerWeek = await ResolveWeeklyFreezeAllowanceAsync(
            userId,
            streak.WeeklyFreezeAllowance,
            cancellationToken);

        return new StreakResponse(
            streak.CurrentStreak,
            streak.LongestStreak,
            streak.StreakFreezesAvailable,
            freezesPerWeek,
            streak.LastActiveDate,
            activeDaysThisWeek);
    }

    public async Task<UseFreezeResult> UseStreakFreezeAsync(Guid userId, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var now = DateTime.UtcNow;
        var expectedLastActiveDate = today.AddDays(-2);
        var virtualActiveDate = today.AddDays(-1);
        var currentWeekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);
        var existingAllowance = await dbContext.DailyStreaks
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .Select(x => (int?)x.WeeklyFreezeAllowance)
            .SingleOrDefaultAsync(cancellationToken) ?? 1;
        var weeklyAllowance = await ResolveWeeklyFreezeAllowanceAsync(
            userId,
            existingAllowance,
            cancellationToken);
        if (dbContext.Database.IsRelational())
        {
            var updated = await dbContext.DailyStreaks
                .Where(x => x.UserId == userId
                    && x.LastActiveDate == expectedLastActiveDate
                    && ((x.FreezesResetAt == null || x.FreezesResetAt < currentWeekStart)
                        || x.StreakFreezesAvailable > 0))
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(
                            x => x.StreakFreezesAvailable,
                            x => x.FreezesResetAt == null || x.FreezesResetAt < currentWeekStart
                                ? weeklyAllowance - 1
                                : x.StreakFreezesAvailable - 1)
                        .SetProperty(
                            x => x.WeeklyFreezeAllowance,
                            x => x.FreezesResetAt == null || x.FreezesResetAt < currentWeekStart
                                ? weeklyAllowance
                                : x.WeeklyFreezeAllowance)
                        .SetProperty(
                            x => x.FreezesResetAt,
                            x => x.FreezesResetAt == null || x.FreezesResetAt < currentWeekStart
                                ? currentWeekStart
                                : x.FreezesResetAt)
                        .SetProperty(x => x.CurrentStreak, x => x.CurrentStreak + 1)
                        .SetProperty(
                            x => x.LongestStreak,
                            x => x.CurrentStreak + 1 > x.LongestStreak
                                ? x.CurrentStreak + 1
                                : x.LongestStreak)
                        .SetProperty(x => x.LastActiveDate, virtualActiveDate)
                        .SetProperty(x => x.StreakFreezeUsedAt, today)
                        .SetProperty(x => x.UpdatedAtUtc, now),
                    cancellationToken);
            var freezesRemaining = await dbContext.DailyStreaks
                .AsNoTracking()
                .Where(x => x.UserId == userId)
                .Select(x => (int?)x.StreakFreezesAvailable)
                .SingleOrDefaultAsync(cancellationToken) ?? 0;

            return new UseFreezeResult(updated == 1, freezesRemaining);
        }

        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (streak is not null)
        {
            ResetWeeklyFreezesIfNeeded(streak, today, weeklyAllowance > 1);
        }

        if (streak is null
            || streak.StreakFreezesAvailable <= 0
            || streak.LastActiveDate != expectedLastActiveDate)
        {
            return new UseFreezeResult(false, streak?.StreakFreezesAvailable ?? 0);
        }

        streak.StreakFreezesAvailable -= 1;
        streak.CurrentStreak += 1;
        streak.LongestStreak = Math.Max(streak.LongestStreak, streak.CurrentStreak);
        streak.LastActiveDate = virtualActiveDate;
        streak.StreakFreezeUsedAt = today;
        streak.UpdatedAtUtc = now;

        await dbContext.SaveChangesAsync(cancellationToken);

        return new UseFreezeResult(true, streak.StreakFreezesAvailable);
    }

    private async Task<int> ResolveWeeklyFreezeAllowanceAsync(
        Guid userId,
        int fallbackAllowance,
        CancellationToken cancellationToken)
    {
        if (economyService is not null)
        {
            var summary = await economyService.GetSubscriptionSummaryAsync(
                userId,
                cancellationToken);
            if (summary.IsSuccess)
            {
                return summary.Value.IsPremium ? 2 : 1;
            }
        }

        return Math.Clamp(fallbackAllowance, 1, 2);
    }

    public async Task<IReadOnlyList<ChallengeResponse>> GetCurrentChallengesAsync(Guid userId, CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var startOfWeek = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);

        await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(
            dbContext,
            startOfWeek,
            cancellationToken);

        var challenges = await dbContext.WeeklyChallenges
            .Where(x => x.WeekStartDate == startOfWeek)
            .OrderBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

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

    public Task RecordCreationSharedAsync(
        Guid generationId,
        Guid userId,
        CancellationToken cancellationToken) => RecordCreationSharedAsync(
            generationId,
            userId,
            DateTime.UtcNow,
            cancellationToken);

    public async Task RecordCreationSharedAsync(
        Guid generationId,
        Guid userId,
        DateTime sharedAtUtc,
        CancellationToken cancellationToken)
    {
        var occurredAtUtc = NormalizeUtcTimestamp(sharedAtUtc);
        var today = DateOnly.FromDateTime(occurredAtUtc);
        var weekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);
        await using var transaction = await BeginUserMutationTransactionAsync(userId, cancellationToken);
        if (await dbContext.ShareEvents
            .AsNoTracking()
            .AnyAsync(x => x.GenerationId == generationId, cancellationToken))
        {
            return;
        }

        dbContext.ShareEvents.Add(new GamificationShareEvent
        {
            GenerationId = generationId,
            UserId = userId,
            WeekStartDate = weekStart,
            SharedAtUtc = occurredAtUtc
        });
        await UpdateChallengeProgressAsync(
            userId,
            "share_creations",
            1,
            weekStart,
            occurredAtUtc,
            cancellationToken);
        await CreditPendingChallengeRewardsAsync(userId, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }
    }

    private async Task<IDbContextTransaction?> BeginUserMutationTransactionAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (!dbContext.Database.IsRelational())
        {
            return null;
        }

        var isPostgres = string.Equals(
            dbContext.Database.ProviderName,
            "Npgsql.EntityFrameworkCore.PostgreSQL",
            StringComparison.Ordinal);
        var transaction = await dbContext.Database.BeginTransactionAsync(
            isPostgres ? IsolationLevel.ReadCommitted : IsolationLevel.Serializable,
            cancellationToken);
        if (isPostgres)
        {
            var lockKey = BitConverter.ToInt64(userId.ToByteArray(), 0);
            await dbContext.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({lockKey})",
                cancellationToken);
        }

        return transaction;
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
                WeeklyFreezeAllowance = isPremium ? 2 : 1,
                FreezesResetAt = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today),
                CreatedAtUtc = DateTime.UtcNow,
                UpdatedAtUtc = DateTime.UtcNow
            };
            dbContext.DailyStreaks.Add(streak);
            return;
        }

        if (today < streak.LastActiveDate)
        {
            return;
        }

        ResetWeeklyFreezesIfNeeded(streak, today, isPremium);

        if (streak.LastActiveDate == today)
        {
            return;
        }

        var expectedPrevious = today.AddDays(-1);
        if (streak.LastActiveDate == expectedPrevious)
        {
            streak.CurrentStreak += 1;
        }
        else if (streak.LastActiveDate == today.AddDays(-2)
            && streak.StreakFreezesAvailable > 0)
        {
            streak.StreakFreezesAvailable -= 1;
            streak.CurrentStreak += 2;
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

    }

    private static void ResetWeeklyFreezesIfNeeded(DailyStreak streak, DateOnly today, bool isPremium)
    {
        var currentWeekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);
        if (!streak.FreezesResetAt.HasValue || streak.FreezesResetAt.Value < currentWeekStart)
        {
            streak.WeeklyFreezeAllowance = isPremium ? 2 : 1;
            streak.StreakFreezesAvailable = streak.WeeklyFreezeAllowance;
            streak.FreezesResetAt = currentWeekStart;
        }
    }

    private async Task UpdateChallengeProgressAsync(
        Guid userId,
        string challengeType,
        int increment,
        DateOnly startOfWeek,
        DateTime occurredAtUtc,
        CancellationToken cancellationToken)
    {
        var challenge = await dbContext.WeeklyChallenges
            .FirstOrDefaultAsync(x => x.WeekStartDate == startOfWeek && x.ChallengeType == challengeType, cancellationToken);

        if (challenge is null)
        {
            await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(
                dbContext,
                startOfWeek,
                cancellationToken,
                persistImmediately: false);
            challenge = dbContext.WeeklyChallenges.Local
                .FirstOrDefault(x => x.WeekStartDate == startOfWeek && x.ChallengeType == challengeType)
                ?? await dbContext.WeeklyChallenges
                    .FirstOrDefaultAsync(
                        x => x.WeekStartDate == startOfWeek && x.ChallengeType == challengeType,
                        cancellationToken);

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
            progress.CompletedAtUtc = occurredAtUtc;
        }
    }

    private async Task<int> CreditPendingChallengeRewardsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var persistedPending = await dbContext.UserChallengeProgresses
            .Where(x => x.UserId == userId && x.Completed && !x.RewardCredited)
            .ToListAsync(cancellationToken);
        var pending = persistedPending
            .Concat(dbContext.UserChallengeProgresses.Local
                .Where(x => x.UserId == userId && x.Completed && !x.RewardCredited))
            .DistinctBy(x => x.Id)
            .ToList();
        if (pending.Count == 0)
        {
            return 0;
        }

        var challengeIds = pending.Select(x => x.ChallengeId).ToHashSet();
        var persistedChallenges = await dbContext.WeeklyChallenges
            .Where(x => challengeIds.Contains(x.Id))
            .ToListAsync(cancellationToken);
        var challenges = persistedChallenges
            .Concat(dbContext.WeeklyChallenges.Local.Where(x => challengeIds.Contains(x.Id)))
            .GroupBy(x => x.Id)
            .ToDictionary(x => x.Key, x => x.First());
        var creditedSpark = 0;

        foreach (var progress in pending)
        {
            if (!challenges.TryGetValue(progress.ChallengeId, out var challenge))
            {
                continue;
            }

            if (challenge.RewardSpark <= 0)
            {
                progress.RewardCredited = true;
                continue;
            }

            if (economyService is null)
            {
                continue;
            }

            var creditResult = await economyService.CreditAsync(
                new CreditBalanceCommand(
                    userId,
                    challenge.RewardSpark,
                    "challenge_reward",
                    "Weekly challenge reward",
                    IdempotencyKey: $"challenge:{challenge.Id:N}"),
                cancellationToken);
            if (creditResult.IsFailure)
            {
                throw new InvalidOperationException("Weekly challenge reward credit could not be confirmed.");
            }

            progress.RewardCredited = true;
            creditedSpark += challenge.RewardSpark;
        }

        return creditedSpark;
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
        var persistedProgress = await dbContext.PetProgresses
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);
        var progress = persistedProgress
            .Concat(dbContext.PetProgresses.Local.Where(x => x.UserId == userId))
            .DistinctBy(x => x.Id)
            .ToList();

        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken)
            ?? dbContext.DailyStreaks.Local.FirstOrDefault(x => x.UserId == userId);

        return new UserProgressCounters
        {
            TotalGenerations = progress.Sum(x => x.TotalGenerations),
            PetCount = progress.Count,
            StreakDays = streak?.CurrentStreak ?? 0,
            MaxPetLevel = progress.Count == 0 ? 0 : progress.Max(x => x.Level)
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

    private static DateTime NormalizeUtcTimestamp(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc)
    };

    private sealed class UserProgressCounters
    {
        public int TotalGenerations { get; set; }
        public int PetCount { get; set; }
        public int StreakDays { get; set; }
        public int MaxPetLevel { get; set; }
    }
}
