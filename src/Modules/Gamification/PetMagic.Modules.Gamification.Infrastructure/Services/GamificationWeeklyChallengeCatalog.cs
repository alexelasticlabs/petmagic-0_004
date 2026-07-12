using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Gamification.Domain.Constants;
using PetMagic.Modules.Gamification.Infrastructure.Data;
using PetMagic.Modules.Gamification.Infrastructure.Entities;

namespace PetMagic.Modules.Gamification.Infrastructure.Services;

internal static class GamificationWeeklyChallengeCatalog
{
    public static DateOnly GetCurrentWeekStart(DateOnly today)
    {
        var startOfWeek = today.AddDays(-(int)today.DayOfWeek + (int)DayOfWeek.Monday);
        return today.DayOfWeek == DayOfWeek.Sunday ? today.AddDays(-6) : startOfWeek;
    }

    public static async Task EnsureWeeklyChallengesAsync(
        GamificationDbContext dbContext,
        DateOnly weekStart,
        CancellationToken cancellationToken,
        bool persistImmediately = true)
    {
        var now = DateTime.UtcNow;
        if (dbContext.Database.IsRelational())
        {
            await using var transaction = dbContext.Database.CurrentTransaction is null
                ? await dbContext.Database.BeginTransactionAsync(cancellationToken)
                : null;
            foreach (var template in DefaultChallenges.Templates.Select((challenge, index) => (challenge, index)))
            {
                await dbContext.Database.ExecuteSqlInterpolatedAsync($$"""
                    INSERT INTO "gamification_weekly_challenges"
                        ("Id", "WeekStartDate", "ChallengeType", "TargetValue", "TitleKey", "DescriptionKey",
                         "RewardSpark", "SortOrder", "CreatedAtUtc")
                    VALUES
                        ({{Guid.NewGuid()}}, {{weekStart}}, {{template.challenge.ChallengeType}}, {{template.challenge.TargetValue}},
                         {{template.challenge.TitleKey}}, {{template.challenge.DescriptionKey}},
                         {{template.challenge.RewardSpark}}, {{template.index}}, {{now}})
                    ON CONFLICT ("WeekStartDate", "ChallengeType") DO NOTHING
                    """, cancellationToken);
            }

            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return;
        }

        var existingTypes = (await dbContext.WeeklyChallenges
                .Where(x => x.WeekStartDate == weekStart)
                .Select(x => x.ChallengeType)
                .ToListAsync(cancellationToken))
            .Concat(dbContext.WeeklyChallenges.Local
                .Where(x => x.WeekStartDate == weekStart)
                .Select(x => x.ChallengeType))
            .ToHashSet(StringComparer.Ordinal);

        foreach (var template in DefaultChallenges.Templates.Select((challenge, index) => (challenge, index)))
        {
            if (!existingTypes.Add(template.challenge.ChallengeType))
            {
                continue;
            }

            dbContext.WeeklyChallenges.Add(new WeeklyChallenge
            {
                Id = Guid.NewGuid(),
                WeekStartDate = weekStart,
                ChallengeType = template.challenge.ChallengeType,
                TargetValue = template.challenge.TargetValue,
                TitleKey = template.challenge.TitleKey,
                DescriptionKey = template.challenge.DescriptionKey,
                RewardSpark = template.challenge.RewardSpark,
                SortOrder = template.index,
                CreatedAtUtc = now
            });
        }

        if (persistImmediately)
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
    }
}
