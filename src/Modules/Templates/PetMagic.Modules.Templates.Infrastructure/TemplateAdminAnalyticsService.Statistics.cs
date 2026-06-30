using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateAdminAnalyticsService
{
    public async Task<Result<AdminTemplateStatisticsResponse>> GetAdminStatisticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<AdminTemplateStatisticsResponse>(TemplatesErrors.NotFound);
        }

        var summary = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalRuns = group.Count(),
                QueuedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Queued),
                ProcessingRuns = group.Count(x => x.Status == TemplateGenerationStatus.Processing),
                CompletedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Completed),
                FailedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Failed),
                TotalTokenCost = group.Sum(x => x.TokenCost),
                ProviderCostSamples = group.Count(x => x.MotionProviderCostUsd.HasValue),
                TotalProviderCostUsd = group.Sum(x => x.MotionProviderCostUsd ?? 0m),
                LastRunAtUtc = group.Max(x => (DateTime?)x.CreatedAtUtc),
                LastCompletedAtUtc = group.Where(x => x.Status == TemplateGenerationStatus.Completed)
                    .Max(x => x.CompletedAtUtc)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var averageGenerationSeconds = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId
                && x.Status == TemplateGenerationStatus.Completed
                && x.StartedAtUtc.HasValue
                && x.CompletedAtUtc.HasValue
                && x.CompletedAtUtc >= x.StartedAtUtc)
            .Select(x => (double?)(x.CompletedAtUtc!.Value - x.StartedAtUtc!.Value).TotalSeconds)
            .AverageAsync(cancellationToken);

        var totalRuns = summary?.TotalRuns ?? 0;
        var completedRuns = summary?.CompletedRuns ?? 0;
        var successRatePercent = totalRuns == 0
            ? 0
            : Math.Round((double)completedRuns * 100 / totalRuns, 1, MidpointRounding.AwayFromZero);
        var averageTokenCost = totalRuns == 0
            ? 0
            : Math.Round((double)(summary?.TotalTokenCost ?? 0) / totalRuns, 1, MidpointRounding.AwayFromZero);
        var averageProviderCostUsd = summary is null || summary.ProviderCostSamples == 0
            ? 0m
            : Math.Round(summary.TotalProviderCostUsd / summary.ProviderCostSamples, 4, MidpointRounding.AwayFromZero);
        averageGenerationSeconds = averageGenerationSeconds is null
            ? null
            : Math.Round(averageGenerationSeconds.Value, 1, MidpointRounding.AwayFromZero);

        return Result.Success(new AdminTemplateStatisticsResponse(
            templateId,
            totalRuns,
            summary?.QueuedRuns ?? 0,
            summary?.ProcessingRuns ?? 0,
            completedRuns,
            summary?.FailedRuns ?? 0,
            successRatePercent,
            summary?.TotalTokenCost ?? 0,
            averageTokenCost,
            Math.Round(summary?.TotalProviderCostUsd ?? 0m, 4, MidpointRounding.AwayFromZero),
            averageProviderCostUsd,
            summary?.LastRunAtUtc,
            summary?.LastCompletedAtUtc,
            averageGenerationSeconds));
    }

    public async Task<Result<IReadOnlyList<AdminTemplateTrendPointResponse>>> GetAdminTrendAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateTrendPointResponse>>(TemplatesErrors.NotFound);
        }

        var trendRows = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .GroupBy(x => x.CreatedAtUtc.Date)
            .Select(group => new
            {
                Day = group.Key,
                TotalRuns = group.Count(),
                QueuedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Queued),
                ProcessingRuns = group.Count(x => x.Status == TemplateGenerationStatus.Processing),
                CompletedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Completed),
                FailedRuns = group.Count(x => x.Status == TemplateGenerationStatus.Failed),
                TotalTokenCost = group.Sum(x => x.TokenCost),
                TotalProviderCostUsd = group.Sum(x => x.MotionProviderCostUsd ?? 0m)
            })
            .ToArrayAsync(cancellationToken);

        var durationSamples = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId
                && x.Status == TemplateGenerationStatus.Completed
                && x.StartedAtUtc.HasValue
                && x.CompletedAtUtc.HasValue)
            .Select(x => new
            {
                Day = x.CreatedAtUtc.Date,
                DurationSeconds = (x.CompletedAtUtc!.Value - x.StartedAtUtc!.Value).TotalSeconds
            })
            .ToArrayAsync(cancellationToken);

        var averageDurationByDay = durationSamples
            .Where(x => x.DurationSeconds >= 0)
            .GroupBy(x => x.Day)
            .ToDictionary(
                group => group.Key,
                group => (double?)Math.Round(group.Average(x => x.DurationSeconds), 1, MidpointRounding.AwayFromZero));

        var trend = trendRows
            .OrderBy(x => x.Day)
            .Select(row => new AdminTemplateTrendPointResponse(
                row.Day,
                row.TotalRuns,
                row.QueuedRuns,
                row.ProcessingRuns,
                row.CompletedRuns,
                row.FailedRuns,
                row.TotalRuns == 0
                    ? 0
                    : Math.Round((double)row.CompletedRuns * 100 / row.TotalRuns, 1, MidpointRounding.AwayFromZero),
                row.TotalTokenCost,
                Math.Round(row.TotalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
                averageDurationByDay.GetValueOrDefault(row.Day)))
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateTrendPointResponse>>(trend);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateRecentGenerationResponse>>> GetAdminRecentGenerationsAsync(Guid templateId, int take, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateRecentGenerationResponse>>(TemplatesErrors.NotFound);
        }

        var recent = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .Select(x => new AdminTemplateRecentGenerationResponse(
                x.Id,
                x.UserId,
                MapRecentGenerationStatus(x.Status),
                x.TokenCost,
                x.AttemptCount,
                x.UsedPreprocessingModel,
                x.UsedKlingModel,
                x.MotionProviderCostUsd,
                x.LastErrorCode,
                x.LastErrorMessage,
                x.ResultUrl,
                x.CreatedAtUtc,
                x.StartedAtUtc,
                x.CompletedAtUtc))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateRecentGenerationResponse>>(recent);
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> GetAdminTestHistoryAsync(Guid templateId, int take, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<TemplateGenerationResponse>>(TemplatesErrors.NotFound);
        }

        var jobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId && x.UserId == TemplateGenerationService.AdminTestUserId)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>([.. jobs.Select(job => TemplateGenerationService.MapResponse(job))]);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>> GetAdminFailureBreakdownAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>(TemplatesErrors.NotFound);
        }

        var failureRows = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId && x.Status == TemplateGenerationStatus.Failed)
            .Select(x => new
            {
                FailureCode = x.LastErrorCode,
                LastOccurredAtUtc = x.CompletedAtUtc ?? x.StartedAtUtc ?? x.CreatedAtUtc
            })
            .ToArrayAsync(cancellationToken);

        var failures = failureRows
            .GroupBy(x => string.IsNullOrWhiteSpace(x.FailureCode) ? "templates.unknown_failure" : x.FailureCode)
            .Select(group => new AdminTemplateFailureBreakdownItemResponse(
                group.Key,
                group.Count(),
                group.Max(x => x.LastOccurredAtUtc)))
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.FailureCode)
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>(failures);
    }

    private static string MapRecentGenerationStatus(TemplateGenerationStatus status)
    {
        return status switch
        {
            TemplateGenerationStatus.Completed => "Completed",
            _ => status.ToString()
        };
    }
}
