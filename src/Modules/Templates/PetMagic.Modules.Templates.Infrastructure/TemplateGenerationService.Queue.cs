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
                    ApplyWatermarkAccess(MapResponse(job, queueEstimate: null), job, isPremium, hasUnlock),
                    job,
                    hasCleanAccess,
                    cancellationToken),
                cancellationToken);
        }

        return await SignUserMediaUrlsAsync(
            await ApplyCompareAccessAsync(
                ApplyWatermarkAccess(MapResponse(job, queueEstimate: queueEstimate), job, isPremium, hasUnlock),
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
            .Where(IsClaimableQueuedJob)
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
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
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
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && (x.ChargedAtUtc != null || x.UserId == AdminTestUserId))
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc,
                x.QueueMediaType,
                x.QueueTier
            })
            .ToArrayAsync(cancellationToken);

        var positionByQueuedJobId = queuedOrderKeys
            .GroupBy(x => TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType))
            .SelectMany(group => group
                .OrderByDescending(x => ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now))
                .ThenBy(x => x.QueuedAtUtc)
                .ThenBy(x => x.Id)
                .Select((job, index) => new
                {
                    job.Id,
                    Position = index + 1
                }))
            .ToDictionary(x => x.Id, x => x.Position);

        var processingCountByMediaType = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status))
            .GroupBy(x => x.QueueMediaType)
            .Select(x => new { MediaType = x.Key, Count = x.Count() })
            .ToDictionaryAsync(x => TemplateGenerationQueue.NormalizeMediaType(x.MediaType), x => x.Count, cancellationToken);
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
                        ApplyWatermarkAccess(MapResponse(job, queueEstimate: null), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
                continue;
            }

            var mediaType = TemplateGenerationQueue.ResolveMediaType(job);
            var queuePosition = positionByQueuedJobId.GetValueOrDefault(job.Id, 1);
            var queueEstimate = BuildQueueEstimate(
                queuePosition,
                processingCountByMediaType.GetValueOrDefault(mediaType),
                mediaType,
                job.QueueTier,
                capacityContext);
            items.Add(await SignUserMediaUrlsAsync(
                ApplyCompareAccess(
                    ApplyWatermarkAccess(
                        MapResponse(job, queueEstimate: queueEstimate),
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
                && (x.ChargedAtUtc != null || x.UserId == AdminTestUserId)
                && x.QueueMediaType == mediaType)
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc,
                x.QueueTier
            })
            .ToArrayAsync(cancellationToken);

        var queuedAhead = queuedJobs.Count(x =>
        {
            var score = ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now);
            return score > jobScore
                || (score == jobScore && (x.QueuedAtUtc < job.QueuedAtUtc || (x.QueuedAtUtc == job.QueuedAtUtc && x.Id.CompareTo(job.Id) < 0)));
        });

        var processingCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)
                && x.QueueMediaType == mediaType,
                cancellationToken);

        var capacityContext = await BuildQueueCapacityContextAsync(cancellationToken);
        return BuildQueueEstimate(queuedAhead + 1, processingCount, mediaType, job.QueueTier, capacityContext);
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
                && (x.ChargedAtUtc != null || x.UserId == AdminTestUserId)
                && x.QueueMediaType == mediaType)
            .Select(x => new
            {
                x.QueuedAtUtc,
                x.QueueTier
            })
            .ToArrayAsync(cancellationToken);

        var queuedAhead = queuedJobs.Count(x => ResolveQueuedProjectionScore(x.QueueTier, x.QueuedAtUtc, now) >= newScore);
        var processingCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)
                && x.QueueMediaType == mediaType,
                cancellationToken);

        var capacityContext = await BuildQueueCapacityContextAsync(cancellationToken);
        return BuildQueueEstimate(queuedAhead + 1, processingCount, mediaType, normalizedTier, capacityContext);
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
        int processingCount,
        string mediaType,
        string queueTier,
        QueueCapacityContext? capacityContext = null)
    {
        var normalizedMediaType = TemplateGenerationQueue.NormalizeMediaType(mediaType);
        var slots = ResolveEffectiveSlotsForEstimate(normalizedMediaType, capacityContext);
        var durationSeconds = normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo
            ? Math.Max(1, options.EstimatedVideoGenerationSeconds)
            : Math.Max(1, options.EstimatedImageGenerationSeconds);
        var estimatedWaitSeconds = (int)Math.Ceiling(Math.Max(0, processingCount + queuePosition - 1) * durationSeconds / (double)slots);
        var estimatedTotalSeconds = estimatedWaitSeconds + durationSeconds;
        var lane = TemplateGenerationQueue.ResolveLane(normalizedMediaType, queueTier);
        var reason = processingCount + queuePosition > slots ? $"backlog:{lane}" : $"capacity:{lane}";
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

    private async Task<QueueCapacityContext> BuildQueueCapacityContextAsync(CancellationToken cancellationToken)
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
                && (x.ChargedAtUtc != null || x.UserId == AdminTestUserId)
                && x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage,
                cancellationToken);

        return new QueueCapacityContext(activeImage, activeVideo, queuedImage);
    }

    private int ResolveEffectiveSlotsForEstimate(string normalizedMediaType, QueueCapacityContext? capacityContext)
    {
        if (normalizedMediaType == TemplateGenerationQueue.MediaTypeVideo)
        {
            var reserved = ResolveVideoReservedConcurrency();
            if (!CanEstimateVideoBorrow(capacityContext))
            {
                return Math.Max(1, reserved);
            }

            return Math.Max(1, Math.Min(
                options.VideoMaxConcurrentGenerations,
                reserved + ResolveVideoBorrowMaxConcurrency()));
        }

        if (capacityContext is null)
        {
            return Math.Max(1, options.ImageMaxConcurrentGenerations);
        }

        var context = capacityContext.Value;
        var borrowedVideo = Math.Max(0, context.ActiveVideo - ResolveVideoReservedConcurrency());
        var globalSlotsAvailableAfterBorrowedVideo = Math.Max(
            ResolveImageProtectedConcurrency(),
            options.GlobalMaxConcurrentGenerations - (int)borrowedVideo);
        return Math.Max(1, Math.Min(options.ImageMaxConcurrentGenerations, globalSlotsAvailableAfterBorrowedVideo));
    }

    private bool CanEstimateVideoBorrow(QueueCapacityContext? capacityContext)
    {
        if (!options.EnableElasticLaneBorrowing || ResolveVideoBorrowMaxConcurrency() <= 0)
        {
            return false;
        }

        if (capacityContext is null)
        {
            return false;
        }

        var context = capacityContext.Value;
        if (context.ActiveVideo >= options.VideoMaxConcurrentGenerations)
        {
            return false;
        }

        if (Math.Max(0, context.ActiveVideo - ResolveVideoReservedConcurrency()) >= ResolveVideoBorrowMaxConcurrency())
        {
            return false;
        }

        if (context.ActiveImage + ResolveImageProtectedConcurrency() > options.ImageMaxConcurrentGenerations)
        {
            return false;
        }

        if (context.QueuedImage == 0)
        {
            return options.AllowVideoBorrowWhenImageQueueEmpty;
        }

        var protectedSlots = Math.Max(1, ResolveImageProtectedConcurrency());
        var backlogUnits = Math.Max(0, context.ActiveImage + context.QueuedImage - protectedSlots);
        var imageEstimatedWaitSeconds = (int)Math.Ceiling(backlogUnits * Math.Max(1, options.EstimatedImageGenerationSeconds) / (double)protectedSlots);
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
        long ActiveImage,
        long ActiveVideo,
        long QueuedImage);

    private static bool IsClaimableQueuedJob(TemplateGenerationJob job)
    {
        return job.Status == TemplateGenerationStatus.Queued
            && (job.ChargedAtUtc != null || job.UserId == AdminTestUserId);
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
