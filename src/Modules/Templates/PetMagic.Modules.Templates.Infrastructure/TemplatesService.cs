using System.Globalization;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatesService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IMediaMetadataReader metadataReader,
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService,
    ITemplateFeedRealtimeService templateFeedRealtimeService) : ITemplatesService
{
    private const int PublicFeedDefaultTake = 20;
    private const int PublicFeedMaxTake = 50;

    private sealed record PublicFeedCursor(DateTime UpdatedAtUtc, Guid TemplateId);

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

    public async Task<Result<IReadOnlyList<AdminTemplateCategoryListItemResponse>>> ListAdminCategoriesAsync(bool includeArchived, CancellationToken cancellationToken)
    {
        var categories = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(x => includeArchived || !x.IsArchived)
            .OrderBy(x => x.IsArchived)
            .ThenBy(x => x.Name)
            .ToArrayAsync(cancellationToken);

        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .ToArrayAsync(cancellationToken);

        var response = categories
            .Select(category => MapAdminCategory(category, templates.Where(template => string.Equals(template.Category, category.Name, StringComparison.Ordinal)).ToArray()))
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateCategoryListItemResponse>>(response);
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> CreateCategoryAsync(CreateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        var categoryName = NormalizeCategoryName(command.Name);
        var normalizedName = NormalizeCategoryKey(categoryName);

        var exists = await dbContext.TemplateCategories
            .AsNoTracking()
            .AnyAsync(x => x.NormalizedName == normalizedName, cancellationToken);

        if (exists)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var category = new TemplateCategory
        {
            Id = Guid.NewGuid(),
            Name = categoryName,
            NormalizedName = normalizedName,
            IsArchived = false,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateCategories.Add(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminCategory(category, []));
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> UpdateCategoryAsync(UpdateTemplateCategoryCommand command, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(command.CategoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryNotFound);
        }

        var categoryName = NormalizeCategoryName(command.Name);
        var normalizedName = NormalizeCategoryKey(categoryName);
        var duplicateExists = await dbContext.TemplateCategories
            .AsNoTracking()
            .AnyAsync(x => x.Id != category.Id && x.NormalizedName == normalizedName, cancellationToken);

        if (duplicateExists)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryAlreadyExists);
        }

        var previousName = category.Name;
        var updatedAtUtc = DateTime.UtcNow;

        category.Name = categoryName;
        category.NormalizedName = normalizedName;
        category.UpdatedAtUtc = updatedAtUtc;

        if (!string.Equals(previousName, categoryName, StringComparison.Ordinal))
        {
            var templates = await dbContext.TemplateItems
                .Where(x => x.Category == previousName)
                .ToArrayAsync(cancellationToken);

            foreach (var template in templates)
            {
                template.Category = categoryName;
                template.UpdatedAtUtc = updatedAtUtc;
            }
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);
        return Result.Success(await BuildAdminCategoryResponseAsync(category, cancellationToken));
    }

    public async Task<Result<AdminTemplateCategoryListItemResponse>> ChangeCategoryArchiveStateAsync(ChangeTemplateCategoryArchiveStateCommand command, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(command.CategoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure<AdminTemplateCategoryListItemResponse>(TemplatesErrors.CategoryNotFound);
        }

        if (category.IsArchived != command.IsArchived)
        {
            category.IsArchived = command.IsArchived;
            category.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);
            await PublishFeedInvalidatedAsync(cancellationToken);
        }

        return Result.Success(await BuildAdminCategoryResponseAsync(category, cancellationToken));
    }

    public async Task<Result> DeleteCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        var category = await FindCategoryAsync(categoryId, cancellationToken);
        if (category is null)
        {
            return Result.Failure(TemplatesErrors.CategoryNotFound);
        }

        var hasTemplates = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Category == category.Name, cancellationToken);

        if (hasTemplates)
        {
            return Result.Failure(TemplatesErrors.CategoryHasTemplates);
        }

        dbContext.TemplateCategories.Remove(category);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<AdminTemplateListItemResponse>>> ListAdminAsync(TemplateType? type, TemplateStatus? status, CancellationToken cancellationToken)
    {
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => !status.HasValue || x.Status == status.Value)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateListItemResponse>>(items.Select(MapAdminListItem).ToArray());
    }

    public async Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        return template is null
            ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapAdminResponse(template));
    }

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

        var durationSamples = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId
                && x.Status == TemplateGenerationStatus.Completed
                && x.StartedAtUtc.HasValue
                && x.CompletedAtUtc.HasValue)
            .Select(x => (x.CompletedAtUtc!.Value - x.StartedAtUtc!.Value).TotalSeconds)
            .ToArrayAsync(cancellationToken);

        var validDurationSamples = durationSamples.Where(x => x >= 0).ToArray();
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
        double? averageGenerationSeconds = validDurationSamples.Length == 0
            ? null
            : Math.Round(validDurationSamples.Average(), 1, MidpointRounding.AwayFromZero);

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
                x.Status.ToString(),
                x.TokenCost,
                x.AttemptCount,
                x.UsedPreprocessingModel,
                x.UsedKlingModel,
                x.MotionProviderCostUsd,
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
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

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(jobs.Select(TemplateGenerationService.MapResponse).ToArray());
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
                x.FailureCode,
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
            sourceCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))
                .ToArray(),
            deviceCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))
                .ToArray(),
            geographyCounts
                .OrderByDescending(x => x.Count)
                .ThenBy(x => x.Key)
                .Select(x => new AdminTemplateAnalyticsDimensionResponse(
                    x.Key,
                    FormatDimensionLabel(x.Key),
                    x.Count,
                    Math.Round((double)x.Count * 100 / totalViews, 1, MidpointRounding.AwayFromZero)))
                .ToArray());

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
            ? Array.Empty<GenerationAnalyticsProjection>()
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
                    x.FailureCode,
                    x.FailureMessage,
                    x.OutputUrl,
                    x.CreatedAtUtc,
                    x.StartedAtUtc,
                    x.CompletedAtUtc))
                .ToArrayAsync(cancellationToken);

        var events = templateIds.Count == 0
            ? Array.Empty<TemplateAnalyticsEvent>()
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
            sortedRows.Take(5).ToArray(),
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
            sortedRows.Take(take).ToArray(),
            allTemplates
                .Select(x => x.Category)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x)
                .ToArray(),
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
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    public async Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, null, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateImageModel(command.ImageModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements),
            Category = categoryResult.Value.Name,
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            ImageModel = command.ImageModel.Trim(),
            ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Image)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, template.Category, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateImageModel(command.ImageModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
        template.Category = categoryResult.Value.Name;
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
        template.Status = statusResult.Value;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.ImageModel = command.ImageModel.Trim();
        template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Reload the entity from the database and reapply changes
            await dbContext.Entry(template).ReloadAsync(cancellationToken);
            template.Title = command.Title.Trim();
            template.ShortDescription = command.ShortDescription.Trim();
            template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
            template.Category = categoryResult.Value.Name;
            template.Tags = SerializeTags(command.Tags);
            template.IsPremium = command.IsPremium;
            template.TokenCost = command.TokenCost;
            template.Status = statusResult.Value;
            template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
            template.ImageModel = command.ImageModel.Trim();
            template.ImagePrompt = ResolvePrompt(command.ImagePrompt, options.DefaultImagePrompt);
            template.UpdatedAtUtc = DateTime.UtcNow;

            // Try to save again
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await PublishFeedInvalidatedAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, null, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);
        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Video,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements),
            Category = categoryResult.Value.Name,
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim(),
            ReferenceVideoDurationSeconds = duration,
            CharacterOrientation = orientation,
            PreprocessingModel = command.PreprocessingModel.Trim(),
            PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt),
            KlingModel = command.KlingModel.Trim(),
            KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt),
            KeepOriginalSound = command.KeepOriginalSound,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);
        SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var categoryResult = await EnsureTemplateCategoryAsync(command.Category, template.Category, cancellationToken);
        if (categoryResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(categoryResult.Error);
        }

        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
        template.Category = categoryResult.Value.Name;
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim();
        template.ReferenceVideoDurationSeconds = duration;
        template.CharacterOrientation = orientation;
        template.PreprocessingModel = command.PreprocessingModel.Trim();
        template.PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
        template.KlingModel = command.KlingModel.Trim();
        template.KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt);
        template.KeepOriginalSound = command.KeepOriginalSound;
        template.Status = statusResult.Value;
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset),
            SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            // Reload the entity from the database and reapply changes
            await dbContext.Entry(template).ReloadAsync(cancellationToken);
            template.Title = command.Title.Trim();
            template.ShortDescription = command.ShortDescription.Trim();
            template.PetPhotoRequirements = SerializeRequirements(command.PetPhotoRequirements);
            template.Category = categoryResult.Value.Name;
            template.Tags = SerializeTags(command.Tags);
            template.IsPremium = command.IsPremium;
            template.TokenCost = command.TokenCost;
            template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
            template.MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim();
            template.ReferenceVideoDurationSeconds = duration;
            template.CharacterOrientation = orientation;
            template.PreprocessingModel = command.PreprocessingModel.Trim();
            template.PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
            template.KlingModel = command.KlingModel.Trim();
            template.KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt);
            template.KeepOriginalSound = command.KeepOriginalSound;
            template.Status = statusResult.Value;
            template.UpdatedAtUtc = DateTime.UtcNow;

            // Try to save again
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        await PublishFeedInvalidatedAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> ChangeStatusAsync(ChangeTemplateStatusCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (!Enum.TryParse<TemplateStatus>(command.Status, true, out var status))
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.InvalidStatus);
        }

        if (status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        template.Status = status;
        template.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        var assetUrls = CollectObsoleteAssetUrls(template.Assets.Select(asset => asset.Url));
        var cleanupResult = await DeleteTemplateAssetsAsync(assetUrls, cancellationToken);
        if (cleanupResult.IsFailure)
        {
            return cleanupResult;
        }

        dbContext.TemplateItems.Remove(template);
        await dbContext.SaveChangesAsync(cancellationToken);
        await PublishFeedInvalidatedAsync(cancellationToken);

        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => string.IsNullOrWhiteSpace(category) || string.Equals(x.Category, category.Trim(), StringComparison.OrdinalIgnoreCase))
            .Where(x => !premiumOnly.HasValue || !premiumOnly.Value || x.IsPremium)
            .OrderBy(x => x.IsPremium)
            .ThenBy(x => x.Title)
            .ToArrayAsync(cancellationToken);

        var filtered = items
            .Where(x => normalizedTags.Length == 0 || normalizedTags.All(tag => DeserializeTags(x.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
            .Select(MapPublicListItem)
            .ToArray();

        return Result.Success<IReadOnlyList<PublicTemplateListItemResponse>>(filtered);
    }

    public async Task<Result<IReadOnlyList<PublicTemplateCategoryResponse>>> ListPublicCategoriesAsync(CancellationToken cancellationToken)
    {
        var categories = await dbContext.TemplateCategories
            .AsNoTracking()
            .Where(x => !x.IsArchived)
            .OrderBy(x => x.Name)
            .Select(x => new PublicTemplateCategoryResponse(x.Name))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<PublicTemplateCategoryResponse>>(categories);
    }

    public async Task<Result<PublicTemplatesFeedResponse>> ListPublicFeedAsync(PublicTemplatesFeedQuery query, CancellationToken cancellationToken)
    {
        var take = NormalizePublicFeedTake(query.Take);
        var cursor = TryParsePublicFeedCursor(query.Cursor);
        var normalizedCategory = query.Category?.Trim();
        var normalizedSearch = query.Search?.Trim();
        var normalizedTags = NormalizeTags(query.Tags);

        var filteredQuery = dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !query.Type.HasValue || x.TemplateType == query.Type.Value)
            .Where(x => !query.PremiumOnly.HasValue || !query.PremiumOnly.Value || x.IsPremium);

        if (!string.IsNullOrWhiteSpace(normalizedCategory))
        {
            var normalizedCategoryUpper = normalizedCategory.ToUpperInvariant();
            filteredQuery = filteredQuery.Where(template => (template.Category ?? string.Empty).ToUpper() == normalizedCategoryUpper);
        }

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            var normalizedSearchLower = normalizedSearch.ToLowerInvariant();
            filteredQuery = filteredQuery.Where(template =>
                (template.Title ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.ShortDescription ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.Category ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (template.Tags ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || ((template.PetPhotoRequirements ?? string.Empty).ToLower().Contains(normalizedSearchLower)));
        }

        if (cursor is not null)
        {
            filteredQuery = filteredQuery.Where(template =>
                template.UpdatedAtUtc < cursor.UpdatedAtUtc
                || (template.UpdatedAtUtc == cursor.UpdatedAtUtc && template.Id.CompareTo(cursor.TemplateId) < 0));
        }

        var orderedQuery = filteredQuery
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Id);

        TemplateItem[] filtered;

        if (normalizedTags.Length == 0)
        {
            filtered = await orderedQuery
                .Take(take + 1)
                .ToArrayAsync(cancellationToken);
        }
        else
        {
            filtered = (await orderedQuery.ToArrayAsync(cancellationToken))
                .Where(template => normalizedTags.All(tag => DeserializeTags(template.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
                .Take(take + 1)
                .ToArray();
        }

        var pageItems = filtered.Take(take).ToArray();
        var hasMore = filtered.Length > take;
        var nextCursor = hasMore && pageItems.Length > 0
            ? FormatPublicFeedCursor(pageItems[^1])
            : null;

        return Result.Success(new PublicTemplatesFeedResponse(
            pageItems.Select(MapPublicListItem).ToArray(),
            nextCursor,
            hasMore,
            DateTime.UtcNow));
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.Status != TemplateStatus.Active)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(template));
    }

    private Result ValidateVideoModels(string preprocessingModel, string klingModel)
    {
        if (!options.AllowedPreprocessingModels.Contains(preprocessingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidPreprocessingModel);
        }

        if (!options.AllowedKlingModels.Contains(klingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidKlingModel);
        }

        return Result.Success();
    }

    private Result ValidateImageModel(string imageModel)
    {
        if (!options.AllowedImageModels.Contains(imageModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidImageModel);
        }

        return Result.Success();
    }

    private Result ValidateActivation(TemplateItem template)
    {
        if (GetAsset(template, TemplateAssetKind.Preview) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (template.TemplateType == TemplateType.Video)
        {
            if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceMotion);
            }

            if (!template.ReferenceVideoDurationSeconds.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceDuration);
            }

            if (!template.CharacterOrientation.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingCharacterOrientation);
            }

            return Result.Success();
        }

        if (string.IsNullOrWhiteSpace(template.ImageModel))
        {
            return Result.Failure(TemplatesErrors.MissingImageModel);
        }

        if (!options.AllowedImageModels.Contains(template.ImageModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidImageModel);
        }

        return Result.Success();
    }

    private static Result<TemplateStatus> ResolveRequestedStatus(string? rawStatus, TemplateStatus fallback)
    {
        if (string.IsNullOrWhiteSpace(rawStatus))
        {
            return Result.Success(fallback);
        }

        return Enum.TryParse<TemplateStatus>(rawStatus, true, out var status)
            ? Result.Success(status)
            : Result.Failure<TemplateStatus>(TemplatesErrors.InvalidStatus);
    }

    private async Task<(double? duration, CharacterOrientation? orientation)> ResolveReferenceMetadataAsync(TemplateAssetCommand? asset, CancellationToken cancellationToken)
    {
        if (asset is null)
        {
            return (null, null);
        }

        var durationResult = await metadataReader.GetVideoDurationSecondsAsync(asset, cancellationToken);
        if (durationResult.IsFailure || !durationResult.Value.HasValue)
        {
            return (null, null);
        }

        var duration = Math.Round(durationResult.Value.Value, 2, MidpointRounding.AwayFromZero);
        var orientation = duration <= 10 ? CharacterOrientation.Image : CharacterOrientation.Video;
        return (duration, orientation);
    }

    private Task<TemplateCategory?> FindCategoryAsync(Guid categoryId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateCategories
            .FirstOrDefaultAsync(x => x.Id == categoryId, cancellationToken);
    }

    private async Task<Result<TemplateCategory>> EnsureTemplateCategoryAsync(string rawCategoryName, string? currentCategoryName, CancellationToken cancellationToken)
    {
        var categoryName = NormalizeCategoryName(rawCategoryName);
        var normalizedName = NormalizeCategoryKey(categoryName);

        var category = await dbContext.TemplateCategories
            .FirstOrDefaultAsync(x => x.NormalizedName == normalizedName, cancellationToken);

        if (category is null)
        {
            var now = DateTime.UtcNow;
            category = new TemplateCategory
            {
                Id = Guid.NewGuid(),
                Name = categoryName,
                NormalizedName = normalizedName,
                IsArchived = false,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };

            dbContext.TemplateCategories.Add(category);
            return Result.Success(category);
        }

        if (category.IsArchived && !string.Equals(category.Name, currentCategoryName, StringComparison.Ordinal))
        {
            return Result.Failure<TemplateCategory>(TemplatesErrors.CategoryArchived);
        }

        return Result.Success(category);
    }

    private async Task<AdminTemplateCategoryListItemResponse> BuildAdminCategoryResponseAsync(TemplateCategory category, CancellationToken cancellationToken)
    {
        var templates = await dbContext.TemplateItems
            .AsNoTracking()
            .Where(x => x.Category == category.Name)
            .ToArrayAsync(cancellationToken);

        return MapAdminCategory(category, templates);
    }

    private Task<TemplateItem?> FindTemplateAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);
    }

    private static int NormalizePublicFeedTake(int? take)
    {
        if (!take.HasValue || take.Value <= 0)
        {
            return PublicFeedDefaultTake;
        }

        return Math.Min(take.Value, PublicFeedMaxTake);
    }

    private static PublicFeedCursor? TryParsePublicFeedCursor(string? rawCursor)
    {
        if (string.IsNullOrWhiteSpace(rawCursor))
        {
            return null;
        }

        var parts = rawCursor.Trim().Split(':', 2, StringSplitOptions.TrimEntries);
        if (parts.Length != 2 || !long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks) || !Guid.TryParseExact(parts[1], "N", out var templateId))
        {
            return null;
        }

        return new PublicFeedCursor(new DateTime(ticks, DateTimeKind.Utc), templateId);
    }

    private static string FormatPublicFeedCursor(TemplateItem template)
    {
        return string.Create(CultureInfo.InvariantCulture, $"{template.UpdatedAtUtc.Ticks}:{template.Id:N}");
    }

    private static bool IsAfterPublicFeedCursor(TemplateItem template, PublicFeedCursor cursor)
    {
        if (template.UpdatedAtUtc < cursor.UpdatedAtUtc)
        {
            return true;
        }

        return template.UpdatedAtUtc == cursor.UpdatedAtUtc && template.Id.CompareTo(cursor.TemplateId) < 0;
    }

    private static bool MatchesPublicFeedSearch(TemplateItem template, string? search)
    {
        if (string.IsNullOrWhiteSpace(search))
        {
            return true;
        }

        return template.Title.Contains(search, StringComparison.OrdinalIgnoreCase)
            || (template.ShortDescription ?? string.Empty).Contains(search, StringComparison.OrdinalIgnoreCase)
            || (template.Category ?? string.Empty).Contains(search, StringComparison.OrdinalIgnoreCase)
            || DeserializeRequirements(template.PetPhotoRequirements).Any(requirement => requirement.Contains(search, StringComparison.OrdinalIgnoreCase))
            || DeserializeTags(template.Tags).Any(tag => tag.Contains(search, StringComparison.OrdinalIgnoreCase));
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return tags
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string SerializeTags(IEnumerable<string> tags)
    {
        return string.Join(',', NormalizeTags(tags));
    }

    private static string[] DeserializeTags(string? tags)
    {
        if (string.IsNullOrWhiteSpace(tags))
        {
            return [];
        }

        return NormalizeTags(tags.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string? SerializeRequirements(IEnumerable<string>? requirements)
    {
        var normalized = NormalizeRequirements(requirements ?? []);
        return normalized.Length == 0 ? null : string.Join('\n', normalized);
    }

    private static string[] DeserializeRequirements(string? requirements)
    {
        if (string.IsNullOrWhiteSpace(requirements))
        {
            return [];
        }

        return NormalizeRequirements(requirements.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string[] NormalizeRequirements(IEnumerable<string> requirements)
    {
        return requirements
            .Select(requirement => requirement.Trim())
            .Where(requirement => !string.IsNullOrWhiteSpace(requirement))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Take(6)
            .ToArray();
    }

    private static string NormalizeCategoryName(string rawCategoryName)
    {
        return rawCategoryName.Trim();
    }

    private static string NormalizeCategoryKey(string categoryName)
    {
        return categoryName.Trim().ToUpperInvariant();
    }

    private static string ResolvePrompt(string prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    private async Task CleanupObsoleteMediaAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                await mediaLifecycleService.MarkCleanupFailureAsync(assetUrl, deleteResult.Error.Code, deleteResult.Error.Message, cancellationToken);
                continue;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);
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

        return jobsByDay.Keys
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
            })
            .ToArray();
    }

    private static IReadOnlyList<AdminTemplatesAnalyticsBreakdownResponse> BuildTemplatesAnalyticsBreakdown(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        Func<AdminTemplatesAnalyticsTemplateRowResponse, string> selector)
    {
        return rows
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
            })
            .ToArray();
    }

    private static IEnumerable<AdminTemplatesAnalyticsTemplateRowResponse> SortTemplatesAnalyticsRows(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        string? sort)
    {
        var normalizedSort = NormalizeAnalyticsFilter(sort) ?? "views";
        IOrderedEnumerable<AdminTemplatesAnalyticsTemplateRowResponse> ordered = normalizedSort switch
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

    private async Task<GenerationAnalyticsProjection[]?> GetAnalyticsProjectionsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return null;
        }

        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
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
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
                x.CreatedAtUtc,
                x.StartedAtUtc,
                x.CompletedAtUtc))
            .ToArrayAsync(cancellationToken);
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

        return events
            .Select(selector)
            .Select(value => NormalizeAnalyticsValue(value, fallback, 64))
            .GroupBy(value => value)
            .OrderByDescending(group => group.Count())
            .ThenBy(group => group.Key)
            .Select(group => new AdminTemplateAnalyticsDimensionResponse(
                group.Key,
                FormatDimensionLabel(group.Key),
                group.Count(),
                Math.Round((double)group.Count() * 100 / events.Count, 1, MidpointRounding.AwayFromZero)))
            .ToArray();
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

    private async Task<Result> DeleteTemplateAssetsAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                return deleteResult;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    private static string[] CollectObsoleteAssetUrls(IEnumerable<string?> assetUrls)
    {
        return assetUrls
            .Where(assetUrl => !string.IsNullOrWhiteSpace(assetUrl))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private ValueTask PublishFeedInvalidatedAsync(CancellationToken cancellationToken)
    {
        return templateFeedRealtimeService.PublishTemplatesFeedInvalidatedAsync(cancellationToken);
    }

    private static string? SetAsset(TemplateItem template, TemplateAssetKind assetKind, TemplateAssetCommand? asset)
    {
        var existing = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        if (asset is null)
        {
            if (existing is not null)
            {
                var removedUrl = existing.Url;
                template.Assets.Remove(existing);
                return removedUrl;
            }

            return null;
        }

        if (existing is null)
        {
            existing = new TemplateAsset
            {
                Id = Guid.NewGuid(),
                TemplateId = template.Id,
                AssetKind = assetKind
            };
            template.Assets.Add(existing);
        }

        var obsoleteUrl = !string.IsNullOrWhiteSpace(existing.Url)
            && !string.Equals(existing.Url, asset.Url, StringComparison.OrdinalIgnoreCase)
                ? existing.Url
                : null;

        existing.Url = asset.Url;
        existing.FileName = asset.FileName;
        existing.ContentType = asset.ContentType;
        existing.FileSizeBytes = asset.FileSizeBytes;
        existing.DurationSeconds = asset.DurationSeconds;

        return obsoleteUrl;
    }

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(asset.Url, asset.FileName, asset.ContentType, asset.FileSizeBytes, asset.DurationSeconds);
    }

    private static AdminTemplateListItemResponse MapAdminListItem(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        // Calculate estimated USD cost based on template models
        decimal? estimatedCostUsd = null;
        if (template.TemplateType == TemplateType.Image)
        {
            estimatedCostUsd = FalModelPricing.TryGetImageGenerationCostUsd(template.ImageModel);
        }
        else if (template.TemplateType == TemplateType.Video)
        {
            estimatedCostUsd = FalModelPricing.TryCalculateEstimatedGenerationCostUsd(
                template.PreprocessingModel,
                template.KlingModel,
                template.ReferenceVideoDurationSeconds);
        }

        return new AdminTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            estimatedCostUsd,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static AdminTemplateCategoryListItemResponse MapAdminCategory(TemplateCategory category, IReadOnlyCollection<TemplateItem> templates)
    {
        var tags = templates
            .SelectMany(template => DeserializeTags(template.Tags))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(tag => tag, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        return new AdminTemplateCategoryListItemResponse(
            category.Id,
            category.Name,
            category.IsArchived,
            templates.Count,
            templates.Count(template => template.TemplateType == TemplateType.Video),
            templates.Count(template => template.TemplateType == TemplateType.Image),
            templates.Count(template => template.Status == TemplateStatus.Active),
            templates.Count(template => template.Status == TemplateStatus.Draft),
            templates.Count(template => template.Status == TemplateStatus.Archived),
            templates.Count(template => template.IsPremium),
            tags,
            category.CreatedAtUtc,
            category.UpdatedAtUtc);
    }

    private static AdminTemplateResponse MapAdminResponse(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            GetAsset(template, TemplateAssetKind.ReferenceMotion),
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.ImageModel,
            template.ImagePrompt,
            template.PreprocessingModel,
            template.PreprocessingPrompt,
            template.KlingModel,
            template.KlingPrompt,
            template.KeepOriginalSound,
            template.TemplateType == TemplateType.Image
                ? FalModelPricing.TryGetImageGenerationCostUsd(template.ImageModel)
                : FalModelPricing.TryCalculateEstimatedGenerationCostUsd(
                    template.PreprocessingModel,
                    template.KlingModel,
                    template.ReferenceVideoDurationSeconds),
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static PublicTemplateListItemResponse MapPublicListItem(TemplateItem template)
    {
        return new PublicTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static PublicTemplateResponse MapPublicResponse(TemplateItem template)
    {
        return new PublicTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            DeserializeRequirements(template.PetPhotoRequirements));
    }

    private static TemplatePromoBadgeMode ParsePromoBadgeMode(string raw)
    {
        return Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out var mode)
            ? mode
            : TemplatePromoBadgeMode.Auto;
    }

    private static string? ResolveEffectivePromoBadge(TemplateItem template, DateTime utcNow)
    {
        if (template.PromoBadgeMode != TemplatePromoBadgeMode.Auto)
        {
            return template.PromoBadgeMode.ToString();
        }

        return TemplatePromoBadgeRules.ResolveAutoBadge(
            template.CreatedAtUtc,
            template.UpdatedAtUtc,
            template.Status,
            template.IsPremium,
            template.TokenCost,
            [
                template.Title,
                template.ShortDescription,
                template.Category,
                template.Tags,
                template.MusicDescription,
                template.ImagePrompt,
                template.KlingPrompt
            ],
            utcNow);
    }
}
