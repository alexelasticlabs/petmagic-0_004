using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{

    private Task<PetPhoto?> ResolvePetPhotoForGenerationAsync(
        Guid userId,
        Pet pet,
        Guid? petPhotoId,
        CancellationToken cancellationToken)
    {
        var query = dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId
                && x.PetId == pet.Id
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted);

        if (petPhotoId is not null)
        {
            return query.FirstOrDefaultAsync(x => x.Id == petPhotoId.Value, cancellationToken);
        }

        return query
            .OrderByDescending(x => x.IsFavorite)
            .ThenByDescending(x => x.MediaAssetId == pet.AvatarMediaAssetId)
            .ThenByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<TemplateGenerationResponse> MapResponseWithQueueMetricsAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
        var queueEstimate = job.Status == TemplateGenerationStatus.Queued
            ? await CalculateQueueEstimateAsync(job, cancellationToken)
            : (QueueEstimate?)null;
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return await SignUserMediaUrlsAsync(
                await ApplyCompareAccessAsync(
                    ApplyWatermarkAccess(MapResponse(job, queueEstimate: null, refundAttemptLimit: options.MaxRefundAttempts), job, isPremium, hasUnlock),
                    job,
                    hasCleanAccess,
                    cancellationToken),
                cancellationToken);
        }

        return await SignUserMediaUrlsAsync(
            await ApplyCompareAccessAsync(
                ApplyWatermarkAccess(MapResponse(job, queueEstimate: queueEstimate, refundAttemptLimit: options.MaxRefundAttempts), job, isPremium, hasUnlock),
                job,
                hasCleanAccess,
                cancellationToken),
            cancellationToken);
    }

    private async Task<IReadOnlyList<TemplateGenerationResponse>> MapResponsesWithQueueMetricsAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        if (jobs.Count == 0)
        {
            return [];
        }

        var compareAccessContext = await BuildCompareAccessContextAsync(jobs, cancellationToken);
        var queuedJobs = jobs
            .Where(IsQueuedJob)
            .ToArray();
        if (queuedJobs.Length == 0)
        {
            var mapped = new List<TemplateGenerationResponse>(jobs.Count);
            foreach (var job in jobs)
            {
                var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
                var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
                mapped.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job, refundAttemptLimit: options.MaxRefundAttempts), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
            }

            return mapped;
        }

        var now = DateTime.UtcNow;
        var queuedOrderKeys = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc,
                x.QueueMediaType,
                x.QueueTier,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl
            })
            .ToArrayAsync(cancellationToken);

        var orderStateByQueuedJobId = new Dictionary<Guid, QueuedOrderState>(queuedOrderKeys.Length);
        foreach (var group in queuedOrderKeys
            .GroupBy(x => TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType)))
        {
            long videoNeedsPreprocessingAhead = 0;
            long videoReadyForGenerationAhead = 0;
            var ordered = group
                .OrderByDescending(x => ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now))
                .ThenBy(x => x.QueuedAtUtc)
                .ThenBy(x => x.Id)
                .ToArray();
            for (var index = 0; index < ordered.Length; index++)
            {
                var queued = ordered[index];
                var requiresVideoPreprocessing = RequiresVideoPreprocessing(
                    queued.QueueMediaType,
                    queued.CurrentProviderStage,
                    queued.PreprocessingCompletedAtUtc,
                    queued.NormalizedImageUrl);
                orderStateByQueuedJobId[queued.Id] = new QueuedOrderState(
                    index + 1,
                    new VideoQueueStageContext(
                        videoNeedsPreprocessingAhead,
                        videoReadyForGenerationAhead,
                        requiresVideoPreprocessing));

                if (TemplateGenerationQueue.NormalizeMediaType(queued.QueueMediaType)
                    != TemplateGenerationQueue.MediaTypeVideo)
                {
                    continue;
                }

                if (requiresVideoPreprocessing)
                {
                    videoNeedsPreprocessingAhead++;
                }
                else
                {
                    videoReadyForGenerationAhead++;
                }
            }
        }

        var capacityContext = await BuildQueueCapacityContextAsync(cancellationToken);

        var items = new List<TemplateGenerationResponse>(jobs.Count);
        foreach (var job in jobs)
        {
            var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
            var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
            if (job.Status != TemplateGenerationStatus.Queued)
            {
                items.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job, queueEstimate: null, refundAttemptLimit: options.MaxRefundAttempts), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
                continue;
            }

            var mediaType = TemplateGenerationQueue.ResolveMediaType(job);
            var orderState = orderStateByQueuedJobId.GetValueOrDefault(
                job.Id,
                new QueuedOrderState(
                    1,
                    new VideoQueueStageContext(
                        0,
                        0,
                        RequiresVideoPreprocessing(job))));
            var queueEstimate = BuildQueueEstimate(
                orderState.Position,
                mediaType,
                job.QueueTier,
                capacityContext,
                orderState.VideoStages);
            items.Add(await SignUserMediaUrlsAsync(
                ApplyCompareAccess(
                    ApplyWatermarkAccess(
                        MapResponse(job, queueEstimate: queueEstimate, refundAttemptLimit: options.MaxRefundAttempts),
                        job,
                        isPremium,
                        hasUnlock),
                    job,
                    hasCleanAccess,
                    compareAccessContext),
                cancellationToken));
        }

        return items;
    }

    private async Task<QueueEstimate> CalculateQueueEstimateAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var mediaType = TemplateGenerationQueue.ResolveMediaType(job);
        var jobScore = TemplateGenerationQueue.ResolvePriorityScore(job, now, options);
        var queuedJobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueueMediaType == mediaType)
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc,
                x.QueueTier,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl
            })
            .ToArrayAsync(cancellationToken);

        var queuedAhead = queuedJobs.Where(x =>
        {
            var score = ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now);
            return score > jobScore
                || (score == jobScore && (x.QueuedAtUtc < job.QueuedAtUtc || (x.QueuedAtUtc == job.QueuedAtUtc && x.Id.CompareTo(job.Id) < 0)));
        }).ToArray();

        var capacityContext = await BuildQueueCapacityContextAsync(cancellationToken);
        var videoStages = TemplateGenerationQueue.NormalizeMediaType(mediaType)
            == TemplateGenerationQueue.MediaTypeVideo
            ? new VideoQueueStageContext(
                queuedAhead.LongCount(x => RequiresVideoPreprocessing(
                    mediaType,
                    x.CurrentProviderStage,
                    x.PreprocessingCompletedAtUtc,
                    x.NormalizedImageUrl)),
                queuedAhead.LongCount(x => !RequiresVideoPreprocessing(
                    mediaType,
                    x.CurrentProviderStage,
                    x.PreprocessingCompletedAtUtc,
                    x.NormalizedImageUrl)),
                RequiresVideoPreprocessing(job))
            : default;
        return BuildQueueEstimate(
            queuedAhead.Length + 1,
            mediaType,
            job.QueueTier,
            capacityContext,
            videoStages);
    }

    private async Task<QueueEstimate> CalculateQueueEstimateForNewJobAsync(
        TemplateType templateType,
        string queueTier,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var mediaType = TemplateGenerationQueue.ResolveMediaType(templateType);
        var normalizedTier = TemplateGenerationQueue.NormalizeTier(queueTier);
        var newScore = TemplateGenerationQueue.ResolveTierBaseScore(normalizedTier, options);
        var queuedJobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueueMediaType == mediaType)
            .Select(x => new
            {
                x.QueuedAtUtc,
                x.QueueTier,
                x.QueueMediaType,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl
            })
            .ToArrayAsync(cancellationToken);

        var queuedAhead = queuedJobs
            .Where(x => ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now) >= newScore)
            .ToArray();
        var capacityContext = await BuildQueueCapacityContextAsync(cancellationToken);
        var videoStages = TemplateGenerationQueue.NormalizeMediaType(mediaType)
            == TemplateGenerationQueue.MediaTypeVideo
            ? new VideoQueueStageContext(
                queuedAhead.LongCount(x => RequiresVideoPreprocessing(
                    mediaType,
                    x.CurrentProviderStage,
                    x.PreprocessingCompletedAtUtc,
                    x.NormalizedImageUrl)),
                queuedAhead.LongCount(x => !RequiresVideoPreprocessing(
                    mediaType,
                    x.CurrentProviderStage,
                    x.PreprocessingCompletedAtUtc,
                    x.NormalizedImageUrl)),
                OwnNeedsPreprocessing: true)
            : default;
        return BuildQueueEstimate(
            queuedAhead.Length + 1,
            mediaType,
            normalizedTier,
            capacityContext,
            videoStages);
    }

    private int ResolveQueuedProjectionScore(string queueTier, DateTime queuedAtUtc, DateTime now)
    {
        var waitedSeconds = Math.Max(0, (now - queuedAtUtc).TotalSeconds);
        var agingSteps = (int)Math.Floor(waitedSeconds / Math.Max(1, options.QueuePriorityAgingIntervalSeconds));
        return TemplateGenerationQueue.ResolveTierBaseScore(queueTier, options)
            + agingSteps * Math.Max(0, options.QueuePriorityAgingBoost);
    }

    private QueueEstimate BuildQueueEstimate(
        int queuePosition,
        string mediaType,
        string queueTier,
        QueueCapacityContext? capacityContext,
        VideoQueueStageContext videoStages)
    {
        var normalizedMediaType = TemplateGenerationQueue.NormalizeMediaType(mediaType);
        var queuedAhead = Math.Max(0, queuePosition - 1);
        var providerImportArrivals = new List<ImportArrival>();
        var imageGenerationSeconds = ResolveImageGenerationSeconds(capacityContext);
        var videoPreprocessingSeconds = ResolveVideoPreprocessingSeconds(capacityContext);
        var videoGenerationSeconds = ResolveVideoGenerationSeconds(capacityContext);
        var imageImportSeconds = ResolveImageImportSeconds(capacityContext);
        var videoImportSeconds = ResolveVideoImportSeconds(capacityContext);

        int ownProviderSeconds;
        int providerCompletedAtSeconds;
        if (normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo)
        {
            var activePreprocessing = capacityContext?.ActiveVideoPreprocessingProvider ?? 0;
            var activeGeneration = capacityContext?.ActiveVideoGenerationProvider ?? 0;
            var videoCapacitySlots = ResolveEffectiveSlotsForEstimate(normalizedMediaType, capacityContext);
            var preprocessingSlots = Math.Min(
                videoCapacitySlots,
                ResolveVideoPreprocessingSlotsForEstimate(capacityContext));
            var generationSlots = ResolveVideoGenerationSlotsForEstimate(
                videoCapacitySlots,
                preprocessingSlots,
                hasPreprocessingWork: activePreprocessing > 0
                    || videoStages.QueuedAheadNeedsPreprocessing > 0
                    || videoStages.OwnNeedsPreprocessing);
            var videoTimeline = EstimateVideoProviderTimeline(
                activePreprocessing,
                activeGeneration,
                videoStages.QueuedAheadNeedsPreprocessing,
                videoStages.QueuedAheadReadyForGeneration,
                includeOwn: true,
                videoStages.OwnNeedsPreprocessing,
                videoPreprocessingSeconds,
                videoGenerationSeconds,
                preprocessingSlots,
                generationSlots);
            providerCompletedAtSeconds = videoTimeline.OwnCompletedAtSeconds;
            providerImportArrivals.AddRange(videoTimeline.AheadCompletionTimes.Select(
                completedAt => new ImportArrival(completedAt, videoImportSeconds, IsOwn: false)));
            ownProviderSeconds = videoStages.OwnNeedsPreprocessing
                ? checked(videoPreprocessingSeconds + videoGenerationSeconds)
                : videoGenerationSeconds;

            var imageTimeline = EstimateSingleStageProviderTimeline(
                capacityContext?.ActiveImageProvider ?? 0,
                capacityContext?.QueuedImage ?? 0,
                includeOwn: false,
                imageGenerationSeconds,
                ResolveEffectiveSlotsForEstimate(
                    TemplateGenerationQueue.MediaTypeImage,
                    capacityContext,
                    videoSlotsToPreserve: videoCapacitySlots));
            providerImportArrivals.AddRange(imageTimeline.AheadCompletionTimes.Select(
                completedAt => new ImportArrival(completedAt, imageImportSeconds, IsOwn: false)));
        }
        else
        {
            var videoCapacitySlots = ResolveEffectiveSlotsForEstimate(
                TemplateGenerationQueue.MediaTypeVideo,
                capacityContext);
            var videoPreprocessingSlots = Math.Min(
                videoCapacitySlots,
                ResolveVideoPreprocessingSlotsForEstimate(capacityContext));
            var videoGenerationSlots = ResolveVideoGenerationSlotsForEstimate(
                videoCapacitySlots,
                videoPreprocessingSlots,
                hasPreprocessingWork: (capacityContext?.ActiveVideoPreprocessingProvider ?? 0) > 0
                    || (capacityContext?.QueuedVideoNeedsPreprocessing ?? 0) > 0);
            var hasVideoWork = capacityContext is { } contextWithVideoWork
                && (contextWithVideoWork.ActiveVideo > 0
                    || contextWithVideoWork.QueuedVideoNeedsPreprocessing > 0
                    || contextWithVideoWork.QueuedVideoReadyForGeneration > 0);
            var generationSlots = ResolveEffectiveSlotsForEstimate(
                normalizedMediaType,
                capacityContext,
                videoSlotsToPreserve: hasVideoWork ? videoCapacitySlots : 0);
            var activeGeneration = capacityContext?.ActiveImageProvider ?? 0;
            var imageTimeline = EstimateSingleStageProviderTimeline(
                activeGeneration,
                queuedAhead,
                includeOwn: true,
                imageGenerationSeconds,
                generationSlots);
            providerCompletedAtSeconds = imageTimeline.OwnCompletedAtSeconds;
            providerImportArrivals.AddRange(imageTimeline.AheadCompletionTimes.Select(
                completedAt => new ImportArrival(completedAt, imageImportSeconds, IsOwn: false)));
            ownProviderSeconds = imageGenerationSeconds;

            var videoTimeline = EstimateVideoProviderTimeline(
                capacityContext?.ActiveVideoPreprocessingProvider ?? 0,
                capacityContext?.ActiveVideoGenerationProvider ?? 0,
                capacityContext?.QueuedVideoNeedsPreprocessing ?? 0,
                capacityContext?.QueuedVideoReadyForGeneration ?? 0,
                includeOwn: false,
                ownNeedsPreprocessing: false,
                videoPreprocessingSeconds,
                videoGenerationSeconds,
                videoPreprocessingSlots,
                videoGenerationSlots);
            providerImportArrivals.AddRange(videoTimeline.AheadCompletionTimes.Select(
                completedAt => new ImportArrival(completedAt, videoImportSeconds, IsOwn: false)));
        }

        var ownImportSeconds = ResolveImportSeconds(normalizedMediaType, capacityContext);
        var estimatedTotalSeconds = EstimateImportCompletionSeconds(
            capacityContext?.ActiveImageImports ?? 0,
            capacityContext?.ActiveVideoImports ?? 0,
            providerImportArrivals,
            providerCompletedAtSeconds,
            ownImportSeconds,
            imageImportSeconds,
            videoImportSeconds,
            Math.Max(1, options.MediaImportConcurrency));
        var ownServiceSeconds = checked(ownProviderSeconds + ownImportSeconds);
        var estimatedWaitSeconds = Math.Max(0, estimatedTotalSeconds - ownServiceSeconds);
        var lane = TemplateGenerationQueue.ResolveLane(normalizedMediaType, queueTier);
        var reason = estimatedWaitSeconds > 0 ? $"backlog:{lane}" : $"capacity:{lane}";
        return new QueueEstimate(
            queuePosition,
            estimatedWaitSeconds,
            estimatedTotalSeconds,
            DateTime.UtcNow.AddSeconds(estimatedTotalSeconds),
            normalizedMediaType,
            TemplateGenerationQueue.NormalizeTier(queueTier),
            reason,
            Math.Max(30, Math.Min(300, estimatedWaitSeconds / 2)));
    }

    private static readonly TemplateGenerationProviderAttemptState[] QueueEstimateActiveAttemptStates =
    [
        TemplateGenerationProviderAttemptState.SubmitReserved,
        TemplateGenerationProviderAttemptState.Submitting,
        TemplateGenerationProviderAttemptState.ProviderQueued,
        TemplateGenerationProviderAttemptState.ProviderProcessing,
        TemplateGenerationProviderAttemptState.SubmissionUnknown
    ];

    private static readonly TemplateGenerationStatus[] QueueEstimateProviderStatuses =
    [
        TemplateGenerationStatus.Processing,
        TemplateGenerationStatus.Retrying,
        TemplateGenerationStatus.SubmittingToProvider,
        TemplateGenerationStatus.ProviderQueued,
        TemplateGenerationStatus.ProviderProcessing
    ];

    private async Task<QueueCapacityContext> BuildQueueCapacityContextAsync(CancellationToken cancellationToken)
    {
        var activeAttemptCounts = await dbContext.TemplateGenerationProviderAttempts
            .AsNoTracking()
            .Where(x => QueueEstimateActiveAttemptStates.Contains(x.State))
            .GroupBy(x => x.Stage)
            .Select(x => new { Stage = x.Key, Count = x.LongCount() })
            .ToArrayAsync(cancellationToken);
        var activeImageProvider = activeAttemptCounts
            .Where(x => x.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration)
            .Sum(x => x.Count);
        var activeVideoPreprocessingProvider = activeAttemptCounts
            .Where(x => x.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing)
            .Sum(x => x.Count);
        var activeVideoGenerationProvider = activeAttemptCounts
            .Where(x => x.Stage == TemplateGenerationProviderAttemptStage.VideoGeneration)
            .Sum(x => x.Count);

        var legacyProviderJobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => QueueEstimateProviderStatuses.Contains(x.Status)
                && !x.ProviderAttempts.Any(attempt => QueueEstimateActiveAttemptStates.Contains(attempt.State)))
            .Select(x => new
            {
                x.QueueMediaType,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl
            })
            .ToArrayAsync(cancellationToken);
        foreach (var legacyJob in legacyProviderJobs)
        {
            if (TemplateGenerationQueue.NormalizeMediaType(legacyJob.QueueMediaType)
                == TemplateGenerationQueue.MediaTypeImage)
            {
                activeImageProvider++;
                continue;
            }

            var isVideoGeneration = string.Equals(
                    legacyJob.CurrentProviderStage,
                    "video_generation",
                    StringComparison.Ordinal)
                || (legacyJob.PreprocessingCompletedAtUtc is not null
                    && !string.IsNullOrWhiteSpace(legacyJob.NormalizedImageUrl));
            if (isVideoGeneration)
            {
                activeVideoGenerationProvider++;
            }
            else
            {
                activeVideoPreprocessingProvider++;
            }
        }

        var activeImportCounts = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.ImportingMedia)
            .GroupBy(x => x.QueueMediaType)
            .Select(x => new { MediaType = x.Key, Count = x.LongCount() })
            .ToArrayAsync(cancellationToken);
        var activeImageImports = activeImportCounts
            .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeImage)
            .Sum(x => x.Count);
        var activeVideoImports = activeImportCounts
            .Where(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType) == TemplateGenerationQueue.MediaTypeVideo)
            .Sum(x => x.Count);

        var queuedJobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
            .Select(x => new
            {
                x.QueueMediaType,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl
            })
            .ToArrayAsync(cancellationToken);
        var queuedImage = queuedJobs.LongCount(x =>
            TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType)
            == TemplateGenerationQueue.MediaTypeImage);
        var queuedVideoNeedsPreprocessing = queuedJobs.LongCount(x =>
            RequiresVideoPreprocessing(
                x.QueueMediaType,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl));
        var queuedVideoReadyForGeneration = queuedJobs.LongCount(x =>
            TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType)
                == TemplateGenerationQueue.MediaTypeVideo
            && !RequiresVideoPreprocessing(
                x.QueueMediaType,
                x.CurrentProviderStage,
                x.PreprocessingCompletedAtUtc,
                x.NormalizedImageUrl));

        var sampleCutoffUtc = DateTime.UtcNow.AddDays(-7);
        var imageGenerationP90Seconds = await LoadProviderP90DurationSecondsAsync(
            TemplateGenerationProviderAttemptStage.ImageGeneration,
            sampleCutoffUtc,
            cancellationToken);
        var videoPreprocessingP90Seconds = await LoadProviderP90DurationSecondsAsync(
            TemplateGenerationProviderAttemptStage.VideoPreprocessing,
            sampleCutoffUtc,
            cancellationToken);
        var videoGenerationP90Seconds = await LoadProviderP90DurationSecondsAsync(
            TemplateGenerationProviderAttemptStage.VideoGeneration,
            sampleCutoffUtc,
            cancellationToken);
        var imageImportP90Seconds = await LoadImportP90DurationSecondsAsync(
            TemplateGenerationQueue.MediaTypeImage,
            sampleCutoffUtc,
            cancellationToken);
        var videoImportP90Seconds = await LoadImportP90DurationSecondsAsync(
            TemplateGenerationQueue.MediaTypeVideo,
            sampleCutoffUtc,
            cancellationToken);

        TemplateGenerationConcurrencyProfile? runtimeProfile = null;
        if (options.GenerationSchedulerV2Enabled && runtimePolicyProvider is not null)
        {
            var runtimePolicy = await runtimePolicyProvider.GetRuntimePolicyAsync(cancellationToken);
            runtimeProfile = runtimePolicy.EffectiveProfile;
        }

        return new QueueCapacityContext(
            activeImageProvider,
            activeVideoPreprocessingProvider,
            activeVideoGenerationProvider,
            activeImageImports,
            activeVideoImports,
            queuedImage,
            queuedVideoNeedsPreprocessing,
            queuedVideoReadyForGeneration,
            imageGenerationP90Seconds,
            videoPreprocessingP90Seconds,
            videoGenerationP90Seconds,
            imageImportP90Seconds,
            videoImportP90Seconds,
            runtimeProfile);
    }

    private async Task<int?> LoadProviderP90DurationSecondsAsync(
        TemplateGenerationProviderAttemptStage stage,
        DateTime cutoffUtc,
        CancellationToken cancellationToken)
    {
        var samples = await dbContext.TemplateGenerationProviderAttempts
            .AsNoTracking()
            .Where(x => x.State == TemplateGenerationProviderAttemptState.Completed
                && x.Stage == stage
                && x.SubmittedAtUtc != null
                && x.ProviderCompletedAtUtc != null
                && x.ProviderCompletedAtUtc >= cutoffUtc)
            .OrderByDescending(x => x.ProviderCompletedAtUtc)
            .Take(600)
            .Select(x => new
            {
                SubmittedAtUtc = x.SubmittedAtUtc!.Value,
                ProviderCompletedAtUtc = x.ProviderCompletedAtUtc!.Value
            })
            .ToArrayAsync(cancellationToken);
        return CalculateP90DurationSeconds(
            samples.Select(x => x.ProviderCompletedAtUtc - x.SubmittedAtUtc));
    }

    private async Task<int?> LoadImportP90DurationSecondsAsync(
        string mediaType,
        DateTime cutoffUtc,
        CancellationToken cancellationToken)
    {
        var samples = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Completed
                && x.QueueMediaType == mediaType
                && x.ImportStartedAtUtc != null
                && x.MediaImportCompletedAtUtc != null
                && x.MediaImportCompletedAtUtc >= cutoffUtc)
            .OrderByDescending(x => x.MediaImportCompletedAtUtc)
            .Take(400)
            .Select(x => new
            {
                ImportStartedAtUtc = x.ImportStartedAtUtc!.Value,
                MediaImportCompletedAtUtc = x.MediaImportCompletedAtUtc!.Value
            })
            .ToArrayAsync(cancellationToken);
        return CalculateP90DurationSeconds(
            samples.Select(x => x.MediaImportCompletedAtUtc - x.ImportStartedAtUtc));
    }

    private int ResolveImageGenerationSeconds(QueueCapacityContext? capacityContext) =>
        capacityContext?.ImageGenerationP90Seconds
        ?? Math.Max(1, options.EstimatedImageGenerationSeconds);

    private int ResolveVideoPreprocessingSeconds(QueueCapacityContext? capacityContext) =>
        capacityContext?.VideoPreprocessingP90Seconds
        ?? Math.Max(1, options.EstimatedVideoPreprocessingSeconds);

    private int ResolveVideoGenerationSeconds(QueueCapacityContext? capacityContext) =>
        capacityContext?.VideoGenerationP90Seconds
        ?? Math.Max(1, options.EstimatedVideoGenerationSeconds);

    private int ResolveImageImportSeconds(QueueCapacityContext? capacityContext) =>
        capacityContext?.ImageImportP90Seconds
        ?? Math.Max(1, options.EstimatedImageImportSeconds);

    private int ResolveVideoImportSeconds(QueueCapacityContext? capacityContext) =>
        capacityContext?.VideoImportP90Seconds
        ?? Math.Max(1, options.EstimatedVideoImportSeconds);

    private int ResolveImportSeconds(string normalizedMediaType, QueueCapacityContext? capacityContext) =>
        normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
            ? ResolveVideoImportSeconds(capacityContext)
            : ResolveImageImportSeconds(capacityContext);

    private static int? CalculateP90DurationSeconds(IEnumerable<TimeSpan> durations)
    {
        var ordered = durations
            .Where(duration => duration > TimeSpan.Zero && duration <= TimeSpan.FromHours(2))
            .Select(duration => (int)Math.Ceiling(duration.TotalSeconds))
            .Order()
            .ToArray();
        if (ordered.Length < 10)
        {
            return null;
        }

        var index = (int)Math.Ceiling(ordered.Length * 0.9) - 1;
        return ordered[Math.Clamp(index, 0, ordered.Length - 1)];
    }

    private int ResolveEffectiveSlotsForEstimate(
        string normalizedMediaType,
        QueueCapacityContext? capacityContext,
        int videoSlotsToPreserve = 0)
    {
        var runtimeProfile = capacityContext?.RuntimeProfile;
        if (normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo)
        {
            var reserved = runtimeProfile?.VideoReservedConcurrentGenerations
                ?? ResolveVideoReservedConcurrency();
            var estimatedSlots = !CanEstimateVideoBorrow(capacityContext)
                ? Math.Max(1, reserved)
                : Math.Max(1, Math.Min(
                    runtimeProfile?.VideoMaxConcurrentGenerations ?? options.VideoMaxConcurrentGenerations,
                    reserved + (runtimeProfile?.VideoBorrowMaxConcurrentGenerations
                        ?? ResolveVideoBorrowMaxConcurrency())));
            if (capacityContext is null)
            {
                return estimatedSlots;
            }

            // Image and video attempts consume the same durable provider capacity. Keep the ETA
            // lane count inside the global limit even when the media-specific limits overlap.
            var videoGlobalMax = runtimeProfile?.GlobalMaxConcurrentGenerations
                ?? options.GlobalMaxConcurrentGenerations;
            var globalSlotsAvailableAlongsideActiveImages = Math.Max(
                1,
                videoGlobalMax - ToSaturatedInt(capacityContext.Value.ActiveImage));
            return Math.Max(1, Math.Min(estimatedSlots, globalSlotsAvailableAlongsideActiveImages));
        }

        if (capacityContext is null)
        {
            return Math.Max(1, options.ImageMaxConcurrentGenerations);
        }

        var context = capacityContext.Value;
        var imageMax = runtimeProfile?.ImageMaxConcurrentGenerations
            ?? options.ImageMaxConcurrentGenerations;
        var globalMax = runtimeProfile?.GlobalMaxConcurrentGenerations
            ?? options.GlobalMaxConcurrentGenerations;
        var videoReserved = runtimeProfile?.VideoReservedConcurrentGenerations
            ?? ResolveVideoReservedConcurrency();
        var hasVideoBacklog = videoSlotsToPreserve > 0
            || context.QueuedVideoNeedsPreprocessing > 0
            || context.QueuedVideoReadyForGeneration > 0;
        var videoCapacityToPreserve = hasVideoBacklog
            ? Math.Max(context.ActiveVideo, Math.Max(videoReserved, videoSlotsToPreserve))
            : context.ActiveVideo;
        var globalSlotsAvailableAlongsideVideo = Math.Max(
            1,
            globalMax - ToSaturatedInt(videoCapacityToPreserve));
        return Math.Max(1, Math.Min(imageMax, globalSlotsAvailableAlongsideVideo));
    }

    private int ResolveVideoPreprocessingSlotsForEstimate(QueueCapacityContext? capacityContext)
    {
        return Math.Max(
            1,
            capacityContext?.RuntimeProfile?.VideoPreprocessingMaxConcurrentGenerations
                ?? options.VideoPreprocessingMaxConcurrentGenerations);
    }

    private static int ResolveVideoGenerationSlotsForEstimate(
        int videoCapacitySlots,
        int preprocessingSlots,
        bool hasPreprocessingWork)
    {
        var boundedVideoCapacity = Math.Max(1, videoCapacitySlots);
        if (!hasPreprocessingWork || boundedVideoCapacity == 1)
        {
            return boundedVideoCapacity;
        }

        // Preprocessing and motion generation reserve attempts from the same video/global
        // provider capacity. Keep their ETA lanes disjoint while preprocessing is backlogged;
        // otherwise the estimate can admit work that the durable scheduler cannot run.
        return Math.Max(
            1,
            boundedVideoCapacity - Math.Min(preprocessingSlots, boundedVideoCapacity - 1));
    }

    private static ProviderTimeline EstimateVideoProviderTimeline(
        long activePreprocessing,
        long activeGeneration,
        long queuedAheadNeedsPreprocessing,
        long queuedAheadReadyForGeneration,
        bool includeOwn,
        bool ownNeedsPreprocessing,
        int preprocessingSeconds,
        int generationSeconds,
        int preprocessingSlots,
        int generationSlots)
    {
        var preprocessingLaneAvailableAt = new long[Math.Max(1, preprocessingSlots)];
        var generationReleaseTimes = new List<long>();

        for (long index = 0; index < activePreprocessing; index++)
        {
            generationReleaseTimes.Add(ScheduleLane(
                preprocessingLaneAvailableAt,
                releaseAtSeconds: 0,
                preprocessingSeconds));
        }

        for (long index = 0; index < queuedAheadNeedsPreprocessing; index++)
        {
            generationReleaseTimes.Add(ScheduleLane(
                preprocessingLaneAvailableAt,
                releaseAtSeconds: 0,
                preprocessingSeconds));
        }

        var ownGenerationReleaseAt = includeOwn && ownNeedsPreprocessing
            ? ScheduleLane(
                preprocessingLaneAvailableAt,
                releaseAtSeconds: 0,
                preprocessingSeconds)
            : 0;

        for (long index = 0; index < queuedAheadReadyForGeneration; index++)
        {
            generationReleaseTimes.Add(0);
        }

        var generationLaneAvailableAt = new long[Math.Max(1, generationSlots)];
        var aheadCompletionTimes = new List<long>();
        for (long index = 0; index < activeGeneration; index++)
        {
            aheadCompletionTimes.Add(ScheduleLane(
                generationLaneAvailableAt,
                releaseAtSeconds: 0,
                generationSeconds));
        }

        var queuedGenerationWork = generationReleaseTimes
            .Select(releaseAt => new ProviderStageArrival(releaseAt, IsOwn: false))
            .ToList();
        if (includeOwn)
        {
            queuedGenerationWork.Add(new ProviderStageArrival(ownGenerationReleaseAt, IsOwn: true));
        }

        long ownCompletedAt = 0;
        foreach (var work in queuedGenerationWork
            .OrderBy(x => x.ReleaseAtSeconds)
            .ThenBy(x => x.IsOwn))
        {
            var completedAt = ScheduleLane(
                generationLaneAvailableAt,
                work.ReleaseAtSeconds,
                generationSeconds);
            if (work.IsOwn)
            {
                ownCompletedAt = completedAt;
            }
            else
            {
                aheadCompletionTimes.Add(completedAt);
            }
        }

        return new ProviderTimeline(
            ToSaturatedInt(ownCompletedAt),
            aheadCompletionTimes);
    }

    private static ProviderTimeline EstimateSingleStageProviderTimeline(
        long active,
        long queuedAhead,
        bool includeOwn,
        int durationSeconds,
        int slots)
    {
        var laneAvailableAt = new long[Math.Max(1, slots)];
        var aheadCompletionTimes = new List<long>();
        for (long index = 0; index < active; index++)
        {
            aheadCompletionTimes.Add(ScheduleLane(
                laneAvailableAt,
                releaseAtSeconds: 0,
                durationSeconds));
        }

        for (long index = 0; index < queuedAhead; index++)
        {
            aheadCompletionTimes.Add(ScheduleLane(
                laneAvailableAt,
                releaseAtSeconds: 0,
                durationSeconds));
        }

        var ownCompletedAt = includeOwn
            ? ScheduleLane(laneAvailableAt, releaseAtSeconds: 0, durationSeconds)
            : 0;
        return new ProviderTimeline(
            ToSaturatedInt(ownCompletedAt),
            aheadCompletionTimes);
    }

    private static int EstimateImportCompletionSeconds(
        long activeImageImports,
        long activeVideoImports,
        IReadOnlyCollection<ImportArrival> providerArrivals,
        int ownProviderCompletedAtSeconds,
        int ownImportSeconds,
        int imageImportSeconds,
        int videoImportSeconds,
        int importSlots)
    {
        var importLaneAvailableAt = new long[Math.Max(1, importSlots)];
        for (long index = 0; index < activeImageImports; index++)
        {
            ScheduleLane(importLaneAvailableAt, releaseAtSeconds: 0, imageImportSeconds);
        }

        for (long index = 0; index < activeVideoImports; index++)
        {
            ScheduleLane(importLaneAvailableAt, releaseAtSeconds: 0, videoImportSeconds);
        }

        var arrivals = new List<ImportArrival>(providerArrivals.Count + 1);
        arrivals.AddRange(providerArrivals);
        arrivals.Add(new ImportArrival(
            ownProviderCompletedAtSeconds,
            ownImportSeconds,
            IsOwn: true));

        foreach (var arrival in arrivals
            .OrderBy(x => x.ReleaseAtSeconds)
            .ThenBy(x => x.IsOwn)
            .ThenByDescending(x => x.DurationSeconds))
        {
            var completedAt = ScheduleLane(
                importLaneAvailableAt,
                arrival.ReleaseAtSeconds,
                arrival.DurationSeconds);
            if (arrival.IsOwn)
            {
                return ToSaturatedInt(completedAt);
            }
        }

        return int.MaxValue;
    }

    private static int ToSaturatedInt(long value) =>
        value >= int.MaxValue ? int.MaxValue : (int)Math.Max(0, value);

    private static long ScheduleLane(long[] laneAvailableAt, long releaseAtSeconds, int durationSeconds)
    {
        var earliestLaneIndex = 0;
        for (var index = 1; index < laneAvailableAt.Length; index++)
        {
            if (laneAvailableAt[index] < laneAvailableAt[earliestLaneIndex])
            {
                earliestLaneIndex = index;
            }
        }

        var startedAt = Math.Max(releaseAtSeconds, laneAvailableAt[earliestLaneIndex]);
        var safeDuration = Math.Max(1, durationSeconds);
        var completedAt = startedAt > long.MaxValue - safeDuration
            ? long.MaxValue
            : startedAt + safeDuration;
        laneAvailableAt[earliestLaneIndex] = completedAt;
        return completedAt;
    }

    private bool CanEstimateVideoBorrow(QueueCapacityContext? capacityContext)
    {
        if (!options.EnableElasticLaneBorrowing)
        {
            return false;
        }

        if (capacityContext is null)
        {
            return false;
        }

        var context = capacityContext.Value;
        var runtimeProfile = context.RuntimeProfile;
        var videoMax = runtimeProfile?.VideoMaxConcurrentGenerations
            ?? options.VideoMaxConcurrentGenerations;
        var videoReserved = runtimeProfile?.VideoReservedConcurrentGenerations
            ?? ResolveVideoReservedConcurrency();
        var videoBorrowMax = runtimeProfile?.VideoBorrowMaxConcurrentGenerations
            ?? ResolveVideoBorrowMaxConcurrency();
        var imageProtected = runtimeProfile?.ImageProtectedConcurrentGenerations
            ?? ResolveImageProtectedConcurrency();
        var imageMax = runtimeProfile?.ImageMaxConcurrentGenerations
            ?? options.ImageMaxConcurrentGenerations;
        if (context.ActiveVideo >= videoMax)
        {
            return false;
        }

        if (videoBorrowMax <= 0
            || Math.Max(0, context.ActiveVideo - videoReserved) >= videoBorrowMax)
        {
            return false;
        }

        if (context.ActiveImage + imageProtected > imageMax)
        {
            return false;
        }

        if (context.QueuedImage == 0)
        {
            return options.AllowVideoBorrowWhenImageQueueEmpty;
        }

        var protectedSlots = Math.Max(1, imageProtected);
        var backlogUnits = Math.Max(0, context.ActiveImage + context.QueuedImage - protectedSlots);
        var imageEstimatedWaitSeconds = (int)Math.Ceiling(
            backlogUnits * ResolveImageGenerationSeconds(context) / (double)protectedSlots);
        return imageEstimatedWaitSeconds <= options.AllowVideoBorrowWhenImageEstimatedWaitBelowSeconds;
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

    private readonly record struct QueueCapacityContext(
        long ActiveImageProvider,
        long ActiveVideoPreprocessingProvider,
        long ActiveVideoGenerationProvider,
        long ActiveImageImports,
        long ActiveVideoImports,
        long QueuedImage,
        long QueuedVideoNeedsPreprocessing,
        long QueuedVideoReadyForGeneration,
        int? ImageGenerationP90Seconds,
        int? VideoPreprocessingP90Seconds,
        int? VideoGenerationP90Seconds,
        int? ImageImportP90Seconds,
        int? VideoImportP90Seconds,
        TemplateGenerationConcurrencyProfile? RuntimeProfile)
    {
        internal long ActiveImage => ActiveImageProvider;

        internal long ActiveVideo => ActiveVideoPreprocessingProvider + ActiveVideoGenerationProvider;
    }

    private static bool RequiresVideoPreprocessing(TemplateGenerationJob job) =>
        RequiresVideoPreprocessing(
            job.QueueMediaType,
            job.CurrentProviderStage,
            job.PreprocessingCompletedAtUtc,
            job.NormalizedImageUrl);

    private static bool RequiresVideoPreprocessing(
        string mediaType,
        string? currentProviderStage,
        DateTime? preprocessingCompletedAtUtc,
        string? normalizedImageUrl)
    {
        if (TemplateGenerationQueue.NormalizeMediaType(mediaType)
            != TemplateGenerationQueue.MediaTypeVideo)
        {
            return false;
        }

        return !string.Equals(currentProviderStage, "video_generation", StringComparison.Ordinal)
            && (preprocessingCompletedAtUtc is null || string.IsNullOrWhiteSpace(normalizedImageUrl));
    }

    private readonly record struct QueuedOrderState(
        int Position,
        VideoQueueStageContext VideoStages);

    private readonly record struct VideoQueueStageContext(
        long QueuedAheadNeedsPreprocessing,
        long QueuedAheadReadyForGeneration,
        bool OwnNeedsPreprocessing);

    private readonly record struct ProviderTimeline(
        int OwnCompletedAtSeconds,
        IReadOnlyList<long> AheadCompletionTimes);

    private readonly record struct ProviderStageArrival(
        long ReleaseAtSeconds,
        bool IsOwn);

    private readonly record struct ImportArrival(
        long ReleaseAtSeconds,
        int DurationSeconds,
        bool IsOwn);

    private static bool IsQueuedJob(TemplateGenerationJob job)
    {
        return job.Status == TemplateGenerationStatus.Queued;
    }

    private int ResolveMaxEstimatedWaitSeconds(string mediaType, string tier)
    {
        var normalizedMediaType = TemplateGenerationQueue.NormalizeMediaType(mediaType);
        return TemplateGenerationQueue.NormalizeTier(tier) switch
        {
            TemplateGenerationQueue.TierAdmin => int.MaxValue,
            TemplateGenerationQueue.TierPrivileged => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.PrivilegedVideoMaxEstimatedWaitSeconds
                : options.PrivilegedImageMaxEstimatedWaitSeconds,
            TemplateGenerationQueue.TierPremium => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.PremiumVideoMaxEstimatedWaitSeconds
                : options.PremiumImageMaxEstimatedWaitSeconds,
            _ => normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
                ? options.FreeVideoMaxEstimatedWaitSeconds
                : options.FreeImageMaxEstimatedWaitSeconds
        };
    }

    internal readonly record struct QueueEstimate(
        int QueuePosition,
        int EstimatedWaitSeconds,
        int EstimatedTotalSeconds,
        DateTime EstimatedCompletionAtUtc,
        string MediaType,
        string PriorityClass,
        string Reason,
        int RetryAfterSeconds);

}
