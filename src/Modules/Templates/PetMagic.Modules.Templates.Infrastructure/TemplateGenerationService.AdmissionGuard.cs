using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task<Result<QueueEstimate>> EnsureGenerationAdmissionUnderLockAsync(
        Guid userId,
        TemplateItem template,
        string queueTier,
        int activeGenerationLimit,
        CancellationToken cancellationToken)
    {
        var activeCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == userId
                && TemplateGenerationJobStatusSets.Active.Contains(x.Status),
                cancellationToken);
        if (activeCount >= Math.Max(1, activeGenerationLimit))
        {
            return Result.Failure<QueueEstimate>(TemplatesErrors.ActiveGenerationLimitReached);
        }

        if (options.QueueMaxSize > 0)
        {
            var queueSize = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .CountAsync(x => TemplateGenerationJobStatusSets.Active.Contains(x.Status),
                    cancellationToken);
            if (queueSize >= options.QueueMaxSize)
            {
                return Result.Failure<QueueEstimate>(TemplatesErrors.GenerationQueueOverloaded);
            }
        }

        return await EnsureQueueCanAcceptAsync(template, queueTier, cancellationToken);
    }
}
