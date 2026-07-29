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
                && x.InputSourceType != TemplateGenerationQaFixtures.InputSourceType
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && (providerAttemptStore == null || !x.ProviderAttempts.Any(attempt =>
                    attempt.State == TemplateGenerationProviderAttemptState.SubmitReserved
                    || attempt.State == TemplateGenerationProviderAttemptState.Submitting
                    || attempt.State == TemplateGenerationProviderAttemptState.ProviderQueued
                    || attempt.State == TemplateGenerationProviderAttemptState.ProviderProcessing
                    || attempt.State == TemplateGenerationProviderAttemptState.SubmissionUnknown))
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
        bool allowVideoPreprocessing,
        CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? ClaimNextPostgresAsync(
                allowImage,
                allowNativeVideo,
                allowBorrowedVideo,
                allowVideoPreprocessing,
                cancellationToken)
            : ClaimNextTrackedAsync(
                allowImage,
                allowNativeVideo,
                allowBorrowedVideo,
                allowVideoPreprocessing,
                cancellationToken);
    }

    private async Task<TemplateGenerationJob?> ClaimNextPostgresAsync(
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        bool allowVideoPreprocessing,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var borrowAdmin = IsBorrowingTierAllowed(TemplateGenerationQueue.TierAdmin);
        var borrowPrivileged = IsBorrowingTierAllowed(TemplateGenerationQueue.TierPrivileged);
        var borrowPremium = IsBorrowingTierAllowed(TemplateGenerationQueue.TierPremium);
        var borrowFree = IsBorrowingTierAllowed(TemplateGenerationQueue.TierFree);
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        await dbContext.Database.ExecuteSqlRawAsync(
            "SELECT pg_advisory_xact_lock({0})",
            [QueueFairnessAdvisoryLockKey],
            cancellationToken);
        var claimedIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            UPDATE templates_generation_jobs AS claimed
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
                SELECT candidate."Id"
                FROM templates_generation_jobs AS candidate
                WHERE candidate."Status" = {0}
                    AND candidate."InputSourceType" <> 'qa_fixture'
                    AND (candidate."ChargedAtUtc" IS NOT NULL OR candidate."UserId" = {4})
                    AND candidate."AttemptCount" < {3}
                    AND (candidate."NextAttemptEarliestAtUtc" IS NULL OR candidate."NextAttemptEarliestAtUtc" <= {2})
                    AND (
                        ({6} AND candidate."QueueMediaType" = 'image')
                        OR (candidate."QueueMediaType" = 'video'
                            AND ({19}
                                OR (candidate."NormalizedImageUrl" IS NOT NULL
                                    AND candidate."PreprocessingCompletedAtUtc" IS NOT NULL))
                            AND (
                                {7}
                                OR ({8} AND (
                                    (candidate."QueueTier" = 'admin' AND {9})
                                    OR (candidate."QueueTier" = 'privileged' AND {10})
                                    OR (candidate."QueueTier" = 'premium' AND {11})
                                    OR (candidate."QueueTier" = 'free' AND {12})
                                ))
                            ))
                    )
                ORDER BY (
                    CASE candidate."QueueTier"
                        WHEN 'admin' THEN {13}
                        WHEN 'privileged' THEN {14}
                        WHEN 'premium' THEN {15}
                        ELSE {16}
                    END
                    + FLOOR(GREATEST(0, EXTRACT(EPOCH FROM ({2} - candidate."QueuedAtUtc"))) / {17})::int * {18}
                ) DESC,
                (
                    SELECT MAX(history."LastAttemptAtUtc")
                    FROM templates_generation_jobs AS history
                    WHERE history."UserId" = candidate."UserId"
                        AND history."QueueTier" = candidate."QueueTier"
                        AND history."LastAttemptAtUtc" IS NOT NULL
                ) ASC NULLS FIRST,
                candidate."QueuedAtUtc",
                candidate."Id"
                FOR UPDATE OF candidate SKIP LOCKED
                LIMIT 1
            )
            RETURNING claimed."Id" AS "Value"
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
            options.QueuePriorityAgingBoost,
            allowVideoPreprocessing)
            .ToListAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);

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
        bool allowVideoPreprocessing,
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
                        && (allowVideoPreprocessing
                            || (x.NormalizedImageUrl != null && x.PreprocessingCompletedAtUtc != null))
                        && (allowNativeVideo
                            || (allowBorrowedVideo && IsBorrowingTierAllowed(x.QueueTier))))))
            .ToArrayAsync(cancellationToken);

        if (candidates.Length == 0)
        {
            return null;
        }

        var candidateUserIds = candidates
            .Select(candidate => candidate.UserId)
            .Distinct()
            .ToArray();
        var recentClaims = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job => candidateUserIds.Contains(job.UserId)
                && job.LastAttemptAtUtc != null)
            .GroupBy(job => new { job.UserId, job.QueueTier })
            .Select(group => new
            {
                group.Key.UserId,
                group.Key.QueueTier,
                LastClaimedAtUtc = group.Max(job => job.LastAttemptAtUtc)
            })
            .ToArrayAsync(cancellationToken);
        var lastClaimedByUserAndTier = recentClaims.ToDictionary(
            claim => (claim.UserId, TemplateGenerationQueue.NormalizeTier(claim.QueueTier)),
            claim => claim.LastClaimedAtUtc);

        var job = candidates
            .OrderByDescending(x => TemplateGenerationQueue.ResolvePriorityScore(x, now, options))
            .ThenBy(x => lastClaimedByUserAndTier.GetValueOrDefault(
                (x.UserId, TemplateGenerationQueue.NormalizeTier(x.QueueTier))))
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
        if ((string.Equals(error.Code, TemplatesErrors.AiProviderTransientFailure.Code, StringComparison.Ordinal)
                || string.Equals(error.Code, TemplatesErrors.AiProviderRateLimited.Code, StringComparison.Ordinal))
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
                && (providerAttemptStore == null || !x.ProviderAttempts.Any(attempt =>
                    attempt.State == TemplateGenerationProviderAttemptState.SubmitReserved
                    || attempt.State == TemplateGenerationProviderAttemptState.Submitting
                    || attempt.State == TemplateGenerationProviderAttemptState.ProviderQueued
                    || attempt.State == TemplateGenerationProviderAttemptState.ProviderProcessing
                    || attempt.State == TemplateGenerationProviderAttemptState.SubmissionUnknown))
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

    private async Task<TemplateGenerationConcurrencyProfile?> ResolveSchedulerProfileAsync(
        CancellationToken cancellationToken)
    {
        if (runtimePolicyProvider is not null)
        {
            var runtimePolicy = await runtimePolicyProvider.GetRuntimePolicyAsync(cancellationToken);
            if (options.GenerationSchedulerV2Enabled)
            {
                return runtimePolicy.EffectiveProfile;
            }
        }

        var imageReserved = options.ImageReservedConcurrentGenerations > 0
            ? options.ImageReservedConcurrentGenerations
            : options.ImageMaxConcurrentGenerations;
        var imageProtected = options.ImageProtectedConcurrentGenerations > 0
            ? options.ImageProtectedConcurrentGenerations
            : imageReserved;
        var videoReserved = options.VideoReservedConcurrentGenerations > 0
            ? options.VideoReservedConcurrentGenerations
            : options.VideoMaxConcurrentGenerations;
        return new TemplateGenerationConcurrencyProfile(
            options.GlobalMaxConcurrentGenerations,
            imageReserved,
            imageProtected,
            options.ImageMaxConcurrentGenerations,
            videoReserved,
            options.VideoMaxConcurrentGenerations,
            Math.Max(0, options.VideoBorrowMaxConcurrentGenerations),
            options.VideoPreprocessingMaxConcurrentGenerations);
    }

    private async Task<GlobalConcurrencyLease?> TryAcquireGlobalConcurrencyLeaseAsync(
        int maxConcurrentGenerations,
        CancellationToken cancellationToken)
    {
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

    private async Task<MediaConcurrencyLeases> TryAcquireMediaConcurrencyLeasesAsync(
        TemplateGenerationConcurrencyProfile profile,
        CancellationToken cancellationToken)
    {
        var snapshot = await BuildSchedulerCapacitySnapshotAsync(cancellationToken);
        TemplateGenerationMetrics.RecordSchedulerCapacitySnapshot(
            snapshot.ActiveImage,
            snapshot.ActiveVideo,
            profile.VideoReservedConcurrentGenerations,
            profile.ImageProtectedConcurrentGenerations);

        if (snapshot.ActiveGlobal >= profile.GlobalMaxConcurrentGenerations)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("active_global");
            return MediaConcurrencyLeases.Empty;
        }

        var missingGuaranteedVideoSlots = snapshot.QueuedVideo > 0
            ? Math.Max(0, profile.VideoReservedConcurrentGenerations - snapshot.ActiveVideo)
            : 0;
        var imagePreservesVideoGuarantee = snapshot.ActiveGlobal + 1
            <= profile.GlobalMaxConcurrentGenerations - missingGuaranteedVideoSlots;
        var allowImage = snapshot.ActiveImage < profile.ImageMaxConcurrentGenerations
            && imagePreservesVideoGuarantee;
        if (!allowImage && snapshot.QueuedVideo > 0 && !imagePreservesVideoGuarantee)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("video_reserved");
        }

        var videoPreprocessingAvailable = snapshot.ActiveVideoPreprocessing
            < profile.VideoPreprocessingMaxConcurrentGenerations;
        var allowNativeVideo = snapshot.ActiveVideo < profile.VideoReservedConcurrentGenerations;
        string? borrowDeniedReason = null;
        var allowBorrowedVideo = !allowNativeVideo
            && CanBorrowVideoCapacity(snapshot, profile, out borrowDeniedReason);
        borrowDeniedReason ??= string.Empty;
        if (!allowBorrowedVideo && !string.IsNullOrWhiteSpace(borrowDeniedReason))
        {
            TemplateGenerationMetrics.RecordVideoBorrowDenied(borrowDeniedReason);
        }

        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await TryAcquirePostgresMediaConcurrencyLeasesAsync(
                profile,
                allowImage,
                allowNativeVideo,
                allowBorrowedVideo,
                videoPreprocessingAvailable,
                cancellationToken)
            : TryAcquireLocalMediaConcurrencyLeases(
                profile,
                allowImage,
                allowNativeVideo,
                allowBorrowedVideo,
                videoPreprocessingAvailable);
    }

    private async Task<MediaConcurrencyLeases> TryAcquirePostgresMediaConcurrencyLeasesAsync(
        TemplateGenerationConcurrencyProfile profile,
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        bool allowVideoPreprocessing,
        CancellationToken cancellationToken)
    {
        var imageSlot = allowImage
            ? await TryAcquirePostgresMediaSlotAsync(
                ImageGenerationAdvisoryLockKey,
                Math.Max(1, profile.ImageMaxConcurrentGenerations),
                cancellationToken)
            : null;
        var videoSlot = allowNativeVideo
            ? await TryAcquirePostgresMediaSlotAsync(
                VideoGenerationAdvisoryLockKey,
                Math.Max(1, profile.VideoReservedConcurrentGenerations),
                cancellationToken)
            : null;
        var borrowedVideoSlot = videoSlot is null && allowBorrowedVideo
            ? await TryAcquirePostgresMediaSlotAsync(
                BorrowedVideoGenerationAdvisoryLockKey,
                Math.Max(1, profile.VideoBorrowMaxConcurrentGenerations),
                cancellationToken)
            : null;

        return new MediaConcurrencyLeases(
            new MediaConcurrencyLease(dbContext, ImageGenerationAdvisoryLockKey, imageSlot),
            new MediaConcurrencyLease(dbContext, VideoGenerationAdvisoryLockKey, videoSlot),
            new MediaConcurrencyLease(dbContext, BorrowedVideoGenerationAdvisoryLockKey, borrowedVideoSlot),
            allowVideoPreprocessing);
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
        TemplateGenerationConcurrencyProfile profile,
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        bool allowVideoPreprocessing)
    {
        lock (LocalConcurrencyLock)
        {
            var imageSlot = allowImage
                ? TryAcquireLocalMediaSlot(LocalImageConcurrencySlots, Math.Max(1, profile.ImageMaxConcurrentGenerations))
                : null;
            var videoSlot = allowNativeVideo
                ? TryAcquireLocalMediaSlot(LocalVideoConcurrencySlots, Math.Max(1, profile.VideoReservedConcurrentGenerations))
                : null;
            var borrowedVideoSlot = videoSlot is null && allowBorrowedVideo
                ? TryAcquireLocalMediaSlot(LocalBorrowedVideoConcurrencySlots, Math.Max(1, profile.VideoBorrowMaxConcurrentGenerations))
                : null;
            return new MediaConcurrencyLeases(
                new MediaConcurrencyLease(LocalImageConcurrencySlots, imageSlot),
                new MediaConcurrencyLease(LocalVideoConcurrencySlots, videoSlot),
                new MediaConcurrencyLease(LocalBorrowedVideoConcurrencySlots, borrowedVideoSlot),
                allowVideoPreprocessing);
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

    private async Task<SchedulerCapacitySnapshot> BuildSchedulerCapacitySnapshotAsync(CancellationToken cancellationToken)
    {
        long activeImage;
        long activeVideo;
        long activeVideoPreprocessing;
        if (providerAttemptStore is not null)
        {
            var activeAttempts = dbContext.TemplateGenerationProviderAttempts
                .AsNoTracking()
                .Where(x => x.State == TemplateGenerationProviderAttemptState.SubmitReserved
                    || x.State == TemplateGenerationProviderAttemptState.Submitting
                    || x.State == TemplateGenerationProviderAttemptState.ProviderQueued
                    || x.State == TemplateGenerationProviderAttemptState.ProviderProcessing
                    || x.State == TemplateGenerationProviderAttemptState.SubmissionUnknown);
            activeImage = await activeAttempts.LongCountAsync(
                x => x.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration,
                cancellationToken);
            activeVideo = await activeAttempts.LongCountAsync(
                x => x.Stage != TemplateGenerationProviderAttemptStage.ImageGeneration,
                cancellationToken);
            activeVideoPreprocessing = await activeAttempts.LongCountAsync(
                x => x.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing,
                cancellationToken);
        }
        else
        {
            var activeCounts = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status))
                .GroupBy(x => x.QueueMediaType)
                .Select(x => new { MediaType = x.Key, Count = x.LongCount() })
                .ToArrayAsync(cancellationToken);
            activeImage = activeCounts
                .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeImage)
                .Sum(x => x.Count);
            activeVideo = activeCounts
                .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeVideo)
                .Sum(x => x.Count);
            activeVideoPreprocessing = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .LongCountAsync(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                        || x.Status == TemplateGenerationStatus.ProviderQueued
                        || x.Status == TemplateGenerationStatus.ProviderProcessing)
                    && x.CurrentProviderStage == ProviderStageVideoPreprocessing
                    && x.ProviderCompletedAtUtc == null,
                    cancellationToken);
        }
        var queuedImage = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage,
                cancellationToken);

        var queuedVideo = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => x.QueueMediaType == TemplateGenerationQueue.MediaTypeVideo
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId)
                && (x.Status == TemplateGenerationStatus.Queued
                    || (x.Status == TemplateGenerationStatus.ProviderQueued
                        && x.CurrentProviderStage == ProviderStageVideoPreprocessing
                        && x.ProviderCompletedAtUtc != null
                        && x.NormalizedImageUrl != null
                        && x.MotionProviderRequestId == null)),
                cancellationToken);

        return new SchedulerCapacitySnapshot(
            activeImage,
            activeVideo,
            queuedImage,
            queuedVideo,
            activeVideoPreprocessing);
    }

    private bool CanBorrowVideoCapacity(
        SchedulerCapacitySnapshot snapshot,
        TemplateGenerationConcurrencyProfile profile,
        out string? deniedReason)
    {
        deniedReason = null;
        if (!options.EnableElasticLaneBorrowing)
        {
            return false;
        }

        if (snapshot.ActiveVideo >= profile.VideoMaxConcurrentGenerations)
        {
            deniedReason = "video_max";
            return false;
        }

        var borrowedVideo = Math.Max(0, snapshot.ActiveVideo - profile.VideoReservedConcurrentGenerations);
        if (borrowedVideo >= profile.VideoBorrowMaxConcurrentGenerations)
        {
            deniedReason = "borrow_max";
            return false;
        }

        if (snapshot.ActiveImage + profile.ImageProtectedConcurrentGenerations > profile.ImageMaxConcurrentGenerations)
        {
            deniedReason = "image_protected";
            return false;
        }

        if (snapshot.QueuedImage == 0)
        {
            if (options.AllowVideoBorrowWhenImageQueueEmpty)
            {
                return true;
            }

            deniedReason = "image_queue_empty_disabled";
            return false;
        }

        var imageEstimatedWaitSeconds = EstimateImageWaitSeconds(snapshot, profile);
        if (imageEstimatedWaitSeconds <= options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds)
        {
            return true;
        }

        deniedReason = "image_backlog";
        return false;
    }

    private int EstimateImageWaitSeconds(
        SchedulerCapacitySnapshot snapshot,
        TemplateGenerationConcurrencyProfile profile)
    {
        var protectedSlots = Math.Max(1, profile.ImageProtectedConcurrentGenerations);
        var backlogUnits = Math.Max(0, snapshot.ActiveImage + snapshot.QueuedImage - protectedSlots);
        return (int)Math.Ceiling(backlogUnits * Math.Max(1, options.EstimatedImageGenerationSeconds) / (double)protectedSlots);
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
        long QueuedVideo,
        long ActiveVideoPreprocessing)
    {
        public long ActiveGlobal => ActiveImage + ActiveVideo;
    }

    private sealed class MediaConcurrencyLeases(
        MediaConcurrencyLease image,
        MediaConcurrencyLease video,
        MediaConcurrencyLease borrowedVideo,
        bool allowVideoPreprocessing) : IAsyncDisposable
    {
        public static readonly MediaConcurrencyLeases Empty = new(
            MediaConcurrencyLease.Empty,
            MediaConcurrencyLease.Empty,
            MediaConcurrencyLease.Empty,
            allowVideoPreprocessing: false);

        private bool disposed;

        public bool AllowImage => image.HasSlot;

        public bool AllowNativeVideo => video.HasSlot;

        public bool AllowBorrowedVideo => borrowedVideo.HasSlot;

        public bool AllowVideoPreprocessing => allowVideoPreprocessing;

        public bool AllowVideo => video.HasSlot || borrowedVideo.HasSlot;

        public bool HasAny => AllowImage || AllowVideo;

        public bool UsesBorrowedVideoFor(TemplateGenerationJob? job)
        {
            return job is not null
                && borrowedVideo.HasSlot
                && !video.HasSlot
                && string.Equals(TemplateGenerationQueue.ResolveMediaType(job), TemplateGenerationQueue.MediaTypeVideo, StringComparison.Ordinal);
        }

        public async ValueTask ReleaseUnusedForAsync(TemplateGenerationJob? job)
        {
            var mediaType = job is null ? null : TemplateGenerationQueue.ResolveMediaType(job);
            if (!string.Equals(mediaType, TemplateGenerationQueue.MediaTypeImage, StringComparison.Ordinal))
            {
                await image.DisposeAsync();
            }

            if (!string.Equals(mediaType, TemplateGenerationQueue.MediaTypeVideo, StringComparison.Ordinal))
            {
                await video.DisposeAsync();
                await borrowedVideo.DisposeAsync();
            }
            else if (video.HasSlot)
            {
                await borrowedVideo.DisposeAsync();
            }
            else
            {
                await video.DisposeAsync();
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
