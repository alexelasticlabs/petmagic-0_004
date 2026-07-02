using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    public async Task<Result<CancelQueuedGenerationResponse>> CancelQueuedAsync(
        Guid userId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        if (!options.CancelQueuedGenerationEnabled)
        {
            return Result.Failure<CancelQueuedGenerationResponse>(TemplatesErrors.GenerationCancelDisabled);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (job is null)
        {
            return Result.Failure<CancelQueuedGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return Result.Failure<CancelQueuedGenerationResponse>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Cancelled;
        job.CancelledAtUtc = now;
        job.CompletedAtUtc = now;
        job.UpdatedAtUtc = now;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            return Result.Failure<CancelQueuedGenerationResponse>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        var refunded = false;
        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            job.RefundAttemptCount++;
            job.RefundLastAttemptedAtUtc = DateTime.UtcNow;
            var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
            if (refund.IsFailure)
            {
                job.RefundLastErrorCode = refund.Error.Code;
                TemplateGenerationMetrics.RecordRefundFailure(job, refund.Error.Code);
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            else
            {
                job.RefundedAtUtc = DateTime.UtcNow;
                job.RefundLastErrorCode = null;
                refunded = true;
                TemplateGenerationMetrics.RecordJobRefunded(job);
                TemplateGenerationMetrics.RecordCancelRefund(job);
                await dbContext.SaveChangesAsync(cancellationToken);
            }
        }

        TemplateGenerationMetrics.RecordJobCancelled(job);
        if (realtimeService is not null)
        {
            await realtimeService.PublishGenerationStatusChangedAsync(
                await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                cancellationToken);
        }

        return Result.Success(new CancelQueuedGenerationResponse(
            job.Id,
            ResolveApiStatus(job.Status),
            refunded,
            now));
    }
}
