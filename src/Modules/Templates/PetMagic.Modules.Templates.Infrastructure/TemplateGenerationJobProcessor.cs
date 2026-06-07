using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationJobProcessor(
    TemplatesDbContext dbContext,
    IImagePreprocessor imagePreprocessor,
    IImageGenerator imageGenerator,
    IVideoMotionGenerator videoMotionGenerator,
    IGeneratedMediaImporter generatedMediaImporter,
    IMediaMetadataReader mediaMetadataReader,
    IMediaStorage mediaStorage,
    ITemplateGenerationBilling billing,
    ITemplateFeedRealtimeService realtimeService,
    ITemplateGenerationPushNotificationSender pushNotificationSender,
    TemplatesOptions options,
    ILogger<TemplateGenerationJobProcessor> logger)
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const int GlobalGenerationAdvisoryLockKey = 0x506D4745;
    private static readonly string WorkerInstanceId = $"{Environment.MachineName}:{Guid.NewGuid():N}";
    private static readonly object LocalConcurrencyLock = new();
    private static readonly HashSet<int> LocalConcurrencySlots = [];

    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var recoveredStaleJob = await RecoverNextStaleProcessingJobAsync(cancellationToken);
        await using var concurrencyLease = await TryAcquireGlobalConcurrencyLeaseAsync(cancellationToken);
        if (concurrencyLease is null)
        {
            return recoveredStaleJob;
        }

        var job = await ClaimNextAsync(cancellationToken);

        if (job is null)
        {
            if (await FailNextExhaustedQueuedJobAsync(cancellationToken))
            {
                return true;
            }

            return recoveredStaleJob;
        }

        var correlationId = ResolveJobCorrelationId(job);
        using (CorrelationContext.Push(correlationId))
        using (BeginJobScope(job, correlationId))
        {
            logger.LogInformation("Template generation job claimed. ElapsedMs={ElapsedMs}", 0);
        }

        TemplateGenerationMetrics.RecordJobClaimed(job);
        await ProcessAsync(job, cancellationToken);
        return true;
    }

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

        MarkQueuedForRecovery(staleJob, now);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobRequeued(staleJob);
            var correlationId = ResolveJobCorrelationId(staleJob);
            using (CorrelationContext.Push(correlationId))
            using (BeginJobScope(staleJob, correlationId))
            {
                logger.LogWarning("Stale template generation job recovered for retry. ElapsedMs={ElapsedMs}", 0);
            }

            dbContext.ChangeTracker.Clear();
        }
        catch (DbUpdateConcurrencyException exception)
        {
            using var staleJobScope = BeginJobScope(staleJob, ResolveJobCorrelationId(staleJob));
            logger.LogWarning(
                exception,
                "Stale template generation job recovery was skipped because its lock changed. ElapsedMs={ElapsedMs}",
                0);
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

    public async Task<bool> RetryNextRefundAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryThreshold = now.AddMilliseconds(-options.RefundRetryDelayMilliseconds);
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .Where(x => x.Status == TemplateGenerationStatus.Failed
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

    private async Task ProcessAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var startedAt = System.Diagnostics.Stopwatch.GetTimestamp();
        var correlationId = ResolveJobCorrelationId(job);
        using var correlationScope = CorrelationContext.Push(correlationId);
        using var jobScope = BeginJobScope(job, correlationId);

        logger.LogInformation(
            "Template generation job started. ElapsedMs={ElapsedMs}",
            0);

        try
        {
            var readiness = TemplateGenerationService.ValidateTemplate(
                job.Template,
                requireActiveStatus: job.UserId != TemplateGenerationService.AdminTestUserId);
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
                exception,
                "Template generation job failed with unhandled exception. ElapsedMs={ElapsedMs}",
                ElapsedMsSince(startedAt));
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
        }
    }

    private static string ResolveJobCorrelationId(TemplateGenerationJob job)
    {
        return !string.IsNullOrWhiteSpace(job.CorrelationId) && CorrelationContext.IsValid(job.CorrelationId)
            ? job.CorrelationId
            : CorrelationContext.ResolveOrCreate();
    }

    private async Task ProcessImageAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var imageModel = job.Template.ImageModel!;
        var imagePrompt = TemplateGenerationService.ResolvePrompt(job.Template.ImagePrompt, options.DefaultImagePrompt);

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        job.UsedPreprocessingModel = imageModel;

        var sourceImageUrl = await CreateProviderReadUrlAsync(job.SourceImageUrl, cancellationToken);
        if (sourceImageUrl is null)
        {
            await MarkFailedAsync(job, TemplatesErrors.MediaStorageFailed, cancellationToken);
            return;
        }

        var generated = await imageGenerator.CreateAsync(
            sourceImageUrl,
            imagePrompt,
            imageModel,
            cancellationToken);

        if (generated.IsFailure)
        {
            await MarkFailedAsync(job, generated.Error, cancellationToken);
            return;
        }

        job.PreprocessingProviderRequestId = generated.Value.ProviderRequestId;
        job.PreprocessingInferenceTimeSeconds = generated.Value.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
        job.MotionProviderCostUsd = FalModelPricing.TryGetImageGenerationCostUsd(imageModel);
        job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        var storedOutput = await generatedMediaImporter.ImportImageAsync(generated.Value.ImageUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return;
        }

        job.ResultUrl = storedOutput.Value.Url;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Succeeded;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        logger.LogInformation(
            "Template generation result uploaded. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.MediaImportCompletedAtUtc));
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await PublishStatusChangedAsync(job, cancellationToken);
        logger.LogInformation(
            "Template generation job completed. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));
    }

    private async Task ProcessVideoAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var referenceMotion = TemplateGenerationService.GetAsset(job.Template, TemplateAssetKind.ReferenceMotion)!;
        var preprocessingModel = job.Template.PreprocessingModel!;
        var preprocessingPrompt = TemplateGenerationService.ResolvePrompt(job.Template.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
        var motionModel = job.Template.KlingModel!;
        var motionPrompt = TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt);

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        job.UsedPreprocessingModel = preprocessingModel;
        job.UsedKlingModel = motionModel;

        var sourceImageUrl = await CreateProviderReadUrlAsync(job.SourceImageUrl, cancellationToken);
        if (sourceImageUrl is null)
        {
            await MarkFailedAsync(job, TemplatesErrors.MediaStorageFailed, cancellationToken);
            return;
        }

        var normalized = await imagePreprocessor.NormalizeAsync(
            sourceImageUrl,
            preprocessingModel,
            preprocessingPrompt,
            cancellationToken);

        if (normalized.IsFailure)
        {
            await MarkFailedAsync(job, normalized.Error, cancellationToken);
            return;
        }

        job.NormalizedImageUrl = normalized.Value.ImageUrl;
        job.PreprocessingProviderRequestId = normalized.Value.ProviderRequestId;
        job.PreprocessingInferenceTimeSeconds = normalized.Value.InferenceTimeSeconds;
        job.PreprocessingCompletedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.PreprocessingCompletedAtUtc.Value;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        var generated = await videoMotionGenerator.CreateAsync(
            normalized.Value.ImageUrl,
            referenceMotion.Url,
            job.Template.CharacterOrientation!.Value.ToString(),
            job.Template.KeepOriginalSound ?? true,
            motionPrompt,
            motionModel,
            cancellationToken);

        if (generated.IsFailure)
        {
            await MarkFailedAsync(job, generated.Error, cancellationToken);
            return;
        }

        job.MotionProviderRequestId = generated.Value.ProviderRequestId;
        job.MotionInferenceTimeSeconds = generated.Value.InferenceTimeSeconds;
        job.MotionGenerationCompletedAtUtc = DateTime.UtcNow;
        job.UpdatedAtUtc = job.MotionGenerationCompletedAtUtc.Value;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return;
        }

        if (!await PublishProcessingStageAsync(job, cancellationToken))
        {
            return;
        }

        var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.Value.VideoUrl, job.Id, cancellationToken);
        if (storedOutput.IsFailure)
        {
            await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
            return;
        }

        var durationResult = await mediaMetadataReader.GetVideoDurationSecondsAsync(storedOutput.Value, cancellationToken);
        if (durationResult.IsFailure)
        {
            logger.LogWarning(
                "Generated template media duration could not be determined. GenerationId={GenerationId}",
                job.Id);
        }
        else
        {
            job.OutputVideoDurationSeconds = durationResult.Value;
            job.MotionProviderCostUsd = FalModelPricing.TryCalculateMotionCostUsd(motionModel, durationResult.Value);
        }

        job.ResultUrl = storedOutput.Value.Url;
        job.MediaImportCompletedAtUtc = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Succeeded;
        job.UpdatedAtUtc = job.MediaImportCompletedAtUtc.Value;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveClaimedChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return;
        }

        logger.LogInformation(
            "Template generation result uploaded. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.MediaImportCompletedAtUtc));
        TemplateGenerationMetrics.RecordJobCompleted(job);
        await PublishStatusChangedAsync(job, cancellationToken);
        logger.LogInformation(
            "Template generation job completed. ElapsedMs={ElapsedMs}",
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));
    }

    private async Task<bool> PublishProcessingStageAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        job.Status = TemplateGenerationStatus.Processing;
        job.UpdatedAtUtc = DateTime.UtcNow;
        if (!await SaveClaimedChangesAsync(job, cancellationToken))
        {
            return false;
        }

        TemplateGenerationMetrics.RecordJobStage(job, TemplateGenerationService.ResolveStage(job));
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
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
                "Template generation job failure was ignored because it is no longer claimed. GenerationId={GenerationId}",
                job.Id);
            return false;
        }

        var previousStatus = job.Status;
        job.Status = TemplateGenerationStatus.Failed;
        job.LastErrorCode = error.Code;
        job.LastErrorMessage = error.Message;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        if (!await SaveJobChangesAsync(job, cancellationToken, releaseLock: true))
        {
            return false;
        }

        TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, error.Code);
        logger.LogError(
            "Template generation job failed. ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
            error.Code,
            ElapsedMsBetween(job.StartedAtUtc, job.CompletedAtUtc));

        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            await TryRefundAsync(job, cancellationToken);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async ValueTask PublishStatusChangedAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var response = TemplateGenerationService.MapResponse(job);
        await realtimeService.PublishGenerationStatusChangedAsync(response, cancellationToken);
        if (job.Status is TemplateGenerationStatus.Succeeded or TemplateGenerationStatus.Completed or TemplateGenerationStatus.Failed)
        {
            await pushNotificationSender.NotifyGenerationTerminalAsync(response, cancellationToken);
        }
    }

    private async Task<string?> CreateProviderReadUrlAsync(string assetUrl, CancellationToken cancellationToken)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private Task<bool> SaveClaimedChangesAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool releaseLock = false)
    {
        if (string.IsNullOrWhiteSpace(job.LockedBy))
        {
            logger.LogWarning(
                "Template generation job update was ignored because it is no longer claimed. GenerationId={GenerationId}",
                job.Id);
            return Task.FromResult(false);
        }

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
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateConcurrencyException exception)
        {
            logger.LogWarning(
                exception,
                "Template generation job update was skipped because its lock changed. GenerationId={GenerationId}",
                job.Id);
            dbContext.ChangeTracker.Clear();
            return false;
        }
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
            job.RefundedAtUtc = DateTime.UtcNow;
            job.RefundLastErrorCode = null;
            return true;
        }

        job.RefundLastErrorCode = refund.Error.Code;
        logger.LogWarning(
            "Template generation refund failed. ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
            refund.Error.Code,
            ElapsedMsSince(startedAt));

        if (job.RefundAttemptCount >= options.MaxRefundAttempts)
        {
            logger.LogError(
                "Template generation refund failed after all retries. RefundAttemptCount={RefundAttemptCount} ErrorCode={ErrorCode} ElapsedMs={ElapsedMs}",
                job.RefundAttemptCount,
                refund.Error.Code,
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
