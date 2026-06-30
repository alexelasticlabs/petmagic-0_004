using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateAdminAnalyticsService
{
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
}
