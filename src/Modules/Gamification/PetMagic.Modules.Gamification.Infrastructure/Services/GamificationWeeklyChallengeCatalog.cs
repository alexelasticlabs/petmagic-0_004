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
        CancellationToken cancellationToken)
    {
        var existing = await dbContext.WeeklyChallenges
            .AnyAsync(x => x.WeekStartDate == weekStart, cancellationToken);

        if (existing)
        {
            return;
        }

        var now = DateTime.UtcNow;
        foreach (var template in DefaultChallenges.Templates.Select((challenge, index) => (challenge, index)))
        {
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

        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
