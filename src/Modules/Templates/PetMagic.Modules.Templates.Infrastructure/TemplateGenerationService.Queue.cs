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
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return await SignUserMediaUrlsAsync(
                await ApplyCompareAccessAsync(
                    ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                    job,
                    hasCleanAccess,
                    cancellationToken),
                cancellationToken);
        }

        var queuePosition = await CalculateQueuePositionAsync(job, cancellationToken);

        return await SignUserMediaUrlsAsync(
            await ApplyCompareAccessAsync(
                ApplyWatermarkAccess(MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)), job, isPremium, hasUnlock),
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
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
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

        var latestQueuedAtUtc = queuedJobs.Max(x => x.QueuedAtUtc);
        var queuedOrderKeys = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc <= latestQueuedAtUtc)
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc
            })
            .ToArrayAsync(cancellationToken);

        var positionByQueuedJobId = queuedOrderKeys
            .OrderBy(x => x.QueuedAtUtc)
            .ThenBy(x => x.Id)
            .Select((job, index) => new
            {
                job.Id,
                Position = index + 1
            })
            .ToDictionary(x => x.Id, x => x.Position);

        var fallbackPositionByQueuedAtUtc = new Dictionary<DateTime, int>();
        foreach (var group in queuedOrderKeys.GroupBy(x => x.QueuedAtUtc).OrderBy(x => x.Key))
        {
            fallbackPositionByQueuedAtUtc[group.Key] = group
                .Select(x => positionByQueuedJobId.GetValueOrDefault(x.Id, 1))
                .Min();
        }

        var items = new List<TemplateGenerationResponse>(jobs.Count);
        foreach (var job in jobs)
        {
            var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
            var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
            if (job.Status != TemplateGenerationStatus.Queued)
            {
                items.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
                continue;
            }

            var queuePosition = positionByQueuedJobId.GetValueOrDefault(
                job.Id,
                fallbackPositionByQueuedAtUtc.GetValueOrDefault(job.QueuedAtUtc, 1));
            items.Add(await SignUserMediaUrlsAsync(
                ApplyCompareAccess(
                    ApplyWatermarkAccess(
                        MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)),
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

    private async Task<int> CalculateQueuePositionAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var olderQueuedCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc < job.QueuedAtUtc,
                cancellationToken);

        var tiedQueuedIds = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc == job.QueuedAtUtc)
            .Select(x => x.Id)
            .ToArrayAsync(cancellationToken);

        Array.Sort(tiedQueuedIds);
        var tiedIndex = Array.IndexOf(tiedQueuedIds, job.Id);
        return olderQueuedCount + Math.Max(0, tiedIndex) + 1;
    }

    private int EstimateWaitSeconds(TemplateGenerationJob job, int queuePosition)
    {
        var averageGenerationSeconds = job.Template?.TemplateType == TemplateType.Video
            ? options.EstimatedVideoGenerationSeconds
            : options.EstimatedImageGenerationSeconds;
        var globalConcurrency = Math.Max(1, options.GlobalMaxConcurrentGenerations);
        return (int)Math.Ceiling(queuePosition * averageGenerationSeconds / (double)globalConcurrency);
    }

}
