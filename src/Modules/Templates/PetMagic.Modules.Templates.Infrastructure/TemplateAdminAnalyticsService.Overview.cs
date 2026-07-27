using System.Globalization;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateAdminAnalyticsService
{
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
        var skip = Math.Max(0, query.Skip ?? 0);
        var requestedTemplateIds = query.TemplateIds?
            .Distinct()
            .ToArray();

        var templatesQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.DeletedAtUtc == null);

        if (requestedTemplateIds is { Length: > 0 })
        {
            templatesQuery = templatesQuery.Where(x => requestedTemplateIds.Contains(x.Id));
        }

        var allTemplates = await templatesQuery
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
        var totalCount = sortedRows.Length;
        var templatesPage = sortedRows
            .Skip(skip)
            .Take(take)
            .ToArray();
        var hasMore = (long)skip + take < totalCount;

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
            BuildTemplatesAnalyticsTrend(jobs, events, periodStartUtc, periodDays.HasValue ? generatedAtUtc.Date : null),
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
            templatesPage,
            [.. allTemplates
                .Select(x => x.Category)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x)],
            generatedAtUtc,
            skip,
            take,
            totalCount,
            hasMore);

        return Result.Success(response);
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
        IReadOnlyCollection<TemplateAnalyticsEvent> events,
        DateTime? periodStartUtc,
        DateTime? periodEndUtc)
    {
        var jobsByDay = jobs
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());
        var eventsByDay = events
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());

        var days = periodStartUtc.HasValue && periodEndUtc.HasValue
            ? Enumerable.Range(0, (periodEndUtc.Value.Date - periodStartUtc.Value.Date).Days + 1)
                .Select(offset => periodStartUtc.Value.Date.AddDays(offset))
            : jobsByDay.Keys
                .Concat(eventsByDay.Keys)
                .Distinct()
                .OrderBy(x => x);

        return [.. days
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
            : new TemplateAssetResponse(
                asset.Url,
                asset.FileName ?? string.Empty,
                asset.ContentType ?? string.Empty,
                asset.FileSizeBytes,
                asset.DurationSeconds);
    }
}
