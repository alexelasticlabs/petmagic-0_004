using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private const int MaxProviderCancellationAttempts = 5;
    private const int ProviderCancellationLeaseSeconds = 120;

    public async Task<Result<AdminGenerationCancellationResult>> CancelAdminAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        if (!options.CancelQueuedGenerationEnabled)
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelDisabled);
        }

        var current = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.HiddenByUserAtUtc == null, cancellationToken);
        if (current is null)
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationJobNotFound);
        }

        if (current.Status == TemplateGenerationStatus.Cancelled)
        {
            return Result.Success(new AdminGenerationCancellationResult(
                await MapResponseWithQueueMetricsAsync(current, cancellationToken),
                IsPending: false));
        }

        if (current.Status == TemplateGenerationStatus.CancellationRequested)
        {
            return Result.Success(new AdminGenerationCancellationResult(
                await MapResponseWithQueueMetricsAsync(current, cancellationToken),
                IsPending: true));
        }

        if (current.Status == TemplateGenerationStatus.Queued)
        {
            dbContext.ChangeTracker.Clear();
            var queued = await dbContext.TemplateGenerationJobs
                .Include(x => x.Template)
                .Include(x => x.WatermarkUnlocks)
                .FirstAsync(x => x.Id == generationId, cancellationToken);
            var cancelled = await CancelQueuedJobAsync(queued, adminUserId, cancellationToken);
            return cancelled.IsFailure
                ? Result.Failure<AdminGenerationCancellationResult>(cancelled.Error)
                : Result.Success(new AdminGenerationCancellationResult(cancelled.Value.Response, IsPending: false));
        }

        if (current.Status is not (TemplateGenerationStatus.ProviderQueued or TemplateGenerationStatus.ProviderProcessing))
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        if (falQueueClient is null || ResolveProviderCancellationTarget(current) is null)
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelProviderUnsupported);
        }

        dbContext.ChangeTracker.Clear();
        await using (var transaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken))
        {
            if (transaction is not null)
            {
                await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
            }

            var job = await dbContext.TemplateGenerationJobs
                .Include(x => x.Template)
                .FirstOrDefaultAsync(x => x.Id == generationId && x.HiddenByUserAtUtc == null, cancellationToken);
            if (job is null)
            {
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationJobNotFound);
            }

            if (job.Status == TemplateGenerationStatus.Cancelled)
            {
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: false));
            }

            if (job.Status == TemplateGenerationStatus.CancellationRequested)
            {
                if (transaction is not null)
                {
                    await transaction.CommitAsync(cancellationToken);
                }

                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: true));
            }

            if (job.Status is not (TemplateGenerationStatus.ProviderQueued or TemplateGenerationStatus.ProviderProcessing)
                || ResolveProviderCancellationTarget(job) is null)
            {
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelNotAllowed);
            }

            var now = DateTime.UtcNow;
            job.CancellationPreviousStatus = job.Status;
            job.Status = TemplateGenerationStatus.CancellationRequested;
            job.CancellationRequestedByAdminUserId = adminUserId;
            job.CancellationRequestedAtUtc ??= now;
            job.CancellationAttemptCount = 0;
            job.CancellationLastAttemptedAtUtc = null;
            job.CancellationNextAttemptAtUtc = now;
            job.CancellationAcceptedAtUtc = null;
            job.CancellationLastErrorCode = null;
            job.LockedAtUtc = null;
            job.LockedBy = null;
            job.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            await PublishCancellationStatusAsync(job, cancellationToken);
            await WriteCancellationAuditAsync(
                job,
                "admin.template_generation.cancellation_requested",
                job.CancellationPreviousStatus?.ToString(),
                job.Status.ToString(),
                "Provider cancellation requested.",
                cancellationToken);
        }

        dbContext.ChangeTracker.Clear();
        return await ProcessProviderCancellationAsync(generationId, ignoreSchedule: true, cancellationToken);
    }

    public async Task<bool> ProcessNextPendingCancellationAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var generationId = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.CancellationRequested
                && (x.CancellationNextAttemptAtUtc == null || x.CancellationNextAttemptAtUtc <= now))
            .OrderBy(x => x.CancellationNextAttemptAtUtc)
            .ThenBy(x => x.CancellationRequestedAtUtc)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        if (!generationId.HasValue)
        {
            return false;
        }

        _ = await ProcessProviderCancellationAsync(
            generationId.Value,
            ignoreSchedule: false,
            cancellationToken);
        return true;
    }

    private async Task<Result<AdminGenerationCancellationResult>> ProcessProviderCancellationAsync(
        Guid generationId,
        bool ignoreSchedule,
        CancellationToken cancellationToken)
    {
        ProviderCancellationTarget target;
        dbContext.ChangeTracker.Clear();
        await using (var claimTransaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken))
        {
            if (claimTransaction is not null)
            {
                await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
            }

            var job = await dbContext.TemplateGenerationJobs
                .Include(x => x.Template)
                .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
            if (job is null)
            {
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationJobNotFound);
            }

            if (job.Status != TemplateGenerationStatus.CancellationRequested)
            {
                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: false));
            }

            var now = DateTime.UtcNow;
            if (!ignoreSchedule && job.CancellationNextAttemptAtUtc > now)
            {
                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: true));
            }

            target = ResolveProviderCancellationTarget(job)!;
            if (falQueueClient is null || target is null)
            {
                await RestoreAfterRejectedCancellationAsync(
                    job,
                    TemplatesErrors.GenerationCancelProviderUnsupported.Code,
                    markGenerationError: true,
                    cancellationToken);
                if (claimTransaction is not null)
                {
                    await claimTransaction.CommitAsync(cancellationToken);
                }

                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelProviderUnsupported);
            }

            job.CancellationAttemptCount++;
            job.CancellationLastAttemptedAtUtc = now;
            job.CancellationNextAttemptAtUtc = now.AddSeconds(ProviderCancellationLeaseSeconds);
            job.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            if (claimTransaction is not null)
            {
                await claimTransaction.CommitAsync(cancellationToken);
            }
        }

        var providerResult = await falQueueClient!.CancelAsync(
            target.Model,
            target.RequestId,
            target.CancelUri,
            cancellationToken);

        dbContext.ChangeTracker.Clear();
        await using var settleTransaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken);
        if (settleTransaction is not null)
        {
            await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
        }

        var settledJob = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (settledJob is null)
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationJobNotFound);
        }

        if (settledJob.Status != TemplateGenerationStatus.CancellationRequested)
        {
            if (settleTransaction is not null)
            {
                await settleTransaction.CommitAsync(cancellationToken);
            }

            return Result.Success(new AdminGenerationCancellationResult(
                await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken),
                IsPending: settledJob.Status == TemplateGenerationStatus.CancellationRequested));
        }

        switch (providerResult.Outcome)
        {
            case FalQueueCancellationOutcome.Accepted:
                await FinalizeProviderCancellationAsync(settledJob, cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                await RefundAcceptedProviderCancellationAsync(settledJob, cancellationToken);
                var acceptedResponse = await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken);
                await PublishCancellationStatusAsync(settledJob, cancellationToken, acceptedResponse);
                await WriteCancellationAuditAsync(
                    settledJob,
                    "admin.template_generation.cancelled",
                    settledJob.CancellationPreviousStatus?.ToString(),
                    settledJob.Status.ToString(),
                    $"Provider cancellation accepted. Refunded={settledJob.RefundedAtUtc is not null}.",
                    cancellationToken);
                return Result.Success(new AdminGenerationCancellationResult(acceptedResponse, IsPending: false));

            case FalQueueCancellationOutcome.AlreadyCompleted:
                await RestoreAfterRejectedCancellationAsync(
                    settledJob,
                    providerResult.ErrorCode,
                    markGenerationError: false,
                    cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                await PublishCancellationStatusAsync(settledJob, cancellationToken);
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelAlreadyCompleted);

            case FalQueueCancellationOutcome.NotFound:
                await RestoreAfterRejectedCancellationAsync(
                    settledJob,
                    providerResult.ErrorCode,
                    markGenerationError: false,
                    cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                await PublishCancellationStatusAsync(settledJob, cancellationToken);
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelProviderNotFound);

            case FalQueueCancellationOutcome.TransientFailure
                when settledJob.CancellationAttemptCount < MaxProviderCancellationAttempts:
                settledJob.CancellationLastErrorCode = AdminFailureMessageSanitizer.SanitizeCode(providerResult.ErrorCode);
                settledJob.CancellationNextAttemptAtUtc = DateTime.UtcNow.Add(
                    ResolveProviderCancellationRetryDelay(settledJob.CancellationAttemptCount));
                settledJob.UpdatedAtUtc = DateTime.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                var pendingResponse = await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken);
                await PublishCancellationStatusAsync(settledJob, cancellationToken, pendingResponse);
                return Result.Success(new AdminGenerationCancellationResult(pendingResponse, IsPending: true));

            case FalQueueCancellationOutcome.TransientFailure:
                await RestoreAfterRejectedCancellationAsync(
                    settledJob,
                    TemplatesErrors.GenerationCancelRetryExhausted.Code,
                    markGenerationError: true,
                    cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                await PublishCancellationStatusAsync(settledJob, cancellationToken);
                await WriteCancellationAuditAsync(
                    settledJob,
                    "admin.template_generation.cancellation_exhausted",
                    TemplateGenerationStatus.CancellationRequested.ToString(),
                    settledJob.Status.ToString(),
                    "Provider cancellation retry budget exhausted.",
                    cancellationToken);
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelRetryExhausted);

            default:
                await RestoreAfterRejectedCancellationAsync(
                    settledJob,
                    providerResult.ErrorCode,
                    markGenerationError: true,
                    cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                await PublishCancellationStatusAsync(settledJob, cancellationToken);
                return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelProviderUnsupported);
        }
    }

    private ProviderCancellationTarget? ResolveProviderCancellationTarget(TemplateGenerationJob job)
    {
        if (falQueueClient is null)
        {
            return null;
        }

        string? model;
        string? requestId;
        string? statusUrl;
        string? cancelUrl;
        if (string.Equals(job.CurrentProviderStage, "video_generation", StringComparison.Ordinal))
        {
            model = job.UsedKlingModel ?? job.Template?.KlingModel;
            requestId = job.MotionProviderRequestId;
            statusUrl = job.MotionProviderStatusUrl;
            cancelUrl = job.MotionProviderCancelUrl;
        }
        else if (string.Equals(job.CurrentProviderStage, "image_generation", StringComparison.Ordinal)
            || string.Equals(job.CurrentProviderStage, "video_preprocessing", StringComparison.Ordinal))
        {
            model = job.UsedPreprocessingModel
                ?? (job.Template?.TemplateType == TemplateType.Image
                    ? job.Template.ImageModel
                    : job.Template?.PreprocessingModel);
            requestId = job.PreprocessingProviderRequestId;
            statusUrl = job.PreprocessingProviderStatusUrl;
            cancelUrl = job.PreprocessingProviderCancelUrl;
        }
        else
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(model) || string.IsNullOrWhiteSpace(requestId))
        {
            return null;
        }

        var cancelUri = falQueueClient.ResolveCancellationUri(model, requestId, cancelUrl, statusUrl);
        return cancelUri is null
            ? null
            : new ProviderCancellationTarget(model, requestId, cancelUri);
    }

    private async Task FinalizeProviderCancellationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Cancelled;
        job.ProviderStatus = "CANCELLATION_REQUESTED";
        job.CancellationAcceptedAtUtc = now;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationLastErrorCode = null;
        job.CancelledAtUtc = now;
        job.CompletedAtUtc = now;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordJobCancelled(job);
    }

    private async Task RefundAcceptedProviderCancellationAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (job.ChargedAtUtc is null || job.RefundedAtUtc is not null)
        {
            return;
        }

        job.RefundAttemptCount++;
        job.RefundLastAttemptedAtUtc = DateTime.UtcNow;
        var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (refund.IsFailure)
        {
            job.RefundLastErrorCode = AdminFailureMessageSanitizer.SanitizeCode(refund.Error.Code);
            TemplateGenerationMetrics.RecordRefundFailure(
                job,
                job.RefundLastErrorCode ?? "templates.refund_failed");
        }
        else
        {
            job.RefundedAtUtc = DateTime.UtcNow;
            job.RefundLastErrorCode = null;
            TemplateGenerationMetrics.RecordJobRefunded(job);
            TemplateGenerationMetrics.RecordCancelRefund(job);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task RestoreAfterRejectedCancellationAsync(
        TemplateGenerationJob job,
        string? errorCode,
        bool markGenerationError,
        CancellationToken cancellationToken)
    {
        var previousStatus = job.CancellationPreviousStatus;
        job.Status = previousStatus is TemplateGenerationStatus.ProviderQueued or TemplateGenerationStatus.ProviderProcessing
            ? previousStatus.Value
            : TemplateGenerationStatus.ProviderProcessing;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationLastErrorCode = AdminFailureMessageSanitizer.SanitizeCode(errorCode);
        if (markGenerationError)
        {
            job.LastErrorCode = job.CancellationLastErrorCode;
        }

        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task PublishCancellationStatusAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        TemplateGenerationResponse? response = null)
    {
        if (realtimeService is null)
        {
            return;
        }

        response ??= await MapResponseWithQueueMetricsAsync(job, cancellationToken);
        await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
    }

    private async Task WriteCancellationAuditAsync(
        TemplateGenerationJob job,
        string action,
        string? oldValue,
        string? newValue,
        string details,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null || !job.CancellationRequestedByAdminUserId.HasValue)
        {
            return;
        }

        await adminAuditLog.WriteAsync(
            new AdminAuditEntry(
                action,
                "TemplateGenerationJob",
                job.Id.ToString("D"),
                oldValue,
                newValue,
                details,
                job.UserId),
            cancellationToken);
    }

    private static TimeSpan ResolveProviderCancellationRetryDelay(int attemptCount)
    {
        var seconds = Math.Min(120, 5 * (1 << Math.Clamp(attemptCount - 1, 0, 5)));
        return TimeSpan.FromSeconds(seconds);
    }

    private sealed record ProviderCancellationTarget(string Model, string RequestId, Uri CancelUri);
}
