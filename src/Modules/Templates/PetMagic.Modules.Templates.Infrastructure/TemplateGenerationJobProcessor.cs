using System.Security.Cryptography;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Gamification.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor(
    TemplatesDbContext dbContext,
    IImagePreprocessor imagePreprocessor,
    IImageGenerator imageGenerator,
    IVideoMotionGenerator videoMotionGenerator,
    IGeneratedMediaImporter generatedMediaImporter,
    IMediaMetadataReader mediaMetadataReader,
    IMediaStorage mediaStorage,
    IImagePreviewGenerator imagePreviewGenerator,
    IVideoThumbnailGenerator videoThumbnailGenerator,
    ITemplateGenerationBilling billing,
    ITemplateFeedRealtimeService realtimeService,
    ITemplateGenerationPushNotificationSender pushNotificationSender,
    TemplatesOptions options,
    ILogger<TemplateGenerationJobProcessor> logger,
    FalQueueClient? falQueueClient = null,
    ITemplateWatermarkRenderer? watermarkRenderer = null,
    TemplateWatermarkSettingsStore? watermarkSettings = null,
    IGamificationService? gamificationService = null,
    IEconomyService? economyService = null)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const int GlobalGenerationAdvisoryLockKey = 0x506D4745;
    private const int ImageGenerationAdvisoryLockKey = 0x506D4749;
    private const int VideoGenerationAdvisoryLockKey = 0x506D4756;
    private const int BorrowedVideoGenerationAdvisoryLockKey = 0x506D4742;
    private static readonly string WorkerInstanceId = $"{Environment.MachineName}:{Guid.NewGuid():N}";
    private static readonly object LocalConcurrencyLock = new();
    private static readonly HashSet<int> LocalConcurrencySlots = [];
    private static readonly HashSet<int> LocalImageConcurrencySlots = [];
    private static readonly HashSet<int> LocalVideoConcurrencySlots = [];
    private static readonly HashSet<int> LocalBorrowedVideoConcurrencySlots = [];

    public TemplateGenerationJobProcessor(
        TemplatesDbContext dbContext,
        IImagePreprocessor imagePreprocessor,
        IImageGenerator imageGenerator,
        IVideoMotionGenerator videoMotionGenerator,
        IGeneratedMediaImporter generatedMediaImporter,
        IMediaMetadataReader mediaMetadataReader,
        IMediaStorage mediaStorage,
        IImagePreviewGenerator imagePreviewGenerator,
        IVideoThumbnailGenerator videoThumbnailGenerator,
        ITemplateWatermarkRenderer watermarkRenderer,
        ITemplateGenerationBilling billing,
        ITemplateFeedRealtimeService realtimeService,
        ITemplateGenerationPushNotificationSender pushNotificationSender,
        TemplatesOptions options,
        ILogger<TemplateGenerationJobProcessor> logger)
        : this(
            dbContext,
            imagePreprocessor,
            imageGenerator,
            videoMotionGenerator,
            generatedMediaImporter,
            mediaMetadataReader,
            mediaStorage,
            imagePreviewGenerator,
            videoThumbnailGenerator,
            billing,
            realtimeService,
            pushNotificationSender,
            options,
            logger,
            null,
            watermarkRenderer)
    {
    }

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        if (await SettleNextPendingGenerationBillingCommandAsync(cancellationToken))
        {
            return true;
        }

        await RecordQueueSnapshotAsync(cancellationToken);

        var failedOrphanQueuedJob = await FailNextOrphanQueuedJobAsync(cancellationToken);
        var recoveredStaleJob = await RecoverNextStaleProcessingJobAsync(cancellationToken);
        var advancedProviderJob = await AdvanceNextProviderJobAsync(cancellationToken);
        if (advancedProviderJob)
        {
            return true;
        }

        await using var concurrencyLease = await TryAcquireGlobalConcurrencyLeaseAsync(cancellationToken);
        if (concurrencyLease is null)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("global");
            return failedOrphanQueuedJob || recoveredStaleJob;
        }

        await using var mediaLeases = await TryAcquireMediaConcurrencyLeasesAsync(cancellationToken);
        if (!mediaLeases.HasAny)
        {
            TemplateGenerationMetrics.RecordSchedulerNoSlotSkip("media");
            return failedOrphanQueuedJob || recoveredStaleJob;
        }

        var claimStartedAt = System.Diagnostics.Stopwatch.GetTimestamp();
        var job = await ClaimNextAsync(
            mediaLeases.AllowImage,
            mediaLeases.AllowNativeVideo,
            mediaLeases.AllowBorrowedVideo,
            cancellationToken);
        var usedBorrowedVideoSlot = mediaLeases.UsesBorrowedVideoFor(job);
        mediaLeases.ReleaseUnusedFor(job);

        if (job is null)
        {
            TemplateGenerationMetrics.RecordSchedulerClaimAttempt("none", "empty");
            if (await FailNextExhaustedQueuedJobAsync(cancellationToken))
            {
                return true;
            }

            return failedOrphanQueuedJob || recoveredStaleJob;
        }

        var correlationId = ResolveJobCorrelationId(job);
        using (CorrelationContext.Push(correlationId))
        using (BeginJobScope(job, correlationId))
        {
            logger.LogInformation(
                "Template generation job claimed. ElapsedMs={ElapsedMs}",
                ElapsedMsSince(claimStartedAt));
        }

        TemplateGenerationMetrics.RecordJobClaimed(job);
        TemplateGenerationMetrics.RecordSchedulerClaimAttempt(
            TemplateGenerationQueue.ResolveMediaType(job),
            usedBorrowedVideoSlot ? "claimed_borrowed" : "claimed");
        if (usedBorrowedVideoSlot)
        {
            TemplateGenerationMetrics.RecordBorrowedVideoStart(job.QueueTier);
        }

        await ProcessAsync(job, cancellationToken);
        return true;
    }

    private async Task RecordQueueSnapshotAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var queueDepth = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .LongCountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId),
                cancellationToken);

        var oldestQueuedAtUtc = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == TemplateGenerationService.AdminTestUserId))
            .OrderBy(x => x.QueuedAtUtc)
            .Select(x => (DateTime?)x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        var oldestProcessingStartedAtUtc = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status))
            .OrderBy(x => x.StartedAtUtc ?? x.UpdatedAtUtc)
            .Select(x => (DateTime?)(x.StartedAtUtc ?? x.UpdatedAtUtc))
            .FirstOrDefaultAsync(cancellationToken);

        TemplateGenerationMetrics.RecordQueueSnapshot(
            queueDepth,
            oldestQueuedAtUtc is null ? null : (now - oldestQueuedAtUtc.Value).TotalSeconds,
            oldestProcessingStartedAtUtc is null ? null : (now - oldestProcessingStartedAtUtc.Value).TotalSeconds);

        var refundSnapshot = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => (x.Status == TemplateGenerationStatus.Failed || x.Status == TemplateGenerationStatus.Cancelled)
                && x.ChargedAtUtc != null
                && x.RefundedAtUtc == null)
            .GroupBy(x => x.RefundAttemptCount >= options.MaxRefundAttempts)
            .Select(x => new { Exhausted = x.Key, Count = x.LongCount() })
            .ToArrayAsync(cancellationToken);

        TemplateGenerationMetrics.RecordPendingRefundsSnapshot(
            refundSnapshot.Where(x => !x.Exhausted).Sum(x => x.Count),
            refundSnapshot.Where(x => x.Exhausted).Sum(x => x.Count));

        var laneSnapshots = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                || TemplateGenerationJobStatusSets.Processing.Contains(x.Status))
            .GroupBy(x => new { x.QueueMediaType, x.QueueTier })
            .Select(x => new
            {
                x.Key.QueueMediaType,
                x.Key.QueueTier,
                QueueDepth = x.LongCount(job => job.Status == TemplateGenerationStatus.Queued
                    && (job.ChargedAtUtc != null || job.UserId == TemplateGenerationService.AdminTestUserId)),
                ActiveJobs = x.LongCount(job => TemplateGenerationJobStatusSets.Processing.Contains(job.Status)),
                OldestQueuedAtUtc = x.Where(job => job.Status == TemplateGenerationStatus.Queued
                        && (job.ChargedAtUtc != null || job.UserId == TemplateGenerationService.AdminTestUserId))
                    .Min(job => (DateTime?)job.QueuedAtUtc),
                OldestProcessingStartedAtUtc = x.Where(job => TemplateGenerationJobStatusSets.Processing.Contains(job.Status))
                    .Min(job => (DateTime?)(job.StartedAtUtc ?? job.UpdatedAtUtc))
            })
            .ToArrayAsync(cancellationToken);

        foreach (var lane in laneSnapshots)
        {
            TemplateGenerationMetrics.RecordLaneQueueSnapshot(
                lane.QueueMediaType,
                lane.QueueTier,
                lane.QueueDepth,
                lane.ActiveJobs,
                lane.OldestQueuedAtUtc is null ? null : (now - lane.OldestQueuedAtUtc.Value).TotalSeconds,
                lane.OldestProcessingStartedAtUtc is null ? null : (now - lane.OldestProcessingStartedAtUtc.Value).TotalSeconds);
        }

        var providerStageSnapshots = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.ProviderQueued
                || x.Status == TemplateGenerationStatus.ProviderProcessing
                || x.Status == TemplateGenerationStatus.ImportingMedia)
            .GroupBy(x => new { x.Status, x.QueueMediaType, x.QueueTier })
            .Select(x => new
            {
                x.Key.Status,
                x.Key.QueueMediaType,
                x.Key.QueueTier,
                OldestStageAtUtc = x.Min(job => (DateTime?)(job.ProviderStatusCheckedAtUtc
                    ?? job.ImportStartedAtUtc
                    ?? job.ProviderSubmittedAtUtc
                    ?? job.UpdatedAtUtc))
            })
            .ToArrayAsync(cancellationToken);

        foreach (var stage in providerStageSnapshots)
        {
            if (stage.OldestStageAtUtc is null)
            {
                continue;
            }

            TemplateGenerationMetrics.RecordStuckStageAge(
                TemplateGenerationService.ResolveApiStatus(stage.Status),
                stage.QueueMediaType,
                stage.QueueTier,
                (now - stage.OldestStageAtUtc.Value).TotalSeconds);
        }
    }

    public async Task<bool> RetryNextRefundAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await RetryNextRefundPostgresAsync(cancellationToken)
            : await RetryNextRefundTrackedAsync(cancellationToken);
    }

    private async Task<bool> RetryNextRefundTrackedAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.RefundRetryDelayMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => (x.Status == TemplateGenerationStatus.Failed
                    || x.Status == TemplateGenerationStatus.Cancelled)
                && x.ChargedAtUtc != null
                && x.RefundedAtUtc == null
                && x.RefundAttemptCount < options.MaxRefundAttempts
                && (x.RefundLastAttemptedAtUtc == null || x.RefundLastAttemptedAtUtc <= retryThreshold))
            .OrderBy(x => x.RefundLastAttemptedAtUtc ?? x.CompletedAtUtc ?? x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        await TryRefundAsync(job, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task<bool> RetryNextRefundPostgresAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.RefundRetryDelayMilliseconds);
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var claimedIds = await dbContext.Database.SqlQueryRaw<Guid>(
            """
            SELECT "Id" AS "Value"
            FROM templates_generation_jobs
            WHERE "Status" IN ({0}, {1})
                AND "ChargedAtUtc" IS NOT NULL
                AND "RefundedAtUtc" IS NULL
                AND "RefundAttemptCount" < {2}
                AND ("RefundLastAttemptedAtUtc" IS NULL OR "RefundLastAttemptedAtUtc" <= {3})
            ORDER BY COALESCE("RefundLastAttemptedAtUtc", "CompletedAtUtc", "UpdatedAtUtc"), "Id"
            FOR UPDATE SKIP LOCKED
            LIMIT 1
            """,
            (int)TemplateGenerationStatus.Failed,
            (int)TemplateGenerationStatus.Cancelled,
            options.MaxRefundAttempts,
            retryThreshold)
            .ToListAsync(cancellationToken);

        var claimedId = claimedIds.FirstOrDefault();
        if (claimedId == Guid.Empty)
        {
            await transaction.CommitAsync(cancellationToken);
            return false;
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .SingleAsync(x => x.Id == claimedId, cancellationToken);

        await TryRefundAsync(job, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return true;
    }

    public async Task<bool> CleanupNextExpiredGenerationAsync(CancellationToken cancellationToken)
    {
        if (options.GenerationRetentionDaysAfterCompletion < 0)
        {
            return false;
        }

        var cutoff = DateTime.UtcNow.AddDays(-options.GenerationRetentionDaysAfterCompletion);
        var job = await dbContext.TemplateGenerationJobs
            .Where(x => x.CompletedAtUtc != null
                && x.CompletedAtUtc <= cutoff
                && x.UserMediaDeletedAtUtc != null
                && (x.Status == TemplateGenerationStatus.Completed
                    || (x.Status == TemplateGenerationStatus.Failed
                        && (x.ChargedAtUtc == null || x.RefundedAtUtc != null))
                    || (x.Status == TemplateGenerationStatus.Cancelled
                        && (x.ChargedAtUtc == null || x.RefundedAtUtc != null))))
            .OrderBy(x => x.CompletedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        dbContext.TemplateGenerationJobs.Remove(job);
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }

    private async Task ProcessAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
        var correlationId = ResolveJobCorrelationId(job);
        using var correlationScope = CorrelationContext.Push(correlationId);
        using var jobScope = BeginJobScope(job, correlationId);

        logger.LogInformation("Template generation job started.");

        try
        {
            var readiness = TemplateGenerationService.ValidateTemplateReadiness(job.Template);
            if (readiness is not null)
            {
                await MarkFailedAsync(job, readiness, cancellationToken);
                return;
            }

            if (job.Template.TemplateType == TemplateType.Image)
            {
                await ProcessImageAsync(job, cancellationToken);
                return;
            }

            await ProcessVideoAsync(job, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(
                "Template generation job failed with unhandled exception. ElapsedMs={ElapsedMs} ExceptionType={ExceptionType}",
                ElapsedMsSince(startedAt),
                SafeLogValues.ExceptionType(exception));
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
        }
    }

    private static string ResolveJobCorrelationId(TemplateGenerationJob job)
    {
        return !string.IsNullOrWhiteSpace(job.CorrelationId) && CorrelationContext.IsValid(job.CorrelationId)
            ? job.CorrelationId
            : CorrelationContext.ResolveOrCreate();
    }

    private async Task<bool> MarkFailedAsync(
        TemplateGenerationJob job,
        Error error,
        CancellationToken cancellationToken,
        bool requireClaim = true)
    {
        using var jobScope = BeginJobScope(job, ResolveJobCorrelationId(job));

        var hasClaim = !string.IsNullOrWhiteSpace(job.LockedBy);
        if (requireClaim && !hasClaim)
        {
            logger.LogWarning(
                "Template generation job failure was ignored because it is no longer claimed. GenerationIdHash={GenerationIdHash}",
                TemplateLogSanitizer.SafeId(job.Id));
            return false;
        }

        var previousStatus = job.Status;
        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(error.Code)
            ?? TemplatesErrors.AiProviderFailed.Code;
        var safeErrorMessage = AdminFailureMessageSanitizer.Sanitize(error.Message);
        job.Status = TemplateGenerationStatus.Failed;
        job.LastErrorCode = safeErrorCode;
        job.LastErrorMessage = safeErrorMessage;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.CompletedAtUtc = job.UpdatedAtUtc;

        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            await TryRefundAsync(job, cancellationToken);
        }

        if (!await SaveJobChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, safeErrorCode);
        logger.LogError(
            "Template generation job failed. ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
            safeErrorCode,
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));

        AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerationFailed);
        if (job.GenerationMode == TemplateGenerationMode.Similar)
        {
            AddAnalyticsEvent(job, TemplateAnalyticsEventTypes.GenerateSimilarFailed);
        }
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private void AddAnalyticsEvent(TemplateGenerationJob job, string eventType)
    {
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = job.UserId == TemplateGenerationService.AdminTestUserId ? null : job.UserId,
            GenerationId = job.Id,
            EventType = eventType,
            Source = "worker",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = JsonSerializer.Serialize(new
            {
                generationId = job.Id,
                templateId = job.TemplateId,
                parentGenerationId = job.ParentGenerationId,
                newTemplateId = job.TemplateId,
                newTemplateType = NormalizeAnalyticsMediaType(job.Template?.TemplateType.ToString()),
                mediaType = NormalizeAnalyticsMediaType(job.Template?.TemplateType.ToString()),
                inputMediaType = ResolveAnalyticsInputMediaType(job),
                userPlan = (string?)null,
                creditsCost = job.TokenCost
            }),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private static string ResolveAnalyticsInputMediaType(TemplateGenerationJob job)
    {
        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase)
            && job.Template?.RequiredInputMediaType is TemplateType requiredInputMediaType)
        {
            return requiredInputMediaType.ToString().ToLowerInvariant();
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? "image"
            : "unknown";
    }

    private static string NormalizeAnalyticsMediaType(string? mediaType)
    {
        return string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant();
    }

    private async ValueTask PublishStatusChangedAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var response = TemplateGenerationService.MapResponse(job);
        await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
    }

    private Task<bool> SaveClaimedChangesAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool releaseLock = false)
    {
        if (string.IsNullOrWhiteSpace(job.LockedBy))
        {
            logger.LogWarning(
                "Template generation job update was ignored because it is no longer claimed. GenerationIdHash={GenerationIdHash}",
                TemplateLogSanitizer.SafeId(job.Id));
            return Task.FromResult(false);
        }

        dbContext.Entry(job).Property(x => x.LockedBy).OriginalValue = job.LockedBy;
        return SaveJobChangesAsync(job, cancellationToken, releaseLock);
    }

    private async Task<bool> SaveJobChangesAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool releaseLock = false)
    {
        if (releaseLock)
        {
            job.LockedAtUtc = null;
            job.LockedBy = null;
        }
        else
        {
            job.LockedAtUtc = DateTime.UtcNow;
        }

        try
        {
            if (job.Status is TemplateGenerationStatus.Completed or TemplateGenerationStatus.Failed)
            {
                await pushNotificationSender.NotifyGenerationTerminalAsync(
                    TemplateGenerationService.MapResponse(job),
                    cancellationToken);
            }

            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateConcurrencyException exception)
        {
            logger.LogWarning(
                "Template generation job update was skipped because its lock changed. GenerationIdHash={GenerationIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(job.Id),
                SafeLogValues.ExceptionType(exception));
            dbContext.ChangeTracker.Clear();
            return false;
        }
    }

    private async Task<bool> TryRefundAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
        var correlationId = ResolveJobCorrelationId(job);
        using var correlationScope = CorrelationContext.Push(correlationId);
        using var jobScope = BeginJobScope(job, correlationId);
        var attemptedAt = DateTime.UtcNow;
        job.RefundAttemptCount++;
        job.RefundLastAttemptedAtUtc = attemptedAt;

        var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (refund.IsSuccess)
        {
            if (job.RefundedAtUtc is not null)
            {
                TemplateGenerationMetrics.RecordDuplicateRefundAttempt(job);
            }

            job.RefundedAtUtc = DateTime.UtcNow;
            job.RefundLastErrorCode = null;
            TemplateGenerationMetrics.RecordJobRefunded(job);
            return true;
        }

        var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(refund.Error.Code);
        job.RefundLastErrorCode = safeErrorCode;
        TemplateGenerationMetrics.RecordRefundFailure(job, safeErrorCode ?? "templates.refund_failed");
        logger.LogWarning(
            "Template generation refund failed. ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
            safeErrorCode,
            ElapsedMsSince(startedAt));

        if (job.RefundAttemptCount >= options.MaxRefundAttempts)
        {
            logger.LogError(
                "Template generation refund failed after all retries. RefundAttemptCount={RefundAttemptCount} ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
                job.RefundAttemptCount,
                safeErrorCode,
                ElapsedMsSince(startedAt));
        }

        return false;
    }

    private IDisposable? BeginJobScope(TemplateGenerationJob job, string correlationId)
    {
        return logger.BeginScope(new Dictionary<string, object?>
        {
            ["JobId"] = job.Id,
            ["GenerationId"] = job.Id,
            ["UserId"] = job.UserId,
            ["Provider"] = ResolveProvider(job),
            ["Attempt"] = job.AttemptCount,
            ["MaxAttempts"] = options.MaxGenerationAttempts,
            ["TraceId"] = System.Diagnostics.Activity.Current?.TraceId.ToString(),
            ["CorrelationId"] = correlationId
        });
    }

    private static string ResolveProvider(TemplateGenerationJob job)
    {
        var model = job.Template.TemplateType == TemplateType.Image
            ? job.UsedPreprocessingModel ?? job.Template.ImageModel
            : job.UsedKlingModel ?? job.Template.KlingModel ?? job.UsedPreprocessingModel ?? job.Template.PreprocessingModel;

        if (string.IsNullOrWhiteSpace(model))
        {
            return "unknown";
        }

        var separatorIndex = model.IndexOf('/');
        return separatorIndex <= 0 ? model : model[..separatorIndex];
    }

    private static int ElapsedMsSince(long startedAt)
    {
        return (int)Math.Min(int.MaxValue, System.Diagnostics.Stopwatch.GetElapsedTime(startedAt).TotalMilliseconds);
    }

    private static int ElapsedMsBetween(DateTime? startedAtUtc, DateTime? completedAtUtc)
    {
        if (startedAtUtc is null || completedAtUtc is null || completedAtUtc < startedAtUtc)
        {
            return 0;
        }

        return (int)Math.Min(int.MaxValue, (completedAtUtc.Value - startedAtUtc.Value).TotalMilliseconds);
    }

    private async Task NotifyGamificationAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        if (gamificationService is null || job.UserId == TemplateGenerationService.AdminTestUserId)
        {
            return;
        }

        try
        {
            var petId = job.PetId ?? job.UserId;
            var isTemplateOfTheDay = await IsTemplateOfTheDayGenerationAsync(job, cancellationToken);
            var isPremium = false;
            if (economyService is not null)
            {
                var premiumSummary = await economyService.GetSubscriptionSummaryAsync(job.UserId, cancellationToken);
                isPremium = premiumSummary.IsSuccess && premiumSummary.Value.IsPremium;
            }

            await gamificationService.ProcessGenerationCompletedAsync(
                job.UserId,
                petId,
                job.TemplateId,
                isTemplateOfTheDay,
                isPremium,
                cancellationToken);
        }
        catch (Exception ex)
        {
            logger.LogWarning(
                "Template generation gamification sync failed. Operation={Operation} JobIdHash={JobIdHash} UserIdHash={UserIdHash} TemplateIdHash={TemplateIdHash} HasEconomyService={HasEconomyService} GenerationStillCompleted={GenerationStillCompleted} ExceptionType={ExceptionType}",
                "notify_gamification",
                SafeLogValues.StableHash(job.Id.ToString("D")),
                SafeLogValues.StableHash(job.UserId.ToString("D")),
                SafeLogValues.StableHash(job.TemplateId.ToString("D")),
                economyService is not null,
                true,
                SafeLogValues.ExceptionType(ex));
        }
    }

    private async Task<bool> IsTemplateOfTheDayGenerationAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var businessDate = ResolveTemplateOfTheDayBusinessDate(job.CreatedAtUtc);
        return await dbContext.TemplateOfTheDay
            .AsNoTracking()
            .AnyAsync(
                assignment => assignment.IsActive
                    && assignment.TemplateId == job.TemplateId
                    && assignment.StartDate <= businessDate
                    && (assignment.EndDate == null || assignment.EndDate >= businessDate),
                cancellationToken);
    }

    private DateOnly ResolveTemplateOfTheDayBusinessDate(DateTime referenceUtc)
    {
        var normalizedUtc = referenceUtc.Kind == DateTimeKind.Utc
            ? referenceUtc
            : DateTime.SpecifyKind(referenceUtc, DateTimeKind.Utc);

        var timeZone = ResolveTemplateOfTheDayBusinessTimeZone();
        return DateOnly.FromDateTime(TimeZoneInfo.ConvertTimeFromUtc(normalizedUtc, timeZone));
    }

    private TimeZoneInfo ResolveTemplateOfTheDayBusinessTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(options.TemplateOfTheDayBusinessTimeZone);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.Utc;
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.Utc;
        }
    }
}
