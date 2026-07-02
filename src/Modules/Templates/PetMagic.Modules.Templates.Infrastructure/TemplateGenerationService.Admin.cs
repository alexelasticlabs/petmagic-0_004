using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
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

    public async Task<Result<TemplateGenerationResponse>> RetryAdminGenerationRefundAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (job.Status is not (TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled)
            || job.ChargedAtUtc is null
            || job.RefundedAtUtc is not null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRefundNotPending);
        }

        // No money moves here: the refund itself stays inside the idempotent worker retry pipeline
        // (generation_refund ledger unique index guarantees at-most-once crediting). This action only
        // re-arms the retry budget so the worker picks the job up again within its poll interval.
        job.RefundAttemptCount = 0;
        job.RefundLastAttemptedAtUtc = null;
        job.RefundLastErrorCode = null;
        job.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        logger?.LogWarning(
            "ADMIN ACTION: generation refund retry re-armed. AdminUserId={AdminUserId} GenerationId={GenerationId} UserId={UserId} TokenCost={TokenCost} CorrelationId={CorrelationId}",
            adminUserId,
            job.Id,
            job.UserId,
            job.TokenCost,
            CorrelationContext.ResolveOrCreate());

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }
}
