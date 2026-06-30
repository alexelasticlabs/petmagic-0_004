using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private async Task<bool> RecoverNextStaleProcessingJobAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var staleThreshold = now.AddMilliseconds(-options.JobLockTimeoutMilliseconds);
        var staleJob = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.LockedAtUtc != null
                && x.LockedAtUtc <= staleThreshold)
            .OrderBy(x => x.LockedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (staleJob is null)
        {
            return false;
        }

        if (staleJob.AttemptCount >= options.MaxGenerationAttempts)
        {
            if (await MarkFailedAsync(staleJob, TemplatesErrors.GenerationAttemptsExceeded, cancellationToken, requireClaim: false))
            {
                TemplateGenerationMetrics.RecordJobExhausted(staleJob, TemplatesErrors.GenerationAttemptsExceeded.Code);
            }

            return true;
        }

        var recoveryStartedAt = System.Diagnostics.Stopwatch.GetTimestamp();
        MarkQueuedForRecovery(staleJob, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobRequeued(staleJob);
            var correlationId = ResolveJobCorrelationId(staleJob);
            using (CorrelationContext.Push(correlationId))
            using (BeginJobScope(staleJob, correlationId))
            {
                logger.LogWarning(
                    "Stale template generation job recovered for retry. ElapsedMs={ElapsedMs}",
                    ElapsedMsSince(recoveryStartedAt));
            }

            dbContext.ChangeTracker.Clear();
        }
        catch (DbUpdateConcurrencyException exception)
        {
            using var staleJobScope = BeginJobScope(staleJob, ResolveJobCorrelationId(staleJob));
            logger.LogWarning(
                exception,
                "Stale template generation job recovery was skipped because its lock changed. ElapsedMs={ElapsedMs}",
                ElapsedMsSince(recoveryStartedAt));
            dbContext.ChangeTracker.Clear();
        }

        return true;
    }

    private Task<TemplateGenerationJob?> ClaimNextAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? ClaimNextPostgresAsync(cancellationToken)
            : ClaimNextTrackedAsync(cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextPostgresAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var claimedIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE templates_generation_jobs
            SET "Status" = {1},
                "AttemptCount" = "AttemptCount" + 1,
                "LastAttemptAtUtc" = {2},
                "StartedAtUtc" = COALESCE("StartedAtUtc", {2}),
                "LockedAtUtc" = {2},
                "LockedBy" = {5},
                "UpdatedAtUtc" = {2},
                "NormalizedImageUrl" = NULL,
                "ResultUrl" = NULL,
                "WatermarkedResultUrl" = NULL,
                "IsWatermarkRequired" = FALSE,
                "IsWatermarkRemoved" = FALSE,
                "WatermarkFailureCode" = NULL,
                "UsedPreprocessingModel" = NULL,
                "UsedKlingModel" = NULL,
                "PreprocessingProviderRequestId" = NULL,
                "PreprocessingInferenceTimeSeconds" = NULL,
                "MotionProviderRequestId" = NULL,
                "MotionInferenceTimeSeconds" = NULL,
                "OutputVideoDurationSeconds" = NULL,
                "MotionProviderCostUsd" = NULL,
                "PreprocessingCompletedAtUtc" = NULL,
                "MotionGenerationCompletedAtUtc" = NULL,
                "MediaImportCompletedAtUtc" = NULL,
                "LastErrorCode" = NULL,
                "LastErrorMessage" = NULL
            WHERE "Id" = (
                SELECT "Id"
                FROM templates_generation_jobs
                WHERE "Status" = {0} AND ("ChargedAtUtc" IS NOT NULL OR "UserId" = {4}) AND "AttemptCount" < {3}
                ORDER BY "QueuedAtUtc"
                FOR UPDATE SKIP LOCKED
                LIMIT 1
            )
            RETURNING "Id" AS "Value"
            """,
            (int)TemplateGenerationStatus.Queued,
            (int)TemplateGenerationStatus.Processing,
            now,
            options.MaxGenerationAttempts,
            TemplateGenerationService.AdminTestUserId,
            WorkerInstanceId)
            .ToListAsync(cancellationToken);

        var claimedId = claimedIds.FirstOrDefault();
        if (claimedId == Guid.Empty)
        {
            return null;
        }

        return await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .SingleAsync(x => x.Id == claimedId, cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextTrackedAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.AttemptCount < options.MaxGenerationAttempts)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return null;
        }

        MarkProcessing(job, DateTime.UtcNow);
        await dbContext.SaveChangesAsync(cancellationToken);
        return job;
    }

    private static void MarkProcessing(TemplateGenerationJob job, DateTime now)
    {
        job.Status = TemplateGenerationStatus.Processing;
        job.AttemptCount++;
        job.LastAttemptAtUtc = now;
        job.StartedAtUtc ??= now;
        job.LockedAtUtc = now;
        job.LockedBy = WorkerInstanceId;
        job.UpdatedAtUtc = now;
        ResetAttemptState(job);
    }

    private static void MarkQueuedForRecovery(TemplateGenerationJob job, DateTime now)
    {
        job.Status = TemplateGenerationStatus.Queued;
        job.QueuedAtUtc = now;
        job.UpdatedAtUtc = now;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        ResetAttemptState(job);
    }

    private static void ResetAttemptState(TemplateGenerationJob job)
    {
        job.NormalizedImageUrl = null;
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.IsWatermarkRequired = false;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.UsedPreprocessingModel = null;
        job.UsedKlingModel = null;
        job.PreprocessingProviderRequestId = null;
        job.PreprocessingInferenceTimeSeconds = null;
        job.MotionProviderRequestId = null;
        job.MotionInferenceTimeSeconds = null;
        job.OutputVideoDurationSeconds = null;
        job.MotionProviderCostUsd = null;
        job.PreprocessingCompletedAtUtc = null;
        job.MotionGenerationCompletedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.CompletedAtUtc = null;
    }

    private async Task<bool> FailNextExhaustedQueuedJobAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.AttemptCount >= options.MaxGenerationAttempts)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        if (await MarkFailedAsync(job, TemplatesErrors.GenerationAttemptsExceeded, cancellationToken, requireClaim: false))
        {
            TemplateGenerationMetrics.RecordJobExhausted(job, TemplatesErrors.GenerationAttemptsExceeded.Code);
        }

        return true;
    }

    private async Task<GlobalConcurrencyLease?> TryAcquireGlobalConcurrencyLeaseAsync(CancellationToken cancellationToken)
    {
        var maxConcurrentGenerations = options.GlobalMaxConcurrentGenerations;
        if (maxConcurrentGenerations <= 0)
        {
            return GlobalConcurrencyLease.Noop;
        }

        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await TryAcquirePostgresConcurrencyLeaseAsync(maxConcurrentGenerations, cancellationToken)
            : TryAcquireLocalConcurrencyLease(maxConcurrentGenerations);
    }

    private async Task<GlobalConcurrencyLease?> TryAcquirePostgresConcurrencyLeaseAsync(
        int maxConcurrentGenerations,
        CancellationToken cancellationToken)
    {
        await dbContext.Database.OpenConnectionAsync(cancellationToken);
        for (var slot = 1; slot <= maxConcurrentGenerations; slot++)
        {
            var acquired = await dbContext.Database.SqlQueryRaw<bool>(
                """
                SELECT pg_try_advisory_lock({0}, {1}) AS "Value"
                """,
                GlobalGenerationAdvisoryLockKey,
                slot)
                .SingleAsync(cancellationToken);

            if (acquired)
            {
                return new GlobalConcurrencyLease(dbContext, slot);
            }
        }

        await dbContext.Database.CloseConnectionAsync();
        return null;
    }

    private GlobalConcurrencyLease? TryAcquireLocalConcurrencyLease(int maxConcurrentGenerations)
    {
        lock (LocalConcurrencyLock)
        {
            for (var slot = 1; slot <= maxConcurrentGenerations; slot++)
            {
                if (!LocalConcurrencySlots.Add(slot))
                {
                    continue;
                }

                return new GlobalConcurrencyLease(slot);
            }
        }

        return null;
    }

    private sealed class GlobalConcurrencyLease : IAsyncDisposable
    {
        public static readonly GlobalConcurrencyLease Noop = new();

        private readonly TemplatesDbContext? dbContext;
        private readonly int? slot;
        private readonly bool postgres;

        private GlobalConcurrencyLease()
        {
        }

        public GlobalConcurrencyLease(TemplatesDbContext dbContext, int slot)
        {
            this.dbContext = dbContext;
            this.slot = slot;
            postgres = true;
        }

        public GlobalConcurrencyLease(int slot)
        {
            this.slot = slot;
        }

        public async ValueTask DisposeAsync()
        {
            if (slot is null)
            {
                return;
            }

            if (postgres && dbContext is not null)
            {
                try
                {
                    await dbContext.Database.SqlQueryRaw<bool>(
                        """
                        SELECT pg_advisory_unlock({0}, {1}) AS "Value"
                        """,
                        GlobalGenerationAdvisoryLockKey,
                        slot.Value)
                        .SingleAsync();
                }
                finally
                {
                    await dbContext.Database.CloseConnectionAsync();
                }

                return;
            }

            lock (LocalConcurrencyLock)
            {
                LocalConcurrencySlots.Remove(slot.Value);
            }
        }
    }
}
