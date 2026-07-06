using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";

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

    public async Task<Result<TemplateGenerationResponse>> CancelAdminQueuedAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        if (!options.CancelQueuedGenerationEnabled)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationCancelDisabled);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.HiddenByUserAtUtc == null, cancellationToken);
        if (job is null)
        {
            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        var cancelled = await CancelQueuedJobAsync(job, adminUserId, cancellationToken);
        return cancelled.IsFailure
            ? Result.Failure<TemplateGenerationResponse>(cancelled.Error)
            : Result.Success(cancelled.Value.Response);
    }

    public async Task<Result<TemplateGenerationResponse>> RetryAdminGenerationAsync(
        Guid adminUserId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await LockGenerationRowForAdminActionAsync(generationId, cancellationToken);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(x => x.Id == generationId && x.HiddenByUserAtUtc == null, cancellationToken);
        if (job is null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (!CanAdminRetryGeneration(job))
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationRetryNotAllowed);
        }

        var previousStatus = job.Status;
        var now = DateTime.UtcNow;
        ResetAdminRetryState(job, now);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        TemplateGenerationMetrics.RecordJobRequeued(job);
        TemplateGenerationMetrics.RecordRetryAttempt(job, "admin_manual");
        var response = await MapResponseWithQueueMetricsAsync(job, cancellationToken);
        if (realtimeService is not null)
        {
            await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
        }

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    "admin.templates.generation.retry",
                    "TemplateGenerationJob",
                    job.Id.ToString(),
                    previousStatus.ToString(),
                    job.Status.ToString(),
                    $"tokenCost={job.TokenCost};chargedAtUtc={job.ChargedAtUtc:O};attemptBudgetReset=true",
                    adminUserId),
                cancellationToken);
        }

        logger?.LogWarning(
            "ADMIN ACTION: generation retry queued. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} UserIdHash={UserIdHash} PreviousStatus={PreviousStatus} TokenCost={TokenCost} CorrelationIdHash={CorrelationIdHash}",
            TemplateLogSanitizer.SafeId(adminUserId),
            TemplateLogSanitizer.SafeId(job.Id),
            TemplateLogSanitizer.SafeId(job.UserId),
            previousStatus,
            job.TokenCost,
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

        return Result.Success(response);
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
            "ADMIN ACTION: generation refund retry re-armed. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} UserIdHash={UserIdHash} TokenCost={TokenCost} CorrelationIdHash={CorrelationIdHash}",
            TemplateLogSanitizer.SafeId(adminUserId),
            TemplateLogSanitizer.SafeId(job.Id),
            TemplateLogSanitizer.SafeId(job.UserId),
            job.TokenCost,
            SafeLogValues.StableHash(CorrelationContext.ResolveOrCreate()));

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    private async Task<IDbContextTransaction?> BeginGenerationAdminActionTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await dbContext.Database.BeginTransactionAsync(cancellationToken)
            : null;
    }

    private async Task LockGenerationRowForAdminActionAsync(Guid generationId, CancellationToken cancellationToken)
    {
        await dbContext.Database.SqlQueryRaw<Guid>(
            """
            SELECT "Id" AS "Value"
            FROM templates_generation_jobs
            WHERE "Id" = {0}
            FOR UPDATE
            """,
            generationId)
            .ToListAsync(cancellationToken);
    }

    private static bool CanAdminRetryGeneration(TemplateGenerationJob job)
    {
        var canReuseCharge = job.UserId == AdminTestUserId
            || (job.ChargedAtUtc is not null && job.RefundedAtUtc is null);
        return job.Status is TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled
            && canReuseCharge;
    }

    private static void ResetAdminRetryState(TemplateGenerationJob job, DateTime now)
    {
        job.Status = TemplateGenerationStatus.Queued;
        job.AttemptCount = 0;
        job.LastAttemptAtUtc = null;
        job.StartedAtUtc = null;
        job.CompletedAtUtc = null;
        job.CancelledAtUtc = null;
        job.QueuedAtUtc = now;
        job.UpdatedAtUtc = now;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        job.NextAttemptEarliestAtUtc = null;
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.ResultMediaAssetId = null;
        job.IsWatermarkRequired = false;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.PreprocessingProviderRequestId = null;
        job.PreprocessingProviderStatusUrl = null;
        job.PreprocessingProviderResponseUrl = null;
        job.PreprocessingInferenceTimeSeconds = null;
        job.PreprocessingCompletedAtUtc = null;
        job.MotionProviderRequestId = null;
        job.MotionProviderStatusUrl = null;
        job.MotionProviderResponseUrl = null;
        job.MotionInferenceTimeSeconds = null;
        job.MotionGenerationCompletedAtUtc = null;
        job.CurrentProviderStage = null;
        job.ProviderStatus = null;
        job.ProviderResultUrl = null;
        job.ProviderSubmittedAtUtc = null;
        job.ProviderStatusCheckedAtUtc = null;
        job.ProviderCompletedAtUtc = null;
        job.WebhookReceivedAtUtc = null;
        job.ImportStartedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.OutputVideoDurationSeconds = null;
        job.MotionProviderCostUsd = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.RefundAttemptCount = 0;
        job.RefundLastAttemptedAtUtc = null;
        job.RefundLastErrorCode = null;
    }
}
