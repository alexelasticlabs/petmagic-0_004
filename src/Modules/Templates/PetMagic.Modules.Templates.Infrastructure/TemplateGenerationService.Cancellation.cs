using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

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

        var cancelResult = await CancelQueuedJobAsync(job, adminUserId: null, cancellationToken);
        if (cancelResult.IsFailure)
        {
            return Result.Failure<CancelQueuedGenerationResponse>(cancelResult.Error);
        }

        return Result.Success(new CancelQueuedGenerationResponse(
            job.Id,
            cancelResult.Value.Status,
            cancelResult.Value.Refunded,
            cancelResult.Value.CancelledAtUtc));
    }

    private async Task<Result<QueuedGenerationCancelResult>> CancelQueuedJobAsync(
        TemplateGenerationJob job,
        Guid? adminUserId,
        CancellationToken cancellationToken)
    {
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return Result.Failure<QueuedGenerationCancelResult>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        var previousStatus = job.Status;
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
            return Result.Failure<QueuedGenerationCancelResult>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        var refunded = false;
        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            job.RefundAttemptCount++;
            job.RefundLastAttemptedAtUtc = DateTime.UtcNow;
            var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
            if (refund.IsFailure)
            {
                var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(refund.Error.Code);
                job.RefundLastErrorCode = safeErrorCode;
                TemplateGenerationMetrics.RecordRefundFailure(job, safeErrorCode ?? "templates.refund_failed");
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
        var response = await MapResponseWithQueueMetricsAsync(job, cancellationToken);
        if (realtimeService is not null)
        {
            await realtimeService.PublishGenerationStatusChangedAsync(
                response,
                cancellationToken);
        }

        if (adminUserId.HasValue)
        {
            logger?.LogWarning(
                "ADMIN ACTION: queued generation cancelled. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} UserIdHash={UserIdHash} PreviousStatus={PreviousStatus} Refunded={Refunded} CorrelationIdHash={CorrelationIdHash}",
                TemplateLogSanitizer.SafeId(adminUserId.Value),
                TemplateLogSanitizer.SafeId(job.Id),
                TemplateLogSanitizer.SafeId(job.UserId),
                previousStatus,
                refunded,
                SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

            if (adminAuditLog is not null)
            {
                await adminAuditLog.WriteAsync(
                    new AdminAuditEntry(
                        "admin.template_generation.cancelled",
                        "template_generation",
                        job.Id.ToString("D"),
                        previousStatus.ToString(),
                        job.Status.ToString(),
                        $"Queued generation cancelled by admin. Refunded={refunded}.",
                        job.UserId),
                    cancellationToken);
            }
        }

        return Result.Success(new QueuedGenerationCancelResult(ResolveApiStatus(job.Status), refunded, now, response));
    }

    private sealed record QueuedGenerationCancelResult(
        string Status,
        bool Refunded,
        DateTime CancelledAtUtc,
        TemplateGenerationResponse Response);
}
