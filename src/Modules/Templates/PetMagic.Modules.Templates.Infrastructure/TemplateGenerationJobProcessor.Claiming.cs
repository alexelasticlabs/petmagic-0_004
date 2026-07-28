using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private async Task<SchedulerClaimGate> AcquireSchedulerClaimGateAsync(CancellationToken cancellationToken)
    {
        if (!string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            await LocalSchedulerClaimGate.WaitAsync(cancellationToken);
            return new SchedulerClaimGate(LocalSchedulerClaimGate);
        }

        var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        try
        {
            await dbContext.Database.ExecuteSqlInterpolatedAsync(
                $"SELECT pg_advisory_xact_lock({GlobalGenerationAdvisoryLockKey}, {SchedulerClaimAdvisoryLockSlot})",
                cancellationToken);
            return new SchedulerClaimGate(transaction);
        }
        catch
        {
            await transaction.DisposeAsync();
            throw;
        }
    }

    private async Task<bool> RecoverNextStaleProcessingJobAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var staleThreshold = now.AddMilliseconds(-options.JobLockTimeoutMilliseconds);
        var staleJob = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
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
        if (staleJob.ProviderCompletedAtUtc is not null
            && !string.IsNullOrWhiteSpace(staleJob.ProviderResultUrl))
        {
            staleJob.Status = TemplateGenerationStatus.ImportingMedia;
            staleJob.ImportStartedAtUtc ??= now;
            staleJob.UpdatedAtUtc = now;
            staleJob.LockedAtUtc = null;
            staleJob.LockedBy = null;
            staleJob.LastErrorCode = null;
            staleJob.LastErrorMessage = null;
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobRequeued(staleJob);
            logger.LogWarning(
                "Stale provider-completed template generation job recovered into media import. GenerationIdHash={GenerationIdHash} ProviderCompletedAtUtc={ProviderCompletedAtUtc}",
                TemplateLogSanitizer.SafeId(staleJob.Id),
                staleJob.ProviderCompletedAtUtc);
            dbContext.ChangeTracker.Clear();
            return true;
        }

        if (HasProviderRequestId(staleJob))
        {
            logger.LogWarning(
                "Stale template generation job has a saved provider request id; retry keeps provider identifiers for provider-state reconciliation. PreprocessingProviderRequestIdHash={PreprocessingProviderRequestIdHash} MotionProviderRequestIdHash={MotionProviderRequestIdHash}",
                SafeLogValues.StableHash(staleJob.PreprocessingProviderRequestId),
                SafeLogValues.StableHash(staleJob.MotionProviderRequestId));
        }
        else
        {
            logger.LogWarning(
                "Stale template generation job has no saved provider request id; retry may need a new provider submission because the current fal queue client only persists request ids after provider completion.");
        }
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
                "Stale template generation job recovery was skipped because its lock changed. ElapsedMs={ElapsedMs} ExceptionType={ExceptionType}",
                ElapsedMsSince(recoveryStartedAt),
                SafeLogValues.ExceptionType(exception));
            dbContext.ChangeTracker.Clear();
        }

        return true;
    }

    private Task<TemplateGenerationJob?> ClaimNextAsync(
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? ClaimNextPostgresAsync(allowImage, allowNativeVideo, allowBorrowedVideo, cancellationToken)
            : ClaimNextTrackedAsync(allowImage, allowNativeVideo, allowBorrowedVideo, cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextPostgresAsync(
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var borrowAdmin = IsBorrowingTierAllowed(TemplateGenerationQueue.TierAdmin);
        var borrowPrivileged = IsBorrowingTierAllowed(TemplateGenerationQueue.TierPrivileged);
        var borrowPremium = IsBorrowingTierAllowed(TemplateGenerationQueue.TierPremium);
        var borrowFree = IsBorrowingTierAllowed(TemplateGenerationQueue.TierFree);
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
                "NextAttemptEarliestAtUtc" = NULL,
                "ResultUrl" = NULL,
                "WatermarkedResultUrl" = NULL,
                "IsWatermarkRequired" = FALSE,
                "IsWatermarkRemoved" = FALSE,
                "WatermarkFailureCode" = NULL,
                "OutputVideoDurationSeconds" = NULL,
                "MotionProviderCostUsd" = NULL,
                "MotionGenerationCompletedAtUtc" = NULL,
                "MediaImportCompletedAtUtc" = NULL,
                "LastErrorCode" = NULL,
                "LastErrorMessage" = NULL
            WHERE "Id" = (
                SELECT "Id"
                FROM templates_generation_jobs
                WHERE "Status" = {0}
                    AND "InputSourceType" <> 'qa_fixture'
                    AND ("ChargedAtUtc" IS NOT NULL OR "UserId" = {4})
                    AND "AttemptCount" < {3}
                    AND ("NextAttemptEarliestAtUtc" IS NULL OR "NextAttemptEarliestAtUtc" <= {2})
                    AND (
                        ({6} AND "QueueMediaType" = 'image')
                        OR ("QueueMediaType" = 'video' AND (
                            {7}
                            OR ({8} AND (
                                ("QueueTier" = 'admin' AND {9})
                                OR ("QueueTier" = 'privileged' AND {10})
                                OR ("QueueTier" = 'premium' AND {11})
                                OR ("QueueTier" = 'free' AND {12})
                            ))
                        ))
                    )
                ORDER BY (
                    CASE "QueueTier"
                        WHEN 'admin' THEN {13}
                        WHEN 'privileged' THEN {14}
                        WHEN 'premium' THEN {15}
                        ELSE {16}
                    END
                    + FLOOR(GREATEST(0, EXTRACT(EPOCH FROM ({2} - "QueuedAtUtc"))) / {17})::int * {18}
                ) DESC,
                "QueuedAtUtc",
                "Id"
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
            WorkerInstanceId,
            allowImage,
            allowNativeVideo,
            allowBorrowedVideo,
            borrowAdmin,
            borrowPrivileged,
            borrowPremium,
            borrowFree,
            options.AdminQueuePriorityScore,
            options.PrivilegedQueuePriorityScore,
            options.PremiumQueuePriorityScore,
            options.FreeQueuePriorityScore,
            options.QueuePriorityAgingIntervalSeconds,
            options.QueuePriorityAgingBoost)
            .ToListAsync(cancellationToken);

        var claimedId = claimedIds.FirstOrDefault();
        if (claimedId == Guid.Empty)
        {
            return null;
        }

        dbContext.ChangeTracker.Clear();
        var claimedJob = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .SingleAsync(x => x.Id == claimedId, cancellationToken);
        dbContext.Entry(claimedJob).Property(x => x.LockedBy).OriginalValue = claimedJob.LockedBy;
        return claimedJob;
    }

    private async Task<TemplateGenerationJob?> ClaimNextTrackedAsync(
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var candidates = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.AttemptCount < options.MaxGenerationAttempts
                && (x.NextAttemptEarliestAtUtc == null || x.NextAttemptEarliestAtUtc <= now)
                && ((allowImage && x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage)
                    || (x.QueueMediaType == TemplateGenerationQueue.MediaTypeVideo
                        && (allowNativeVideo
                            || (allowBorrowedVideo && IsBorrowingTierAllowed(x.QueueTier))))))
            .ToArrayAsync(cancellationToken);

        var job = candidates
            .OrderByDescending(x => TemplateGenerationQueue.ResolvePriorityScore(x, now, options))
            .ThenBy(x => x.QueuedAtUtc)
            .ThenBy(x => x.Id)
            .FirstOrDefault();

        if (job is null)
        {
            return null;
        }

        MarkProcessing(job, DateTime.UtcNow);
        await dbContext.SaveChangesAsync(cancellationToken);
        if (job.AttemptCount > 1)
        {
            TemplateGenerationMetrics.RecordRetryAttempt(job, "claim_retry");
        }

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
        job.NextAttemptEarliestAtUtc = null;
        ResetAttemptState(job);
    }

    private static void MarkQueuedForRecovery(TemplateGenerationJob job, DateTime now)
    {
        job.Status = HasProviderRequestId(job)
            ? TemplateGenerationStatus.ProviderQueued
            : TemplateGenerationStatus.Queued;
        if (HasProviderRequestId(job) && string.IsNullOrWhiteSpace(job.CurrentProviderStage))
        {
            job.CurrentProviderStage = !string.IsNullOrWhiteSpace(job.MotionProviderRequestId)
                ? ProviderStageVideoGeneration
                : job.Template?.TemplateType == TemplateType.Video && string.IsNullOrWhiteSpace(job.NormalizedImageUrl)
                    ? ProviderStageVideoPreprocessing
                    : ProviderStageImageGeneration;
        }

        job.QueuedAtUtc = now;
        job.UpdatedAtUtc = now;
        job.ProviderStatusCheckedAtUtc = null;
        job.LockedAtUtc = null;
        job.LockedBy = null;
        ResetAttemptState(job);
    }

    private static void ResetAttemptState(TemplateGenerationJob job)
    {
        job.ResultUrl = null;
        job.WatermarkedResultUrl = null;
        job.IsWatermarkRequired = false;
        job.IsWatermarkRemoved = false;
        job.WatermarkFailureCode = null;
        job.PreprocessingInferenceTimeSeconds = null;
        job.MotionInferenceTimeSeconds = null;
        job.OutputVideoDurationSeconds = null;
        job.MotionProviderCostUsd = null;
        job.MotionGenerationCompletedAtUtc = null;
        job.MediaImportCompletedAtUtc = null;
        job.LastErrorCode = null;
        job.LastErrorMessage = null;
        job.CompletedAtUtc = null;
    }

    private async Task<bool> FailNextOrphanQueuedJobAsync(CancellationToken cancellationToken)
    {
        var cutoff = DateTime.UtcNow.AddMilliseconds(-Math.Max(1, options.OrphanQueuedJobTimeoutMilliseconds));
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
                && x.UserId != TemplateGenerationService.AdminTestUserId
                && x.ChargedAtUtc == null
                && x.QueuedAtUtc <= cutoff)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        var previousStatus = job.Status;
        job.Status = TemplateGenerationStatus.Failed;
        job.LastErrorCode = TemplatesErrors.GenerationQueueOrphaned.Code;
        job.LastErrorMessage = TemplatesErrors.GenerationQueueOrphaned.Message;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordQueuedWithoutCharge(job);
        TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, TemplatesErrors.GenerationQueueOrphaned.Code);
        logger.LogWarning(
            "Orphan queued template generation job failed because it was never charged. GenerationIdHash={GenerationIdHash} QueuedAtUtc={QueuedAtUtc}",
            TemplateLogSanitizer.SafeId(job.Id),
            job.QueuedAtUtc);
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private static bool HasProviderRequestId(TemplateGenerationJob job)
    {
        return !string.IsNullOrWhiteSpace(job.PreprocessingProviderRequestId)
            || !string.IsNullOrWhiteSpace(job.MotionProviderRequestId);
    }

    /// <summary>
    /// Requeues a claimed job after a transient provider submit failure (429/5xx/timeout/network).
    /// The job returns to Queued with an exponential claim delay instead of terminally failing,
    /// so a temporary fal.ai outage does not turn into a wave of failed jobs and refunds.
    /// </summary>
    private async Task<bool> RequeueForTransientSubmitFailureAsync(
        TemplateGenerationJob job,
        PetMagic.BuildingBlocks.Results.Error error,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var backoffExponent = Math.Clamp(job.AttemptCount - 1, 0, 5);
        var delaySeconds = options.ProviderTransientRetryBaseDelaySeconds * (1 << backoffExponent);
        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(error.Code)
            ?? TemplatesErrors.AiProviderTransientFailure.Code;
        var safeErrorMessage = AdminFailureMessageSanitizer.Sanitize(error.Message);

        job.Status = TemplateGenerationStatus.Queued;
        job.CurrentProviderStage = null;
        job.ProviderStatus = null;
        job.ProviderSubmittedAtUtc = null;
        job.ProviderStatusCheckedAtUtc = null;
        job.NextAttemptEarliestAtUtc = now.AddSeconds(delaySeconds);
        job.LastErrorCode = safeErrorCode;
        job.LastErrorMessage = safeErrorMessage;
        job.UpdatedAtUtc = now;
        job.LockedAtUtc = null;
        job.LockedBy = null;

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException exception)
        {
            logger.LogWarning(
                "Transient provider failure requeue was skipped because the job lock changed. GenerationIdHash={GenerationIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.Id),
                SafeLogValues.ExceptionType(exception));
            dbContext.ChangeTracker.Clear();
            return true;
        }

        TemplateGenerationMetrics.RecordRetryAttempt(job, "provider_transient");
        logger.LogWarning(
            "Template generation job requeued after transient provider failure. GenerationIdHash={GenerationIdHash} ErrorCode={ErrorCode} AttemptCount={AttemptCount} RetryDelaySeconds={RetryDelaySeconds}",
            TemplateLogSanitizer.SafeId(job.Id),
            safeErrorCode,
            job.AttemptCount,
            delaySeconds);
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> HandleProviderSubmitFailureAsync(
        TemplateGenerationJob job,
        PetMagic.BuildingBlocks.Results.Error error,
        CancellationToken cancellationToken)
    {
        if (string.Equals(error.Code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal)
            && job.AttemptCount < options.MaxGenerationAttempts)
        {
            return await RequeueForTransientSubmitFailureAsync(job, error, cancellationToken);
        }

        // Permanent provider errors (or exhausted attempts) keep the existing terminal path,
        // including the automatic refund of charged credits.
        await MarkFailedAsync(job, error, cancellationToken);
        return true;
    }

    private async Task<bool> FailNextExhaustedQueuedJobAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
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
        var maxConcurrentGenerations = RuntimeSettings.GlobalMaxConcurrent;
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

    private async Task<MediaConcurrencyLeases> TryAcquireMediaConcurrencyLeasesAsync(CancellationToken cancellationToken)
    {
        var snapshot = await BuildSchedulerCapacitySnapshotAsync(cancellationToken);
        var settings = RuntimeSettings;
        TemplateGenerationMetrics.RecordSchedulerCapacitySnapshot(
            snapshot.ActiveImage,
            snapshot.ActiveVideo,
            ResolveVideoReservedConcurrency(),
            ResolveImageProtectedConcurrency());

        if (settings.NewClaimsPaused || snapshot.ActiveGlobal >= settings.GlobalMaxConcurrent)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("active_global");
            return MediaConcurrencyLeases.Empty;
        }

        var effectiveImageMax = TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(
            settings,
            snapshot.ActiveVideo,
            snapshot.QueuedVideo);
        var allowImage = snapshot.ActiveImage < effectiveImageMax;
        var allowNativeVideo = snapshot.ActiveVideo < ResolveVideoReservedConcurrency();
        string? borrowDeniedReason = null;
        var allowBorrowedVideo = !allowNativeVideo && CanBorrowVideoCapacity(snapshot, out borrowDeniedReason);
        borrowDeniedReason ??= string.Empty;
        if (!allowBorrowedVideo && !string.IsNullOrWhiteSpace(borrowDeniedReason))
        {
            TemplateGenerationMetrics.RecordVideoBorrowDenied(borrowDeniedReason);
        }

        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await TryAcquirePostgresMediaConcurrencyLeasesAsync(
                allowImage,
                effectiveImageMax,
                allowNativeVideo,
                allowBorrowedVideo,
                cancellationToken)
            : TryAcquireLocalMediaConcurrencyLeases(
                allowImage,
                effectiveImageMax,
                allowNativeVideo,
                allowBorrowedVideo);
    }

    private async Task<MediaConcurrencyLeases> TryAcquirePostgresMediaConcurrencyLeasesAsync(
        bool allowImage,
        int effectiveImageMax,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        CancellationToken cancellationToken)
    {
        var imageSlot = allowImage
            ? await TryAcquirePostgresMediaSlotAsync(
                ImageGenerationAdvisoryLockKey,
                Math.Max(1, effectiveImageMax),
                cancellationToken)
            : null;
        var videoSlot = allowNativeVideo
            ? await TryAcquirePostgresMediaSlotAsync(
                VideoGenerationAdvisoryLockKey,
                Math.Max(1, ResolveVideoReservedConcurrency()),
                cancellationToken)
            : null;
        var borrowedVideoSlot = videoSlot is null && allowBorrowedVideo
            ? await TryAcquirePostgresMediaSlotAsync(
                BorrowedVideoGenerationAdvisoryLockKey,
                Math.Max(1, ResolveVideoBorrowMaxConcurrency()),
                cancellationToken)
            : null;

        return new MediaConcurrencyLeases(
            new MediaConcurrencyLease(dbContext, ImageGenerationAdvisoryLockKey, imageSlot),
            new MediaConcurrencyLease(dbContext, VideoGenerationAdvisoryLockKey, videoSlot),
            new MediaConcurrencyLease(dbContext, BorrowedVideoGenerationAdvisoryLockKey, borrowedVideoSlot));
    }

    private async Task<int?> TryAcquirePostgresMediaSlotAsync(
        int advisoryLockKey,
        int maxConcurrentGenerations,
        CancellationToken cancellationToken)
    {
        for (var slot = 1; slot <= maxConcurrentGenerations; slot++)
        {
            var acquired = await dbContext.Database.SqlQueryRaw<bool>(
                """
                SELECT pg_try_advisory_lock({0}, {1}) AS "Value"
                """,
                advisoryLockKey,
                slot)
                .SingleAsync(cancellationToken);

            if (acquired)
            {
                return slot;
            }
        }

        return null;
    }

    private MediaConcurrencyLeases TryAcquireLocalMediaConcurrencyLeases(
        bool allowImage,
        int effectiveImageMax,
        bool allowNativeVideo,
        bool allowBorrowedVideo)
    {
        lock (LocalConcurrencyLock)
        {
            var imageSlot = allowImage
                ? TryAcquireLocalMediaSlot(LocalImageConcurrencySlots, Math.Max(1, effectiveImageMax))
                : null;
            var videoSlot = allowNativeVideo
                ? TryAcquireLocalMediaSlot(LocalVideoConcurrencySlots, Math.Max(1, ResolveVideoReservedConcurrency()))
                : null;
            var borrowedVideoSlot = videoSlot is null && allowBorrowedVideo
                ? TryAcquireLocalMediaSlot(LocalBorrowedVideoConcurrencySlots, Math.Max(1, ResolveVideoBorrowMaxConcurrency()))
                : null;
            return new MediaConcurrencyLeases(
                new MediaConcurrencyLease(LocalImageConcurrencySlots, imageSlot),
                new MediaConcurrencyLease(LocalVideoConcurrencySlots, videoSlot),
                new MediaConcurrencyLease(LocalBorrowedVideoConcurrencySlots, borrowedVideoSlot));
        }
    }

    private static int? TryAcquireLocalMediaSlot(HashSet<int> slots, int maxConcurrentGenerations)
    {
        for (var slot = 1; slot <= maxConcurrentGenerations; slot++)
        {
            if (slots.Add(slot))
            {
                return slot;
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

    private sealed class SchedulerClaimGate : IAsyncDisposable
    {
        private IDbContextTransaction? transaction;
        private SemaphoreSlim? semaphore;

        public SchedulerClaimGate(IDbContextTransaction transaction)
        {
            this.transaction = transaction;
        }

        public SchedulerClaimGate(SemaphoreSlim semaphore)
        {
            this.semaphore = semaphore;
        }

        public async Task CompleteAsync(CancellationToken cancellationToken)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            await ReleaseAsync();
        }

        public ValueTask DisposeAsync() => ReleaseAsync();

        private async ValueTask ReleaseAsync()
        {
            if (transaction is not null)
            {
                var current = transaction;
                transaction = null;
                await current.DisposeAsync();
            }

            if (semaphore is not null)
            {
                var current = semaphore;
                semaphore = null;
                current.Release();
            }
        }
    }

    private async Task<SchedulerCapacitySnapshot> BuildSchedulerCapacitySnapshotAsync(CancellationToken cancellationToken)
    {
        var activeCounts = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status))
            .GroupBy(x => x.QueueMediaType)
            .Select(x => new { MediaType = x.Key, Count = x.LongCount() })
            .ToArrayAsync(cancellationToken);

        var activeImage = activeCounts
            .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeImage)
            .Sum(x => x.Count);
        var activeVideo = activeCounts
            .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeVideo)
            .Sum(x => x.Count);
        var queuedImage = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage,
                cancellationToken);

        var queuedVideo = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.QueueMediaType == TemplateGenerationQueue.MediaTypeVideo,
                cancellationToken);

        return new SchedulerCapacitySnapshot(activeImage, activeVideo, queuedImage, queuedVideo);
    }

    private bool CanBorrowVideoCapacity(SchedulerCapacitySnapshot snapshot, out string? deniedReason)
    {
        var settings = RuntimeSettings;
        return TemplateGenerationCapacityPolicy.CanBorrowVideo(
            settings,
            options.EnableElasticLaneBorrowing,
            options.AllowVideoBorrowWhenImageQueueEmpty,
            snapshot.ActiveImage,
            snapshot.ActiveVideo,
            snapshot.QueuedImage,
            out deniedReason);
    }

    private int ResolveImageProtectedConcurrency()
    {
        return RuntimeSettings.ImageProtectedConcurrent;
    }

    private int ResolveImageReservedConcurrency()
    {
        return RuntimeSettings.ImageProtectedConcurrent;
    }

    private int ResolveVideoReservedConcurrency()
    {
        return RuntimeSettings.VideoGuaranteedConcurrent;
    }

    private int ResolveVideoBorrowMaxConcurrency()
    {
        return Math.Max(0, RuntimeSettings.VideoBorrowMaxConcurrent);
    }

    private bool IsBorrowingTierAllowed(string queueTier)
    {
        var normalizedTier = TemplateGenerationQueue.NormalizeTier(queueTier);
        return options.BorrowingPriorityTiers
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Select(TemplateGenerationQueue.NormalizeTier)
            .Contains(normalizedTier, StringComparer.Ordinal);
    }

    private readonly record struct SchedulerCapacitySnapshot(
        long ActiveImage,
        long ActiveVideo,
        long QueuedImage,
        long QueuedVideo)
    {
        public long ActiveGlobal => ActiveImage + ActiveVideo;
    }

    private sealed class MediaConcurrencyLeases(MediaConcurrencyLease image, MediaConcurrencyLease video, MediaConcurrencyLease borrowedVideo) : IAsyncDisposable
    {
        public static readonly MediaConcurrencyLeases Empty = new(
            MediaConcurrencyLease.Empty,
            MediaConcurrencyLease.Empty,
            MediaConcurrencyLease.Empty);

        private bool disposed;

        public bool AllowImage => image.HasSlot;

        public bool AllowNativeVideo => video.HasSlot;

        public bool AllowBorrowedVideo => borrowedVideo.HasSlot;

        public bool AllowVideo => video.HasSlot || borrowedVideo.HasSlot;

        public bool HasAny => AllowImage || AllowVideo;

        public bool UsesBorrowedVideoFor(TemplateGenerationJob? job)
        {
            return job is not null
                && borrowedVideo.HasSlot
                && !video.HasSlot
                && string.Equals(TemplateGenerationQueue.ResolveMediaType(job), TemplateGenerationQueue.MediaTypeVideo, StringComparison.Ordinal);
        }

        public void ReleaseUnusedFor(TemplateGenerationJob? job)
        {
            var mediaType = job is null ? null : TemplateGenerationQueue.ResolveMediaType(job);
            if (!string.Equals(mediaType, TemplateGenerationQueue.MediaTypeImage, StringComparison.Ordinal))
            {
                image.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }

            if (!string.Equals(mediaType, TemplateGenerationQueue.MediaTypeVideo, StringComparison.Ordinal))
            {
                video.DisposeAsync().AsTask().GetAwaiter().GetResult();
                borrowedVideo.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }
            else if (video.HasSlot)
            {
                borrowedVideo.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }
            else
            {
                video.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }
        }

        public async ValueTask DisposeAsync()
        {
            if (disposed)
            {
                return;
            }

            disposed = true;
            await image.DisposeAsync();
            await video.DisposeAsync();
            await borrowedVideo.DisposeAsync();
        }
    }

    private sealed class MediaConcurrencyLease : IAsyncDisposable
    {
        public static readonly MediaConcurrencyLease Empty = new();

        private readonly TemplatesDbContext? dbContext;
        private readonly int? advisoryLockKey;
        private readonly HashSet<int>? localSlots;
        private int? slot;

        private MediaConcurrencyLease()
        {
        }

        public MediaConcurrencyLease(TemplatesDbContext dbContext, int advisoryLockKey, int? slot)
        {
            this.dbContext = dbContext;
            this.advisoryLockKey = advisoryLockKey;
            this.slot = slot;
        }

        public MediaConcurrencyLease(HashSet<int> localSlots, int? slot)
        {
            this.localSlots = localSlots;
            this.slot = slot;
        }

        public bool HasSlot => slot is not null;

        public async ValueTask DisposeAsync()
        {
            if (slot is null)
            {
                return;
            }

            var currentSlot = slot.Value;
            slot = null;
            if (dbContext is not null && advisoryLockKey is not null)
            {
                await dbContext.Database.SqlQueryRaw<bool>(
                    """
                    SELECT pg_advisory_unlock({0}, {1}) AS "Value"
                    """,
                    advisoryLockKey.Value,
                    currentSlot)
                    .SingleAsync();
                return;
            }

            if (localSlots is not null)
            {
                lock (LocalConcurrencyLock)
                {
                    localSlots.Remove(currentSlot);
                }
            }
        }
    }
}
