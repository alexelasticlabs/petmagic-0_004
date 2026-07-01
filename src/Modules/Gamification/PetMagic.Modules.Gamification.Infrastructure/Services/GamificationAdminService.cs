using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Contracts;
using PetMagic.Modules.Gamification.Domain.Constants;
using PetMagic.Modules.Gamification.Infrastructure.Data;

namespace PetMagic.Modules.Gamification.Infrastructure.Services;

public sealed class GamificationAdminService(
    GamificationDbContext dbContext,
    IGamificationService gamificationService) : IGamificationAdminService
{
    public async Task<Result<AdminGamificationDashboardMetricsResponse>> GetAdminDashboardMetricsAsync(CancellationToken cancellationToken)
    {
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        var currentWeekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(today);
        await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(dbContext, currentWeekStart, cancellationToken);

        var currentWeekChallengeIds = await dbContext.WeeklyChallenges
            .Where(x => x.WeekStartDate == currentWeekStart)
            .Select(x => x.Id)
            .ToListAsync(cancellationToken);

        var metrics = new AdminGamificationDashboardMetricsResponse(
            TotalUsersWithProgress: await dbContext.PetProgresses.Select(x => x.UserId).Distinct().CountAsync(cancellationToken),
            TotalPetsTracked: await dbContext.PetProgresses.CountAsync(cancellationToken),
            TotalAchievementDefinitions: await dbContext.AchievementDefinitions.CountAsync(cancellationToken),
            TotalAchievementsUnlocked: await dbContext.UserAchievements.CountAsync(cancellationToken),
            UsersWithActiveStreak: await dbContext.DailyStreaks.CountAsync(x => x.CurrentStreak > 0, cancellationToken),
            CurrentWeekChallenges: currentWeekChallengeIds.Count,
            CurrentWeekChallengeParticipants: await dbContext.UserChallengeProgresses
                .Where(x => currentWeekChallengeIds.Contains(x.ChallengeId))
                .Select(x => x.UserId)
                .Distinct()
                .CountAsync(cancellationToken),
            CurrentWeekChallengeCompletions: await dbContext.UserChallengeProgresses
                .CountAsync(x => currentWeekChallengeIds.Contains(x.ChallengeId) && x.Completed, cancellationToken),
            GeneratedAtUtc: DateTime.UtcNow);

        return Result.Success(metrics);
    }

    public async Task<Result<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>> ListAdminAchievementsAsync(CancellationToken cancellationToken)
    {
        var unlockedCounts = (await dbContext.UserAchievements
                .Select(x => new
                {
                    x.UserId,
                    x.AchievementKey
                })
                .ToListAsync(cancellationToken))
            .Select(row => new
            {
                row.UserId,
                Key = NormalizeAchievementKey(row.AchievementKey)
            })
            .Where(x => x.Key.Length > 0)
            .GroupBy(x => x.Key, StringComparer.Ordinal)
            .ToDictionary(
                x => x.Key,
                x => x.Select(item => item.UserId).Distinct().Count(),
                StringComparer.Ordinal);

        var definitions = await dbContext.AchievementDefinitions
            .OrderBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);

        var items = definitions
            .Select(def =>
            {
                var normalizedKey = NormalizeAchievementKey(def.Key);
                return new AdminGamificationAchievementDefinitionResponse(
                    normalizedKey,
                    def.Category ?? "special",
                    def.Rarity ?? "common",
                    def.TitleKey ?? string.Empty,
                    def.DescriptionKey ?? string.Empty,
                    def.IconEmoji,
                    def.RequirementType ?? string.Empty,
                    def.RequirementValue,
                    def.RewardSpark,
                    def.IsSecret,
                    def.SortOrder,
                    unlockedCounts.TryGetValue(normalizedKey, out var count) ? count : 0);
            })
            .ToList();

        return Result.Success<IReadOnlyList<AdminGamificationAchievementDefinitionResponse>>(items);
    }

    public async Task<Result<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>> ListAdminCurrentChallengesAsync(CancellationToken cancellationToken)
    {
        var weekStart = GamificationWeeklyChallengeCatalog.GetCurrentWeekStart(DateOnly.FromDateTime(DateTime.UtcNow));
        await GamificationWeeklyChallengeCatalog.EnsureWeeklyChallengesAsync(dbContext, weekStart, cancellationToken);

        var challenges = await dbContext.WeeklyChallenges
            .Where(x => x.WeekStartDate == weekStart)
            .OrderBy(x => x.SortOrder)
            .ToListAsync(cancellationToken);
        var challengeIds = challenges.Select(x => x.Id).ToList();
        var aggregates = await dbContext.UserChallengeProgresses
            .Where(x => challengeIds.Contains(x.ChallengeId))
            .GroupBy(x => x.ChallengeId)
            .Select(group => new
            {
                ChallengeId = group.Key,
                Participants = group.Select(x => x.UserId).Distinct().Count(),
                Completed = group.Count(x => x.Completed)
            })
            .ToDictionaryAsync(x => x.ChallengeId, cancellationToken);

        var items = challenges.Select(challenge =>
        {
            aggregates.TryGetValue(challenge.Id, out var stats);

            return new AdminGamificationChallengeSummaryResponse(
                challenge.Id,
                challenge.WeekStartDate,
                challenge.ChallengeType ?? string.Empty,
                challenge.TargetValue,
                challenge.TitleKey ?? string.Empty,
                challenge.DescriptionKey ?? string.Empty,
                challenge.IconEmoji,
                challenge.RewardSpark,
                challenge.SortOrder,
                stats?.Participants ?? 0,
                stats?.Completed ?? 0);
        }).ToList();

        return Result.Success<IReadOnlyList<AdminGamificationChallengeSummaryResponse>>(items);
    }

    public async Task<Result<AdminUserGamificationOverviewResponse>> GetAdminUserOverviewAsync(Guid userId, CancellationToken cancellationToken)
    {
        var streak = await gamificationService.GetStreakAsync(userId, cancellationToken);
        var achievements = await gamificationService.GetAchievementsAsync(userId, cancellationToken);
        var currentChallenges = await gamificationService.GetCurrentChallengesAsync(userId, cancellationToken);
        var pets = await dbContext.PetProgresses
            .Where(x => x.UserId == userId)
            .OrderByDescending(x => x.Level)
            .ThenByDescending(x => x.Xp)
            .ThenByDescending(x => x.LastGenerationAtUtc)
            .ToListAsync(cancellationToken);

        var response = new AdminUserGamificationOverviewResponse(
            userId,
            streak,
            pets.Select(MapPetProgress).ToList(),
            achievements,
            currentChallenges);

        return Result.Success(response);
    }

    public async Task<Result> ResetAdminUserStreakAsync(Guid userId, CancellationToken cancellationToken)
    {
        var streak = await dbContext.DailyStreaks
            .FirstOrDefaultAsync(x => x.UserId == userId, cancellationToken);

        if (streak is null)
        {
            return Result.Failure(GamificationErrors.StreakNotFound);
        }

        dbContext.DailyStreaks.Remove(streak);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    private static PetProgressResponse MapPetProgress(Infrastructure.Entities.PetProgress progress)
    {
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

    private static string NormalizeAchievementKey(string? value) => value?.Trim() ?? string.Empty;
}
