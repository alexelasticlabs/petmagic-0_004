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
        if (HasProviderRequestId(staleJob))
        {
            logger.LogWarning(
                "Stale template generation job has a saved provider request id; retry keeps provider identifiers for provider-state reconciliation. PreprocessingProviderRequestId={PreprocessingProviderRequestId} MotionProviderRequestId={MotionProviderRequestId}",
                staleJob.PreprocessingProviderRequestId,
                staleJob.MotionProviderRequestId);
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
                exception,
                "Stale template generation job recovery was skipped because its lock changed. ElapsedMs={ElapsedMs}",
                ElapsedMsSince(recoveryStartedAt));
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
            "Orphan queued template generation job failed because it was never charged. GenerationId={GenerationId} QueuedAtUtc={QueuedAtUtc}",
            job.Id,
            job.QueuedAtUtc);
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private static bool HasProviderRequestId(TemplateGenerationJob job)
    {
        return !string.IsNullOrWhiteSpace(job.PreprocessingProviderRequestId)
            || !string.IsNullOrWhiteSpace(job.MotionProviderRequestId);
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

    private async Task<MediaConcurrencyLeases> TryAcquireMediaConcurrencyLeasesAsync(CancellationToken cancellationToken)
    {
        var snapshot = await BuildSchedulerCapacitySnapshotAsync(cancellationToken);
        TemplateGenerationMetrics.RecordSchedulerCapacitySnapshot(
            snapshot.ActiveImage,
            snapshot.ActiveVideo,
            ResolveVideoReservedConcurrency(),
            ResolveImageProtectedConcurrency());

        if (snapshot.ActiveGlobal >= options.GlobalMaxConcurrentGenerations)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("active_global");
            return MediaConcurrencyLeases.Empty;
        }

        var allowImage = snapshot.ActiveImage < options.ImageMaxConcurrentGenerations;
        var allowNativeVideo = snapshot.ActiveVideo < ResolveVideoReservedConcurrency();
        string? borrowDeniedReason = null;
        var allowBorrowedVideo = !allowNativeVideo && CanBorrowVideoCapacity(snapshot, out borrowDeniedReason);
        borrowDeniedReason ??= string.Empty;
        if (!allowBorrowedVideo && !string.IsNullOrWhiteSpace(borrowDeniedReason))
        {
            TemplateGenerationMetrics.RecordVideoBorrowDenied(borrowDeniedReason);
        }

        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await TryAcquirePostgresMediaConcurrencyLeasesAsync(allowImage, allowNativeVideo, allowBorrowedVideo, cancellationToken)
            : TryAcquireLocalMediaConcurrencyLeases(allowImage, allowNativeVideo, allowBorrowedVideo);
    }

    private async Task<MediaConcurrencyLeases> TryAcquirePostgresMediaConcurrencyLeasesAsync(
        bool allowImage,
        bool allowNativeVideo,
        bool allowBorrowedVideo,
        CancellationToken cancellationToken)
    {
        var imageSlot = allowImage
            ? await TryAcquirePostgresMediaSlotAsync(
                ImageGenerationAdvisoryLockKey,
                Math.Max(1, options.ImageMaxConcurrentGenerations),
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
        bool allowNativeVideo,
        bool allowBorrowedVideo)
    {
        lock (LocalConcurrencyLock)
        {
            var imageSlot = allowImage
                ? TryAcquireLocalMediaSlot(LocalImageConcurrencySlots, Math.Max(1, options.ImageMaxConcurrentGenerations))
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

        return new SchedulerCapacitySnapshot(activeImage, activeVideo, queuedImage);
    }

    private bool CanBorrowVideoCapacity(SchedulerCapacitySnapshot snapshot, out string? deniedReason)
    {
        deniedReason = null;
        if (!options.EnableElasticLaneBorrowing)
        {
            return false;
        }

        if (snapshot.ActiveVideo >= options.VideoMaxConcurrentGenerations)
        {
            deniedReason = "video_max";
            return false;
        }

        var borrowedVideo = Math.Max(0, snapshot.ActiveVideo - ResolveVideoReservedConcurrency());
        if (borrowedVideo >= ResolveVideoBorrowMaxConcurrency())
        {
            deniedReason = "borrow_max";
            return false;
        }

        if (snapshot.ActiveImage + ResolveImageProtectedConcurrency() > options.ImageMaxConcurrentGenerations)
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

        var imageEstimatedWaitSeconds = EstimateImageWaitSeconds(snapshot);
        if (imageEstimatedWaitSeconds <= options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds)
        {
            return true;
        }

        deniedReason = "image_backlog";
        return false;
    }

    private int EstimateImageWaitSeconds(SchedulerCapacitySnapshot snapshot)
    {
        var protectedSlots = Math.Max(1, ResolveImageProtectedConcurrency());
        var backlogUnits = Math.Max(0, snapshot.ActiveImage + snapshot.QueuedImage - protectedSlots);
        return (int)Math.Ceiling(backlogUnits * Math.Max(1, options.EstimatedImageGenerationSeconds) / (double)protectedSlots);
    }

    private int ResolveImageProtectedConcurrency()
    {
        return options.ImageProtectedConcurrentGenerations > 0
            ? options.ImageProtectedConcurrentGenerations
            : ResolveImageReservedConcurrency();
    }

    private int ResolveImageReservedConcurrency()
    {
        return options.ImageReservedConcurrentGenerations > 0
            ? options.ImageReservedConcurrentGenerations
            : options.ImageMaxConcurrentGenerations;
    }

    private int ResolveVideoReservedConcurrency()
    {
        return options.VideoReservedConcurrentGenerations > 0
            ? options.VideoReservedConcurrentGenerations
            : options.VideoMaxConcurrentGenerations;
    }

    private int ResolveVideoBorrowMaxConcurrency()
    {
        return Math.Max(0, options.VideoBorrowMaxConcurrentGenerations);
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
        long QueuedImage)
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
