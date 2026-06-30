using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    internal static TemplateGenerationResponse ApplyWatermarkAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool isPremium,
        bool hasUnlock,
        int removeWatermarkCostCredits)
    {
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;

        return response with
        {
            OutputUrl = ResolveAccessibleOutputUrl(job, hasCleanAccess),
            HasWatermark = HasWatermark(job, hasCleanAccess),
            CanRemoveWatermark = CanRemoveWatermark(job, hasCleanAccess),
            IsWatermarkRemoved = hasUnlock || job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits = Math.Max(1, removeWatermarkCostCredits),
            UserPlan = isPremium ? "premium" : "free",
            WatermarkMessage = ResolveWatermarkMessage(job, hasCleanAccess)
        };
    }

    private static string? ResolveAccessibleOutputUrl(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (job.Status != TemplateGenerationStatus.Completed)
        {
            return job.ResultUrl;
        }

        if (hasCleanAccess)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static string? ResolveDefaultOutputUrl(TemplateGenerationJob job)
    {
        if (job.Status != TemplateGenerationStatus.Completed || !job.IsWatermarkRequired)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static bool HasWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.WatermarkedResultUrl);
    }

    private static bool CanRemoveWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.ResultUrl);
    }

    private static string? ResolveWatermarkMessage(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (hasCleanAccess && job.IsWatermarkRequired)
        {
            return "Watermark removed";
        }

        if (job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && string.IsNullOrWhiteSpace(job.WatermarkedResultUrl))
        {
            return "Preparing result...";
        }

        return job.IsWatermarkRequired && !hasCleanAccess
            ? "Watermark added on the free plan"
            : null;
    }

    private TemplateGenerationWatermarkUnlock AddWatermarkUnlock(
        TemplateGenerationJob job,
        TemplateWatermarkUnlockMethod unlockMethod,
        int creditsSpent,
        Guid? unlockedByUserId)
    {
        var unlock = new TemplateGenerationWatermarkUnlock
        {
            Id = Guid.NewGuid(),
            UserId = job.UserId,
            GenerationJobId = job.Id,
            UnlockedByUserId = unlockedByUserId,
            UnlockMethod = unlockMethod,
            CreditsSpent = creditsSpent,
            CreatedAtUtc = DateTime.UtcNow
        };

        job.IsWatermarkRemoved = true;
        job.UpdatedAtUtc = unlock.CreatedAtUtc;
        dbContext.TemplateGenerationWatermarkUnlocks.Add(unlock);
        return unlock;
    }

    private async Task<RemoveGenerationWatermarkResponse?> TryResolveExistingWatermarkUnlockAsync(
        Guid userId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();

        var existing = await dbContext.TemplateGenerationWatermarkUnlocks
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.GenerationJobId == generationId)
            .Select(x => new { x.CreditsSpent })
            .FirstOrDefaultAsync(cancellationToken);
        if (existing is null)
        {
            return null;
        }

        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);
        if (job is null || string.IsNullOrWhiteSpace(job.ResultUrl))
        {
            return null;
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl);
    }
}
