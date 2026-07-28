using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateRenderScaleOperationProcessor(
    TemplatesDbContext dbContext,
    IRenderGenerationWorkerClient renderClient,
    ITemplateGenerationRuntimeSettingsProvider runtimeSettings,
    ITemplateGenerationDrainController drainController,
    ILogger<TemplateRenderScaleOperationProcessor> logger)
{
    private const string RenderScaleFailedAlertCode = "render_scale_failed";
    private const string ProcessingFailedErrorCode = "templates.render.scale_processing_failed";
    private const string CurrentInstancesChangedErrorCode = "templates.render.current_instances_changed";
    private const string DesiredInstancesUnknownErrorCode = "templates.render.desired_instances_unknown";
    private const string DrainTimedOutErrorCode = "templates.render.drain_timed_out";
    private const string VerificationTimedOutErrorCode = "templates.render.verification_timed_out";

    private static readonly TimeSpan OperationLease = TimeSpan.FromMinutes(1);
    private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(5);
    private static readonly TimeSpan WorkerFreshness = TimeSpan.FromSeconds(90);
    private static readonly TimeSpan DrainTimeout = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan VerificationTimeout = TimeSpan.FromMinutes(20);
    private static readonly DateTime NoFurtherAttemptUtc = DateTime.SpecifyKind(DateTime.MaxValue, DateTimeKind.Utc);

    private static readonly string[] ActiveStatuses =
    [
        AdminGenerationRenderControlService.StatusRequested,
        AdminGenerationRenderControlService.StatusDraining,
        AdminGenerationRenderControlService.StatusScaling,
        AdminGenerationRenderControlService.StatusVerifying
    ];

    internal TimeProvider TimeProvider { get; init; } = TimeProvider.System;

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var now = UtcNow();
        var candidate = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .Where(operation => operation.NextAttemptAtUtc <= now)
            .Where(operation => operation.LockExpiresAtUtc == null || operation.LockExpiresAtUtc < now)
            .Where(operation => ActiveStatuses.Contains(operation.Status)
                || operation.Status == AdminGenerationRenderControlService.StatusCancelled
                || operation.Status == AdminGenerationRenderControlService.StatusFailed)
            .OrderBy(operation => operation.NextAttemptAtUtc)
            .ThenBy(operation => operation.CreatedAtUtc)
            .Select(operation => new { operation.Id, operation.Version })
            .FirstOrDefaultAsync(cancellationToken);
        if (candidate is null)
        {
            return false;
        }

        var lockId = Guid.NewGuid();
        var acquired = await dbContext.TemplateRenderScaleOperations
            .Where(operation => operation.Id == candidate.Id
                && operation.Version == candidate.Version
                && (operation.LockExpiresAtUtc == null || operation.LockExpiresAtUtc < now))
            .ExecuteUpdateAsync(setters => setters
                .SetProperty(operation => operation.LockId, lockId)
                .SetProperty(operation => operation.LockExpiresAtUtc, now.Add(OperationLease))
                .SetProperty(operation => operation.AttemptCount, operation => operation.AttemptCount + 1)
                .SetProperty(operation => operation.UpdatedAtUtc, now)
                .SetProperty(operation => operation.Version, operation => operation.Version + 1),
                cancellationToken);
        if (acquired == 0)
        {
            return false;
        }

        dbContext.ChangeTracker.Clear();
        var operation = await dbContext.TemplateRenderScaleOperations
            .SingleAsync(item => item.Id == candidate.Id && item.LockId == lockId, cancellationToken);

        try
        {
            await ProcessStepAsync(operation, now, cancellationToken);
            return true;
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            var latestStatus = await dbContext.TemplateRenderScaleOperations
                .AsNoTracking()
                .Where(item => item.Id == operation.Id)
                .Select(item => item.Status)
                .SingleOrDefaultAsync(cancellationToken);
            if (latestStatus is AdminGenerationRenderControlService.StatusCancelled
                or AdminGenerationRenderControlService.StatusFailed
                or AdminGenerationRenderControlService.StatusCompleted)
            {
                await ReleaseDrainIfOwnedAsync(operation.Id, cancellationToken);
            }

            logger.LogInformation(
                "Render scale operation step lost a concurrency race. OperationIdHash={OperationIdHash}",
                SafeLogValues.StableHash(operation.Id.ToString("D")));
            return true;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Render scale operation step failed. OperationIdHash={OperationIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(operation.Id.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            await FailAfterUnexpectedExceptionAsync(operation.Id, cancellationToken);
            return true;
        }
    }

    private async Task ProcessStepAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        switch (operation.Status)
        {
            case AdminGenerationRenderControlService.StatusRequested:
                await ProcessRequestedAsync(operation, now, cancellationToken);
                break;
            case AdminGenerationRenderControlService.StatusDraining:
                await ProcessDrainingAsync(operation, now, cancellationToken);
                break;
            case AdminGenerationRenderControlService.StatusScaling:
                await ProcessScalingAsync(operation, now, cancellationToken);
                break;
            case AdminGenerationRenderControlService.StatusVerifying:
                await ProcessVerifyingAsync(operation, now, cancellationToken);
                break;
            case AdminGenerationRenderControlService.StatusCancelled:
            case AdminGenerationRenderControlService.StatusFailed:
                await ProcessTerminalDrainCleanupAsync(operation, now, cancellationToken);
                break;
            default:
                await ReleaseLeaseAsync(operation, now, cancellationToken);
                break;
        }
    }

    private async Task ProcessRequestedAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var targetResult = await renderClient.GetTargetStatusAsync(cancellationToken);
        if (targetResult.IsFailure)
        {
            if (IsRetryableRenderError(targetResult.Error.Code))
            {
                operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(targetResult.Error.Code);
                operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(targetResult.Error.Message);
                await ScheduleRetryAsync(operation, now, cancellationToken);
            }
            else
            {
                await FailAsync(operation, targetResult.Error.Code, targetResult.Error.Message, now, cancellationToken);
            }

            return;
        }

        if (targetResult.Value.AutoscalingEnabled)
        {
            await FailAsync(
                operation,
                RenderGenerationWorkerErrors.AutoscalingEnabled.Code,
                RenderGenerationWorkerErrors.AutoscalingEnabled.Message,
                now,
                cancellationToken);
            return;
        }

        if (targetResult.Value.DesiredInstances is not int desiredInstances)
        {
            await FailAsync(
                operation,
                DesiredInstancesUnknownErrorCode,
                "Render did not report a manual desired instance count.",
                now,
                cancellationToken);
            return;
        }

        var instancesResult = await renderClient.ListInstancesAsync(cancellationToken);
        if (instancesResult.IsFailure)
        {
            if (IsRetryableRenderError(instancesResult.Error.Code))
            {
                operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(instancesResult.Error.Code);
                operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(instancesResult.Error.Message);
                await ScheduleRetryAsync(operation, now, cancellationToken);
            }
            else
            {
                await FailAsync(operation, instancesResult.Error.Code, instancesResult.Error.Message, now, cancellationToken);
            }

            return;
        }

        var observedInstances = instancesResult.Value.Count;
        if (operation.InitialInstances is int expectedInstances
            && (expectedInstances != desiredInstances || expectedInstances != observedInstances))
        {
            await FailAsync(
                operation,
                CurrentInstancesChangedErrorCode,
                $"Expected {expectedInstances} Render instances, but desired/observed topology is {desiredInstances}/{observedInstances}.",
                now,
                cancellationToken);
            return;
        }

        if (desiredInstances != observedInstances)
        {
            await FailAsync(
                operation,
                CurrentInstancesChangedErrorCode,
                $"Render desired/observed topology differs ({desiredInstances}/{observedInstances}).",
                now,
                cancellationToken);
            return;
        }

        operation.InitialInstances = observedInstances;
        if (operation.TargetInstances == observedInstances)
        {
            await CompleteAsync(operation, now, cancellationToken);
            return;
        }

        if (operation.TargetInstances < observedInstances)
        {
            operation.DrainStartedAtUtc = now;
            operation.VerificationDeadlineAtUtc = now.Add(DrainTimeout);
            await TransitionAsync(
                operation,
                AdminGenerationRenderControlService.StatusDraining,
                now,
                now,
                cancellationToken);
            return;
        }

        operation.VerificationDeadlineAtUtc = now.Add(VerificationTimeout);
        await TransitionAsync(
            operation,
            AdminGenerationRenderControlService.StatusScaling,
            now,
            now,
            cancellationToken);
    }

    private async Task ProcessDrainingAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (operation.VerificationDeadlineAtUtc is { } deadline && now >= deadline)
        {
            await FailAsync(
                operation,
                DrainTimedOutErrorCode,
                "Generation workers did not drain before the timeout.",
                now,
                cancellationToken);
            return;
        }

        if (operation.DrainRuntimeVersion is null)
        {
            await runtimeSettings.RefreshAsync(cancellationToken);
            var snapshot = runtimeSettings.Current;
            if (!snapshot.NewClaimsPaused || snapshot.DrainOperationId != operation.Id)
            {
                var paused = await drainController.TryPauseNewClaimsAsync(operation.Id, cancellationToken);
                await runtimeSettings.RefreshAsync(cancellationToken);
                snapshot = runtimeSettings.Current;
                if ((!paused && (!snapshot.NewClaimsPaused || snapshot.DrainOperationId != operation.Id))
                    || !snapshot.NewClaimsPaused
                    || snapshot.DrainOperationId != operation.Id)
                {
                    await FailAsync(
                        operation,
                        ProcessingFailedErrorCode,
                        "Generation claims could not be paused for Render scale down.",
                        now,
                        cancellationToken);
                    return;
                }
            }

            operation.DrainRuntimeVersion = snapshot.Version;
            await ScheduleRetryAsync(operation, now, cancellationToken);
            return;
        }

        if (operation.DrainRuntimeVersion is not long drainVersion
            || operation.InitialInstances is not int initialInstances)
        {
            await FailAsync(
                operation,
                ProcessingFailedErrorCode,
                "Render scale operation is missing persisted drain state.",
                now,
                cancellationToken);
            return;
        }

        var freshWorkers = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(fingerprint => fingerprint.Component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            .Where(fingerprint => fingerprint.LastSeenAtUtc >= now.Subtract(WorkerFreshness))
            .ToArrayAsync(cancellationToken);
        var allWorkersAppliedDrain = freshWorkers.Length >= initialInstances
            && freshWorkers.All(fingerprint => fingerprint.NewClaimsPaused
                && fingerprint.AppliedSettingsVersion >= drainVersion);
        if (!allWorkersAppliedDrain)
        {
            await ScheduleRetryAsync(operation, now, cancellationToken);
            return;
        }

        var hasProcessingJobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .AnyAsync(job => TemplateGenerationJobStatusSets.Processing.Contains(job.Status), cancellationToken);
        if (hasProcessingJobs)
        {
            await ScheduleRetryAsync(operation, now, cancellationToken);
            return;
        }

        operation.VerificationDeadlineAtUtc = now.Add(VerificationTimeout);
        await TransitionAsync(
            operation,
            AdminGenerationRenderControlService.StatusScaling,
            now,
            now,
            cancellationToken);
    }

    private async Task ProcessScalingAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (operation.VerificationDeadlineAtUtc is { } deadline && now >= deadline)
        {
            await FailAsync(
                operation,
                VerificationTimedOutErrorCode,
                "Render did not accept the requested scale before the timeout.",
                now,
                cancellationToken);
            return;
        }

        var scaleResult = await renderClient.ScaleAsync(operation.TargetInstances, cancellationToken);
        if (scaleResult.IsFailure)
        {
            if (IsRetryableRenderError(scaleResult.Error.Code))
            {
                operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(scaleResult.Error.Code);
                operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(scaleResult.Error.Message);
                await ScheduleRetryAsync(operation, now, cancellationToken);
                return;
            }

            await FailAsync(operation, scaleResult.Error.Code, scaleResult.Error.Message, now, cancellationToken);
            return;
        }

        operation.ScaleRequestedAtUtc ??= scaleResult.Value.AcceptedAtUtc;
        operation.ErrorCode = null;
        operation.ErrorMessage = null;
        await TransitionAsync(
            operation,
            AdminGenerationRenderControlService.StatusVerifying,
            now,
            now.Add(RetryDelay),
            cancellationToken);
    }

    private async Task ProcessVerifyingAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (operation.VerificationDeadlineAtUtc is { } deadline && now >= deadline)
        {
            await FailAsync(
                operation,
                VerificationTimedOutErrorCode,
                "Render did not reach the requested instance count before the timeout.",
                now,
                cancellationToken);
            return;
        }

        var targetResult = await renderClient.GetTargetStatusAsync(cancellationToken);
        if (targetResult.IsFailure)
        {
            if (IsRetryableRenderError(targetResult.Error.Code))
            {
                operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(targetResult.Error.Code);
                operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(targetResult.Error.Message);
                await ScheduleRetryAsync(operation, now, cancellationToken);
            }
            else
            {
                await FailAsync(operation, targetResult.Error.Code, targetResult.Error.Message, now, cancellationToken);
            }

            return;
        }

        if (targetResult.Value.AutoscalingEnabled)
        {
            await FailAsync(
                operation,
                RenderGenerationWorkerErrors.AutoscalingEnabled.Code,
                RenderGenerationWorkerErrors.AutoscalingEnabled.Message,
                now,
                cancellationToken);
            return;
        }

        var instancesResult = await renderClient.ListInstancesAsync(cancellationToken);
        if (instancesResult.IsFailure)
        {
            if (IsRetryableRenderError(instancesResult.Error.Code))
            {
                operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(instancesResult.Error.Code);
                operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(instancesResult.Error.Message);
                await ScheduleRetryAsync(operation, now, cancellationToken);
            }
            else
            {
                await FailAsync(operation, instancesResult.Error.Code, instancesResult.Error.Message, now, cancellationToken);
            }

            return;
        }

        if (targetResult.Value.DesiredInstances != operation.TargetInstances
            || instancesResult.Value.Count != operation.TargetInstances)
        {
            await ScheduleRetryAsync(operation, now, cancellationToken);
            return;
        }

        await CompleteAsync(operation, now, cancellationToken);
    }

    private async Task CompleteAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        if (!await ReleaseDrainIfOwnedAsync(operation.Id, cancellationToken))
        {
            await ScheduleRetryAsync(operation, now, cancellationToken);
            return;
        }

        var previousStatus = operation.Status;
        operation.Status = AdminGenerationRenderControlService.StatusCompleted;
        operation.CompletedAtUtc = now;
        operation.ErrorCode = null;
        operation.ErrorMessage = null;
        operation.NextAttemptAtUtc = NoFurtherAttemptUtc;
        ReleaseLease(operation, now);
        await ResolveScaleFailureAlertAsync(now, cancellationToken);
        TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            AdminGenerationRenderControlService.CreateAuditEntry(
                operation,
                "admin.templates.render_scale.completed",
                previousStatus,
                operation.Status,
                CreateDeterministicEventId(operation.Id, "completed"),
                now));
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task FailAsync(
        TemplateRenderScaleOperation operation,
        string? errorCode,
        string? errorMessage,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var previousStatus = operation.Status;
        var drainReleased = await ReleaseDrainIfOwnedAsync(operation.Id, cancellationToken);
        operation.Status = AdminGenerationRenderControlService.StatusFailed;
        operation.ErrorCode = AdminFailureMessageSanitizer.SanitizeCode(errorCode) ?? ProcessingFailedErrorCode;
        operation.ErrorMessage = AdminFailureMessageSanitizer.Sanitize(errorMessage) ?? "Render scale operation failed.";
        operation.NextAttemptAtUtc = drainReleased ? NoFurtherAttemptUtc : now.Add(RetryDelay);
        ReleaseLease(operation, now);
        await ActivateScaleFailureAlertAsync(operation, now, cancellationToken);
        TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            AdminGenerationRenderControlService.CreateAuditEntry(
                operation,
                "admin.templates.render_scale.failed",
                previousStatus,
                operation.Status,
                CreateDeterministicEventId(operation.Id, "failed"),
                now,
                $"reason={operation.Reason};targetInstances={operation.TargetInstances};errorCode={operation.ErrorCode}"));
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task FailAfterUnexpectedExceptionAsync(Guid operationId, CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();
        var operation = await dbContext.TemplateRenderScaleOperations
            .SingleOrDefaultAsync(item => item.Id == operationId, cancellationToken);
        if (operation is null
            || operation.Status is AdminGenerationRenderControlService.StatusCompleted
                or AdminGenerationRenderControlService.StatusCancelled)
        {
            await ReleaseDrainIfOwnedAsync(operationId, cancellationToken);
            return;
        }

        await FailAsync(
            operation,
            ProcessingFailedErrorCode,
            "Render scale operation failed unexpectedly.",
            UtcNow(),
            cancellationToken);
    }

    private async Task ProcessTerminalDrainCleanupAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var released = await ReleaseDrainIfOwnedAsync(operation.Id, cancellationToken);
        operation.NextAttemptAtUtc = released ? NoFurtherAttemptUtc : now.Add(RetryDelay);
        ReleaseLease(operation, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task<bool> ReleaseDrainIfOwnedAsync(Guid operationId, CancellationToken cancellationToken)
    {
        await runtimeSettings.RefreshAsync(cancellationToken);
        var current = runtimeSettings.Current;
        if (!current.NewClaimsPaused || current.DrainOperationId != operationId)
        {
            return true;
        }

        try
        {
            if (await drainController.TryResumeNewClaimsAsync(operationId, cancellationToken))
            {
                return true;
            }

            await runtimeSettings.RefreshAsync(cancellationToken);
            current = runtimeSettings.Current;
            return !current.NewClaimsPaused || current.DrainOperationId != operationId;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Generation drain release failed for a Render scale operation. OperationIdHash={OperationIdHash} ExceptionType={ExceptionType}",
                SafeLogValues.StableHash(operationId.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            return false;
        }
    }

    private async Task ActivateScaleFailureAlertAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var alert = await dbContext.TemplateGenerationOperationalAlerts
            .SingleOrDefaultAsync(item => item.Code == RenderScaleFailedAlertCode, cancellationToken);
        var message = $"Render generation-worker scaling to {operation.TargetInstances} instances failed ({operation.ErrorCode}).";
        if (alert is null)
        {
            dbContext.TemplateGenerationOperationalAlerts.Add(new TemplateGenerationOperationalAlert
            {
                Id = Guid.NewGuid(),
                Code = RenderScaleFailedAlertCode,
                Severity = "critical",
                Title = "Render generation worker scale failed",
                Message = message,
                ActivatedAtUtc = now,
                LastObservedAtUtc = now,
                UpdatedAtUtc = now
            });
            return;
        }

        if (alert.ResolvedAtUtc is not null)
        {
            alert.ActivatedAtUtc = now;
            alert.ResolvedAtUtc = null;
            dbContext.TemplateGenerationOperationalAlertAcknowledgements.RemoveRange(
                await dbContext.TemplateGenerationOperationalAlertAcknowledgements
                    .Where(item => item.AlertId == alert.Id)
                    .ToArrayAsync(cancellationToken));
        }

        alert.Severity = "critical";
        alert.Title = "Render generation worker scale failed";
        alert.Message = message;
        alert.LastObservedAtUtc = now;
        alert.UpdatedAtUtc = now;
    }

    private async Task ResolveScaleFailureAlertAsync(DateTime now, CancellationToken cancellationToken)
    {
        var alert = await dbContext.TemplateGenerationOperationalAlerts
            .SingleOrDefaultAsync(
                item => item.Code == RenderScaleFailedAlertCode && item.ResolvedAtUtc == null,
                cancellationToken);
        if (alert is null)
        {
            return;
        }

        alert.ResolvedAtUtc = now;
        alert.UpdatedAtUtc = now;
    }

    private async Task TransitionAsync(
        TemplateRenderScaleOperation operation,
        string status,
        DateTime now,
        DateTime nextAttemptAtUtc,
        CancellationToken cancellationToken)
    {
        operation.Status = status;
        operation.NextAttemptAtUtc = nextAttemptAtUtc;
        ReleaseLease(operation, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task ScheduleRetryAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        operation.NextAttemptAtUtc = now.Add(RetryDelay);
        ReleaseLease(operation, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task ReleaseLeaseAsync(
        TemplateRenderScaleOperation operation,
        DateTime now,
        CancellationToken cancellationToken)
    {
        ReleaseLease(operation, now);
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private static void ReleaseLease(TemplateRenderScaleOperation operation, DateTime now)
    {
        operation.LockId = null;
        operation.LockExpiresAtUtc = null;
        operation.UpdatedAtUtc = now;
        operation.Version++;
    }

    private static bool IsRetryableRenderError(string? errorCode) => errorCode is
        "templates.render.rate_limited" or "templates.render.upstream_unavailable";

    private DateTime UtcNow() => TimeProvider.GetUtcNow().UtcDateTime;

    private static Guid CreateDeterministicEventId(Guid operationId, string phase)
    {
        var payload = Encoding.UTF8.GetBytes($"{operationId:D}:{phase}");
        var hash = SHA256.HashData(payload);
        return new Guid(hash.AsSpan(0, 16));
    }
}
