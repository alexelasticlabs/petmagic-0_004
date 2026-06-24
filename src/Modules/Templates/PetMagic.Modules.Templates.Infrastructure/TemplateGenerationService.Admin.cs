using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    public async Task<Result<TemplateGenerationResponse>> GetAdminAsync(Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == AdminTestUserId, cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    public async Task<Result<RemoveGenerationWatermarkResponse>> GrantAdminCleanDownloadAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<RemoveGenerationWatermarkResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        var existing = job.WatermarkUnlocks.FirstOrDefault(x => x.UserId == job.UserId);
        if (existing is null)
        {
            existing = AddWatermarkUnlock(job, TemplateWatermarkUnlockMethod.Admin, creditsSpent: 0, adminUserId);
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.RemovedPremium, "admin", "admin", creditsSpent: 0);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return Result.Success(new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl));
    }
}
