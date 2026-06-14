using System.Globalization;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateAdminAnalyticsService(TemplatesDbContext dbContext)
{
    private sealed record GenerationAnalyticsProjection(
        Guid GenerationId,
        Guid TemplateId,
        Guid UserId,
        TemplateGenerationStatus Status,
        int TokenCost,
        int AttemptCount,
        string? UsedPreprocessingModel,
        string? UsedKlingModel,
        decimal? MotionProviderCostUsd,
        string? FailureCode,
        string? FailureMessage,
        string? OutputUrl,
        DateTime CreatedAtUtc,
        DateTime? StartedAtUtc,
        DateTime? CompletedAtUtc);

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

    private static string MapRecentGenerationStatus(TemplateGenerationStatus status)
    {
        return status switch
        {
            TemplateGenerationStatus.Completed => "Completed",
            _ => status.ToString()
        };
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

    public async Task<Result<AdminTemplateEventAnalyticsResponse>> GetAdminEventAnalyticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<AdminTemplateEventAnalyticsResponse>(TemplatesErrors.NotFound);
        }

        var eventsQuery = dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId);

        var totals = await eventsQuery
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalViews = group.Count(x => x.EventType == TemplateAnalyticsEventTypes.View),
                TotalVideoViews = group.Count(x => x.EventType == TemplateAnalyticsEventTypes.VideoView),
                TotalComplaints = group.Count(x => x.EventType == TemplateAnalyticsEventTypes.Complaint)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var totalViews = totals?.TotalViews ?? 0;
        var viewEventsQuery = eventsQuery.Where(x => x.EventType == TemplateAnalyticsEventTypes.View);

        var sourceCounts = totalViews == 0
            ? []
            : await viewEventsQuery
                .GroupBy(x => x.Source == null || x.Source == string.Empty ? "direct" : x.Source.Trim().ToLower())
                .Select(group => new { group.Key, Count = group.Count() })
                .ToArrayAsync(cancellationToken);

        var deviceCounts = totalViews == 0
            ? []
            : await viewEventsQuery
                .GroupBy(x => x.DeviceClass == null || x.DeviceClass == string.Empty ? "unknown" : x.DeviceClass.Trim().ToLower())
                .Select(group => new { group.Key, Count = group.Count() })
                .ToArrayAsync(cancellationToken);

        var geographyCounts = totalViews == 0
            ? []
            : await viewEventsQuery
                .GroupBy(x => x.CountryCode == null || x.CountryCode == string.Empty ? "unknown" : x.CountryCode.Trim().ToLower())
                .Select(group => new { group.Key, Count = group.Count() })
                .ToArrayAsync(cancellationToken);

        var response = new AdminTemplateEventAnalyticsResponse(
            totalViews,
            totals?.TotalVideoViews ?? 0,
            totals?.TotalComplaints ?? 0,
            [.. sourceCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))],
            [.. deviceCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))],
            [.. geographyCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))]);

        return Result.Success(response);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFeedbackItemResponse>>> GetAdminFeedbackAsync(Guid templateId, AdminTemplateFeedbackQuery query, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateFeedbackItemResponse>>(TemplatesErrors.NotFound);
        }

        var take = Math.Clamp(query.Take ?? 50, 1, 200);
        var eventType = NormalizeAnalyticsFilter(query.Type);
        var search = NormalizeOptionalText(query.Search, 200)?.ToLowerInvariant();

        var feedbackQuery = dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .Where(x => x.EventType == TemplateAnalyticsEventTypes.Complaint || x.EventType == TemplateAnalyticsEventTypes.Feedback);

        if (eventType is TemplateAnalyticsEventTypes.Complaint or TemplateAnalyticsEventTypes.Feedback)
        {
            feedbackQuery = feedbackQuery.Where(x => x.EventType == eventType);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            feedbackQuery = feedbackQuery.Where(x => x.FeedbackMessage != null && x.FeedbackMessage.ToLower().Contains(search));
        }

        var items = await feedbackQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .Select(x => new AdminTemplateFeedbackItemResponse(
                x.Id,
                x.EventType,
                x.FeedbackMessage,
                x.Source,
                x.DeviceClass,
                x.CountryCode,
                x.UserId,
                x.GenerationId,
                x.CreatedAtUtc))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateFeedbackItemResponse>>(items);
    }

    public async Task<Result<AdminTemplatesAnalyticsOverviewResponse>> GetAdminTemplatesAnalyticsAsync(AdminTemplatesAnalyticsQuery query, CancellationToken cancellationToken)
    {
        var generatedAtUtc = DateTime.UtcNow;
        var periodDays = query.PeriodDays.HasValue ? Math.Clamp(query.PeriodDays.Value, 1, 3650) : (int?)null;
        var periodStartUtc = periodDays.HasValue ? generatedAtUtc.Date.AddDays(-(periodDays.Value - 1)) : (DateTime?)null;
        var templateType = ParseTemplateTypeFilter(query.TemplateType);
        var templateStatus = ParseTemplateStatusFilter(query.Status);
        var access = NormalizeAnalyticsFilter(query.Access);
        var category = string.IsNullOrWhiteSpace(query.Category) ? null : query.Category.Trim();
        var take = Math.Clamp(query.Take ?? 50, 1, 200);

        var allTemplates = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .ToArrayAsync(cancellationToken);

        var templates = allTemplates
            .Where(x => !templateType.HasValue || x.TemplateType == templateType.Value)
            .Where(x => !templateStatus.HasValue || x.Status == templateStatus.Value)
            .Where(x => category is null || string.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase))
            .Where(x => access is null || access == "all" || (access == "premium" ? x.IsPremium : !x.IsPremium))
            .ToArray();
        var templateIds = templates.Select(x => x.Id).ToHashSet();

        var jobs = templateIds.Count == 0
            ? []
            : await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Where(x => templateIds.Contains(x.TemplateId))
                .Where(x => !periodStartUtc.HasValue || x.CreatedAtUtc >= periodStartUtc.Value)
                .Select(x => new GenerationAnalyticsProjection(
                    x.Id,
                    x.TemplateId,
                    x.UserId,
                    x.Status,
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

        var events = templateIds.Count == 0
            ? []
            : await dbContext.TemplateAnalyticsEvents
                .AsNoTracking()
                .Where(x => templateIds.Contains(x.TemplateId))
                .Where(x => !periodStartUtc.HasValue || x.CreatedAtUtc >= periodStartUtc.Value)
                .ToArrayAsync(cancellationToken);

        var jobsByTemplate = jobs.GroupBy(x => x.TemplateId).ToDictionary(x => x.Key, x => x.ToArray());
        var eventsByTemplate = events.GroupBy(x => x.TemplateId).ToDictionary(x => x.Key, x => x.ToArray());
        var templatesById = templates.ToDictionary(x => x.Id);
        var rows = templates
            .Select(template => BuildTemplatesAnalyticsRow(
                template,
                jobsByTemplate.GetValueOrDefault(template.Id) ?? [],
                eventsByTemplate.GetValueOrDefault(template.Id) ?? []))
            .ToArray();
        var sortedRows = SortTemplatesAnalyticsRows(rows, query.Sort).ToArray();

        var totalStarts = rows.Sum(x => x.GenerationStarts);
        var completed = rows.Sum(x => x.CompletedGenerations);
        var totalTokenCost = rows.Sum(x => x.TotalTokenCost);
        var totalProviderCostUsd = rows.Sum(x => x.TotalProviderCostUsd);
        var totalViews = rows.Sum(x => x.Views);
        var totalComplaints = events.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.Complaint));
        var viewEvents = events
            .Where(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View))
            .ToArray();
        var feedbackItems = events
            .Where(IsFeedbackEvent)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(20)
            .Select(x =>
            {
                var template = templatesById[x.TemplateId];

                return new AdminTemplatesAnalyticsFeedbackItemResponse(
                    x.Id,
                    x.TemplateId,
                    template.Title,
                    template.TemplateType.ToString(),
                    x.EventType,
                    x.FeedbackMessage,
                    x.Source,
                    x.DeviceClass,
                    x.CountryCode,
                    x.UserId,
                    x.GenerationId,
                    x.CreatedAtUtc);
            })
            .ToArray();

        var response = new AdminTemplatesAnalyticsOverviewResponse(
            new AdminTemplatesAnalyticsSummaryResponse(
                rows.Length,
                templates.Count(x => x.TemplateType == TemplateType.Video),
                templates.Count(x => x.TemplateType == TemplateType.Image),
                templates.Count(x => x.Status == TemplateStatus.Active),
                templates.Count(x => x.IsPremium),
                totalViews,
                totalStarts,
                completed,
                rows.Sum(x => x.FailedGenerations),
                CalculatePercent(completed, totalStarts),
                totalTokenCost,
                totalStarts == 0 ? 0 : Math.Round((double)totalTokenCost / totalStarts, 1, MidpointRounding.AwayFromZero),
                Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
                totalComplaints),
            BuildTemplatesAnalyticsTrend(jobs, events),
            [.. sortedRows.Take(5)],
            BuildTemplatesAnalyticsBreakdown(rows, row => row.Category),
            BuildTemplatesAnalyticsBreakdown(rows, row => row.TemplateType),
            BuildDimension(viewEvents, x => x.Source, "direct"),
            BuildDimension(viewEvents, x => x.DeviceClass, "unknown"),
            BuildDimension(viewEvents, x => x.CountryCode, "unknown"),
            feedbackItems,
            new AdminTemplatesAnalyticsFunnelResponse(
                totalViews,
                totalStarts,
                completed,
                rows.Sum(x => x.FailedGenerations),
                totalComplaints),
            [.. sortedRows.Take(take)],
            [.. allTemplates
                .Select(x => x.Category)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x)],
            generatedAtUtc);

        return Result.Success(response);
    }

    public async Task<Result> RecordAnalyticsEventAsync(RecordTemplateAnalyticsEventCommand command, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == command.TemplateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = command.TemplateId,
            UserId = command.UserId,
            GenerationId = command.GenerationId,
            EventType = NormalizeAnalyticsValue(command.EventType, TemplateAnalyticsEventTypes.View, 64),
            Source = NormalizeAnalyticsValue(command.Source, "direct", 64),
            DeviceClass = NormalizeAnalyticsValue(command.DeviceClass, "unknown", 32),
            CountryCode = NormalizeAnalyticsValue(command.CountryCode, "unknown", 8).ToUpperInvariant(),
            FeedbackMessage = NormalizeOptionalText(command.FeedbackMessage, 2000),
            MetadataJson = NormalizeOptionalText(command.MetadataJson, 2000),
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    private static AdminTemplatesAnalyticsTemplateRowResponse BuildTemplatesAnalyticsRow(
        TemplateItem template,
        IReadOnlyCollection<GenerationAnalyticsProjection> jobs,
        IReadOnlyCollection<TemplateAnalyticsEvent> events)
    {
        var starts = jobs.Count;
        var completed = jobs.Count(x => x.Status == TemplateGenerationStatus.Completed);
        var failed = jobs.Count(x => x.Status == TemplateGenerationStatus.Failed);
        var totalTokenCost = jobs.Sum(x => x.TokenCost);
        var totalProviderCostUsd = jobs.Sum(x => x.MotionProviderCostUsd ?? 0m);

        return new AdminTemplatesAnalyticsTemplateRowResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.Category,
            template.Status.ToString(),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            events.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View)),
            starts,
            completed,
            failed,
            CalculatePercent(completed, starts),
            totalTokenCost,
            Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
            template.UpdatedAtUtc);
    }

    private static IReadOnlyList<AdminTemplatesAnalyticsTrendPointResponse> BuildTemplatesAnalyticsTrend(
        IReadOnlyCollection<GenerationAnalyticsProjection> jobs,
        IReadOnlyCollection<TemplateAnalyticsEvent> events)
    {
        var jobsByDay = jobs
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());
        var eventsByDay = events
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());

        return [.. jobsByDay.Keys
            .Concat(eventsByDay.Keys)
            .Distinct()
            .OrderBy(x => x)
            .Select(day =>
            {
                var dayJobs = jobsByDay.GetValueOrDefault(day) ?? [];
                var dayEvents = eventsByDay.GetValueOrDefault(day) ?? [];
                var totalTokenCost = dayJobs.Sum(x => x.TokenCost);
                var totalProviderCostUsd = dayJobs.Sum(x => x.MotionProviderCostUsd ?? 0m);

                return new AdminTemplatesAnalyticsTrendPointResponse(
                    DateTime.SpecifyKind(day, DateTimeKind.Utc),
                    dayEvents.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View)),
                    dayJobs.Length,
                    dayJobs.Count(x => x.Status == TemplateGenerationStatus.Completed),
                    dayJobs.Count(x => x.Status == TemplateGenerationStatus.Failed),
                    totalTokenCost,
                    Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero));
            })];
    }

    private static IReadOnlyList<AdminTemplatesAnalyticsBreakdownResponse> BuildTemplatesAnalyticsBreakdown(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        Func<AdminTemplatesAnalyticsTemplateRowResponse, string> selector)
    {
        return [.. rows
            .GroupBy(row => NormalizeAnalyticsValue(selector(row), "unknown", 128))
            .OrderByDescending(group => group.Sum(x => x.Views))
            .ThenByDescending(group => group.Sum(x => x.GenerationStarts))
            .ThenBy(group => group.Key)
            .Select(group =>
            {
                var starts = group.Sum(x => x.GenerationStarts);
                var completed = group.Sum(x => x.CompletedGenerations);
                var totalTokenCost = group.Sum(x => x.TotalTokenCost);
                var totalProviderCostUsd = group.Sum(x => x.TotalProviderCostUsd);

                return new AdminTemplatesAnalyticsBreakdownResponse(
                    group.Key,
                    FormatDimensionLabel(group.Key),
                    group.Count(),
                    group.Sum(x => x.Views),
                    starts,
                    completed,
                    CalculatePercent(completed, starts),
                    totalTokenCost,
                    Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero));
            })];
    }

    private static IEnumerable<AdminTemplatesAnalyticsTemplateRowResponse> SortTemplatesAnalyticsRows(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        string? sort)
    {
        var normalizedSort = NormalizeAnalyticsFilter(sort) ?? "views";
        var ordered = normalizedSort switch
        {
            "starts" => rows.OrderByDescending(x => x.GenerationStarts),
            "conversion" => rows.OrderByDescending(x => x.ConversionPercent),
            "cost" => rows.OrderByDescending(x => x.TotalProviderCostUsd),
            "tokens" => rows.OrderByDescending(x => x.TotalTokenCost),
            "updated" => rows.OrderByDescending(x => x.UpdatedAtUtc),
            _ => rows.OrderByDescending(x => x.Views),
        };

        return ordered.ThenBy(x => x.Title);
    }

    private static TemplateType? ParseTemplateTypeFilter(string? raw)
    {
        return Enum.TryParse<TemplateType>(raw, true, out var templateType) ? templateType : null;
    }

    private static TemplateStatus? ParseTemplateStatusFilter(string? raw)
    {
        return Enum.TryParse<TemplateStatus>(raw, true, out var templateStatus) ? templateStatus : null;
    }

    private static string? NormalizeAnalyticsFilter(string? raw)
    {
        return string.IsNullOrWhiteSpace(raw) ? null : raw.Trim().ToLowerInvariant();
    }

    private static double CalculatePercent(int numerator, int denominator)
    {
        return denominator == 0
            ? 0
            : Math.Round((double)numerator * 100 / denominator, 1, MidpointRounding.AwayFromZero);
    }

    private static bool IsAnalyticsEventType(TemplateAnalyticsEvent analyticsEvent, string eventType)
    {
        return string.Equals(analyticsEvent.EventType, eventType, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsFeedbackEvent(TemplateAnalyticsEvent analyticsEvent)
    {
        return IsAnalyticsEventType(analyticsEvent, TemplateAnalyticsEventTypes.Complaint)
            || IsAnalyticsEventType(analyticsEvent, TemplateAnalyticsEventTypes.Feedback);
    }

    private static IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> BuildDimension(
        IReadOnlyCollection<TemplateAnalyticsEvent> events,
        Func<TemplateAnalyticsEvent, string> selector,
        string fallback)
    {
        if (events.Count == 0)
        {
            return [];
        }

        return [.. events
            .Select(selector)
            .Select(value => NormalizeAnalyticsValue(value, fallback, 64))
            .GroupBy(value => value)
            .OrderByDescending(group => group.Count())
            .ThenBy(group => group.Key)
            .Select(group => new AdminTemplateAnalyticsDimensionResponse(
                group.Key,
                FormatDimensionLabel(group.Key),
                group.Count(),
                Math.Round((double)group.Count() * 100 / events.Count, 1, MidpointRounding.AwayFromZero)))];
    }

    private static string NormalizeAnalyticsValue(string? value, string fallback, int maxLength)
    {
        var normalized = string.IsNullOrWhiteSpace(value)
            ? fallback
            : value.Trim().ToLowerInvariant();

        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string FormatDimensionLabel(string key) => key switch
    {
        "home" => "Home",
        "categories" => "Categories",
        "search" => "Search",
        "profile" => "Profile",
        "direct" => "Direct",
        "ios" => "iOS",
        "android" => "Android",
        "web" => "Web",
        "bot" => "Bot",
        "unknown" => "Unknown",
        _ when key.Length <= 3 => key.ToUpperInvariant(),
        _ => CultureInfo.InvariantCulture.TextInfo.ToTitleCase(key.Replace('-', ' ').Replace('_', ' '))
    };

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(asset.Url, asset.FileName, asset.ContentType, asset.FileSizeBytes, asset.DurationSeconds);
    }
}
