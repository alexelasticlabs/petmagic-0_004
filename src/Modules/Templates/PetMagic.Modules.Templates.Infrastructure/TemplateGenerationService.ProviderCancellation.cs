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

        if (IsVideoInterstageCancellation(current))
        {
            return await CancelVideoInterstageAsync(adminUserId, generationId, cancellationToken);
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
        var pendingCancellation = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.CancellationRequested
                && (x.CancellationNextAttemptAtUtc == null || x.CancellationNextAttemptAtUtc <= now))
            .OrderBy(x => x.CancellationNextAttemptAtUtc)
            .ThenBy(x => x.CancellationRequestedAtUtc)
            .Select(x => new PendingProviderCancellation(
                x.Id,
                x.CancellationAcceptedAtUtc != null))
            .FirstOrDefaultAsync(cancellationToken);
        if (pendingCancellation is null)
        {
            return false;
        }

        _ = pendingCancellation.ProviderAccepted
            ? await ReconcileAcceptedProviderCancellationAsync(
                pendingCancellation.GenerationId,
                cancellationToken)
            : await ProcessProviderCancellationAsync(
                pendingCancellation.GenerationId,
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
            if ((!ignoreSchedule || job.CancellationAcceptedAtUtc is not null)
                && job.CancellationNextAttemptAtUtc > now)
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
                var acceptedAtUtc = DateTime.UtcNow;
                settledJob.ProviderStatus = "CANCELLATION_REQUESTED";
                settledJob.CancellationAcceptedAtUtc ??= acceptedAtUtc;
                settledJob.CancellationLastErrorCode = null;
                settledJob.CancellationNextAttemptAtUtc = acceptedAtUtc.Add(
                    ResolveProviderCancellationRetryDelay(settledJob.CancellationAttemptCount));
                settledJob.UpdatedAtUtc = acceptedAtUtc;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                var acceptedResponse = await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken);
                await PublishCancellationStatusAsync(settledJob, cancellationToken, acceptedResponse);
                await WriteCancellationAuditAsync(
                    settledJob,
                    "admin.template_generation.cancellation_accepted",
                    settledJob.CancellationPreviousStatus?.ToString(),
                    settledJob.Status.ToString(),
                    "Provider acknowledged the cancellation request; terminal confirmation is still pending.",
                    cancellationToken);
                return Result.Success(new AdminGenerationCancellationResult(acceptedResponse, IsPending: true));

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

    private async Task<Result<AdminGenerationCancellationResult>> ReconcileAcceptedProviderCancellationAsync(
        Guid generationId,
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

            if (job.Status != TemplateGenerationStatus.CancellationRequested
                || job.CancellationAcceptedAtUtc is null)
            {
                if (claimTransaction is not null)
                {
                    await claimTransaction.CommitAsync(cancellationToken);
                }

                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: job.Status == TemplateGenerationStatus.CancellationRequested));
            }

            var now = DateTime.UtcNow;
            if (job.CancellationNextAttemptAtUtc > now)
            {
                if (claimTransaction is not null)
                {
                    await claimTransaction.CommitAsync(cancellationToken);
                }

                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: true));
            }

            target = ResolveProviderCancellationTarget(job)!;
            if (falQueueClient is null || target is null)
            {
                job.CancellationLastErrorCode = TemplatesErrors.GenerationCancelProviderUnsupported.Code;
                job.CancellationNextAttemptAtUtc = now.AddMinutes(5);
                job.UpdatedAtUtc = now;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (claimTransaction is not null)
                {
                    await claimTransaction.CommitAsync(cancellationToken);
                }

                return Result.Success(new AdminGenerationCancellationResult(
                    await MapResponseWithQueueMetricsAsync(job, cancellationToken),
                    IsPending: true));
            }

            job.CancellationLastAttemptedAtUtc = now;
            job.CancellationNextAttemptAtUtc = now.AddSeconds(ProviderCancellationLeaseSeconds);
            job.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            if (claimTransaction is not null)
            {
                await claimTransaction.CommitAsync(cancellationToken);
            }
        }

        var providerStatus = await falQueueClient!.GetStatusAsync(
            target.StatusUri,
            target.Model,
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

        if (settledJob.Status != TemplateGenerationStatus.CancellationRequested
            || settledJob.CancellationAcceptedAtUtc is null)
        {
            if (settleTransaction is not null)
            {
                await settleTransaction.CommitAsync(cancellationToken);
            }

            return Result.Success(new AdminGenerationCancellationResult(
                await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken),
                IsPending: settledJob.Status == TemplateGenerationStatus.CancellationRequested));
        }

        var settledAtUtc = DateTime.UtcNow;
        if (providerStatus.IsSuccess)
        {
            var normalizedStatus = providerStatus.Value.Status.Trim().ToUpperInvariant();
            settledJob.ProviderStatus = normalizedStatus;
            settledJob.ProviderStatusCheckedAtUtc = settledAtUtc;
            if (string.Equals(normalizedStatus, "COMPLETED", StringComparison.Ordinal))
            {
                await RestoreAfterRejectedCancellationAsync(
                    settledJob,
                    errorCode: null,
                    markGenerationError: false,
                    cancellationToken);
                settledJob.NextAttemptEarliestAtUtc = settledAtUtc;
                settledJob.UpdatedAtUtc = settledAtUtc;
                await dbContext.SaveChangesAsync(cancellationToken);
                if (settleTransaction is not null)
                {
                    await settleTransaction.CommitAsync(cancellationToken);
                }

                var completedResponse = await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken);
                await PublishCancellationStatusAsync(settledJob, cancellationToken, completedResponse);
                await WriteCancellationAuditAsync(
                    settledJob,
                    "admin.template_generation.cancellation_raced_completion",
                    TemplateGenerationStatus.CancellationRequested.ToString(),
                    settledJob.Status.ToString(),
                    "Provider completed before cancellation reached a terminal state; result reconciliation resumed without refund.",
                    cancellationToken);
                return Result.Success(new AdminGenerationCancellationResult(completedResponse, IsPending: false));
            }

            settledJob.CancellationLastErrorCode = normalizedStatus is "IN_QUEUE" or "IN_PROGRESS"
                ? null
                : "templates.provider_cancellation_status_unknown";
            settledJob.CancellationNextAttemptAtUtc = settledAtUtc.Add(
                ResolveProviderCancellationReconciliationDelay(settledJob.CancellationAcceptedAtUtc.Value, settledAtUtc));
            settledJob.UpdatedAtUtc = settledAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
            if (settleTransaction is not null)
            {
                await settleTransaction.CommitAsync(cancellationToken);
            }

            return Result.Success(new AdminGenerationCancellationResult(
                await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken),
                IsPending: true));
        }

        var providerRequestMissing = string.Equals(
            providerStatus.Error.Code,
            TemplatesErrors.AiProviderRequestNotFound.Code,
            StringComparison.Ordinal);
        if (providerRequestMissing
            && settledAtUtc - settledJob.CancellationAcceptedAtUtc.Value >= TimeSpan.FromSeconds(5))
        {
            settledJob.Status = TemplateGenerationStatus.Cancelled;
            settledJob.ProviderStatus = "CANCELLED";
            settledJob.ProviderStatusCheckedAtUtc = settledAtUtc;
            settledJob.CancelledAtUtc = settledAtUtc;
            settledJob.CompletedAtUtc = settledAtUtc;
            settledJob.CancellationNextAttemptAtUtc = null;
            settledJob.CancellationLastErrorCode = null;
            settledJob.LastErrorCode = null;
            settledJob.LastErrorMessage = null;
            settledJob.LockedAtUtc = null;
            settledJob.LockedBy = null;
            settledJob.UpdatedAtUtc = settledAtUtc;
            await MarkActiveProviderAttemptsCancelledAsync(settledJob.Id, settledAtUtc, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
            if (settleTransaction is not null)
            {
                await settleTransaction.CommitAsync(cancellationToken);
            }

            await RefundAcceptedProviderCancellationAsync(settledJob, cancellationToken);
            TemplateGenerationMetrics.RecordJobCancelled(settledJob);
            var cancelledResponse = await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken);
            await PublishCancellationStatusAsync(settledJob, cancellationToken, cancelledResponse);
            await WriteCancellationAuditAsync(
                settledJob,
                "admin.template_generation.cancelled",
                TemplateGenerationStatus.CancellationRequested.ToString(),
                settledJob.Status.ToString(),
                $"Provider cancellation reached a terminal not-found state. Refunded={settledJob.RefundedAtUtc is not null}.",
                cancellationToken);
            return Result.Success(new AdminGenerationCancellationResult(cancelledResponse, IsPending: false));
        }

        settledJob.CancellationLastErrorCode = AdminFailureMessageSanitizer.SanitizeCode(providerStatus.Error.Code);
        settledJob.CancellationNextAttemptAtUtc = settledAtUtc.Add(
            providerRequestMissing
                ? TimeSpan.FromSeconds(5)
                : IsProviderCancellationTransient(providerStatus.Error)
                    ? ResolveProviderCancellationReconciliationDelay(
                        settledJob.CancellationAcceptedAtUtc.Value,
                        settledAtUtc)
                    : TimeSpan.FromMinutes(5));
        settledJob.UpdatedAtUtc = settledAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (settleTransaction is not null)
        {
            await settleTransaction.CommitAsync(cancellationToken);
        }

        return Result.Success(new AdminGenerationCancellationResult(
            await MapResponseWithQueueMetricsAsync(settledJob, cancellationToken),
            IsPending: true));
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
        var statusUri = falQueueClient.ResolveStatusUri(model, requestId, statusUrl);
        return cancelUri is null || statusUri is null
            ? null
            : new ProviderCancellationTarget(model, requestId, statusUri, cancelUri);
    }

    private async Task<Result<AdminGenerationCancellationResult>> CancelVideoInterstageAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();
        await using var transaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken);
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

        if (!IsVideoInterstageCancellation(job))
        {
            return Result.Failure<AdminGenerationCancellationResult>(TemplatesErrors.GenerationCancelNotAllowed);
        }

        var previousStatus = job.Status;
        var now = DateTime.UtcNow;
        job.CancellationPreviousStatus = previousStatus;
        job.CancellationRequestedByAdminUserId = adminUserId;
        job.CancellationRequestedAtUtc ??= now;
        job.CancellationAcceptedAtUtc = now;
        job.CancellationNextAttemptAtUtc = null;
        job.CancellationLastErrorCode = null;
        job.Status = TemplateGenerationStatus.Cancelled;
        job.ProviderStatus = "CANCELLED_BETWEEN_STAGES";
        job.CancelledAtUtc = now;
        job.CompletedAtUtc = now;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.UpdatedAtUtc = now;
        await MarkActiveProviderAttemptsCancelledAsync(job.Id, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        await RefundAcceptedProviderCancellationAsync(job, cancellationToken);
        TemplateGenerationMetrics.RecordJobCancelled(job);
        var response = await MapResponseWithQueueMetricsAsync(job, cancellationToken);
        await PublishCancellationStatusAsync(job, cancellationToken, response);
        await WriteCancellationAuditAsync(
            job,
            "admin.template_generation.cancelled",
            previousStatus.ToString(),
            job.Status.ToString(),
            $"Generation cancelled locally between video preprocessing and motion submit. Refunded={job.RefundedAtUtc is not null}.",
            cancellationToken);
        return Result.Success(new AdminGenerationCancellationResult(response, IsPending: false));
    }

    private static bool IsVideoInterstageCancellation(TemplateGenerationJob job)
    {
        return job.Status == TemplateGenerationStatus.ProviderQueued
            && string.Equals(job.CurrentProviderStage, "video_preprocessing", StringComparison.Ordinal)
            && job.ProviderCompletedAtUtc is not null
            && !string.IsNullOrWhiteSpace(job.NormalizedImageUrl)
            && string.IsNullOrWhiteSpace(job.MotionProviderRequestId);
    }

    private async Task MarkActiveProviderAttemptsCancelledAsync(
        Guid generationId,
        DateTime cancelledAtUtc,
        CancellationToken cancellationToken)
    {
        var activeAttempts = dbContext.TemplateGenerationProviderAttempts
            .Where(x => x.GenerationJobId == generationId
                && (x.State == TemplateGenerationProviderAttemptState.SubmitReserved
                    || x.State == TemplateGenerationProviderAttemptState.Submitting
                    || x.State == TemplateGenerationProviderAttemptState.ProviderQueued
                    || x.State == TemplateGenerationProviderAttemptState.ProviderProcessing
                    || x.State == TemplateGenerationProviderAttemptState.SubmissionUnknown));
        if (string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            await activeAttempts.ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(x => x.State, TemplateGenerationProviderAttemptState.Cancelled)
                    .SetProperty(x => x.NextPollAtUtc, (DateTime?)null)
                    .SetProperty(x => x.CompletedAtUtc, cancelledAtUtc)
                    .SetProperty(x => x.LockedAtUtc, (DateTime?)null)
                    .SetProperty(x => x.LockedBy, (string?)null)
                    .SetProperty(x => x.UpdatedAtUtc, cancelledAtUtc)
                    .SetProperty(x => x.Version, x => x.Version + 1),
                cancellationToken);
            return;
        }

        foreach (var attempt in await activeAttempts.ToListAsync(cancellationToken))
        {
            attempt.State = TemplateGenerationProviderAttemptState.Cancelled;
            attempt.NextPollAtUtc = null;
            attempt.CompletedAtUtc = cancelledAtUtc;
            attempt.LockedAtUtc = null;
            attempt.LockedBy = null;
            attempt.UpdatedAtUtc = cancelledAtUtc;
            attempt.Version++;
        }
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

    private static TimeSpan ResolveProviderCancellationReconciliationDelay(
        DateTime acceptedAtUtc,
        DateTime nowUtc)
    {
        var elapsed = nowUtc - acceptedAtUtc;
        if (elapsed < TimeSpan.FromSeconds(30))
        {
            return TimeSpan.FromSeconds(5);
        }

        return elapsed < TimeSpan.FromMinutes(2)
            ? TimeSpan.FromSeconds(15)
            : TimeSpan.FromSeconds(30);
    }

    private static bool IsProviderCancellationTransient(Error error) =>
        string.Equals(error.Code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal)
        || string.Equals(error.Code, TemplatesErrors.AiProviderRateLimited.Code, StringComparison.Ordinal);

    private sealed record PendingProviderCancellation(Guid GenerationId, bool ProviderAccepted);

    private sealed record ProviderCancellationTarget(
        string Model,
        string RequestId,
        Uri StatusUri,
        Uri CancelUri);
}
