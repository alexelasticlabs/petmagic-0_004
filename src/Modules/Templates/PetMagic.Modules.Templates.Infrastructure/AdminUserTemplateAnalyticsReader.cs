using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class AdminUserTemplateAnalyticsReader(TemplatesDbContext dbContext) : IAdminUserTemplateAnalyticsReader
{
    public async Task<Result<AdminUserTemplateAnalyticsResponse>> GetAdminUserTemplateAnalyticsAsync(
        Guid userId,
        CancellationToken cancellationToken)
    {
        var generationSummary = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TotalGenerations = group.Count(),
                CompletedGenerations = group.Count(x => x.Status == TemplateGenerationStatus.Completed),
                FailedGenerations = group.Count(x => x.Status == TemplateGenerationStatus.Failed),
                LastGenerationAtUtc = group.Max(x => (DateTime?)x.CreatedAtUtc)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var recentGenerationRows = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .Join(
                dbContext.TemplateItems.AsNoTracking(),
                generation => generation.TemplateId,
                template => template.Id,
                (generation, template) => new { generation, template })
            .OrderByDescending(x => x.generation.CreatedAtUtc)
            .Take(10)
            .Select(x => new
            {
                x.generation.Id,
                x.generation.TemplateId,
                TemplateTitle = x.template.Title,
                TemplateType = x.template.TemplateType,
                x.generation.Status,
                x.generation.TokenCost,
                FailureCode = x.generation.LastErrorCode,
                FailureMessage = x.generation.LastErrorMessage,
                OutputUrl = x.generation.ResultUrl,
                x.generation.CreatedAtUtc,
                x.generation.CompletedAtUtc
            })
            .ToListAsync(cancellationToken);

        var recentGenerations = recentGenerationRows
            .Select(x => new AdminUserTemplateGenerationResponse(
                x.Id,
                x.TemplateId,
                x.TemplateTitle ?? string.Empty,
                x.TemplateType.ToString(),
                x.Status.ToString(),
                x.TokenCost,
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
                x.CreatedAtUtc,
                x.CompletedAtUtc))
            .ToList();

        var failureBreakdown = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.Status == TemplateGenerationStatus.Failed)
            .Select(x => new
            {
                FailureCode = x.LastErrorCode,
                LastOccurredAtUtc = x.CompletedAtUtc ?? x.UpdatedAtUtc
            })
            .ToListAsync(cancellationToken);

        var failureBreakdownItems = failureBreakdown
            .GroupBy(x => string.IsNullOrWhiteSpace(x.FailureCode) ? "templates.unknown_failure" : x.FailureCode)
            .Select(group => new AdminUserTemplateFailureBreakdownItemResponse(
                group.Key,
                group.Count(),
                group.Max(x => x.LastOccurredAtUtc)))
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.FailureCode)
            .ToList();

        var templateEventSummary = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                TemplateAnalyticsEvents = group.Count(),
                TotalViews = group.Count(x => x.EventType == TemplateAnalyticsEventTypes.View),
                TotalVideoViews = group.Count(x => x.EventType == TemplateAnalyticsEventTypes.VideoView),
                LastTemplateEventAtUtc = group.Max(x => (DateTime?)x.CreatedAtUtc)
            })
            .FirstOrDefaultAsync(cancellationToken);

        var recentTemplateEventRows = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.UserId == userId)
            .Join(
                dbContext.TemplateItems.AsNoTracking(),
                templateEvent => templateEvent.TemplateId,
                template => template.Id,
                (templateEvent, template) => new { templateEvent, template })
            .OrderByDescending(x => x.templateEvent.CreatedAtUtc)
            .Take(10)
            .Select(x => new
            {
                x.templateEvent.Id,
                x.templateEvent.TemplateId,
                TemplateTitle = x.template.Title,
                x.templateEvent.EventType,
                x.templateEvent.Source,
                x.templateEvent.DeviceClass,
                x.templateEvent.CountryCode,
                x.templateEvent.GenerationId,
                x.templateEvent.FeedbackMessage,
                x.templateEvent.CreatedAtUtc
            })
            .ToListAsync(cancellationToken);

        var recentTemplateEvents = recentTemplateEventRows
            .Select(x => new AdminUserTemplateEventResponse(
                x.Id,
                x.TemplateId,
                x.TemplateTitle ?? string.Empty,
                x.EventType ?? string.Empty,
                x.Source ?? string.Empty,
                x.DeviceClass ?? string.Empty,
                x.CountryCode ?? string.Empty,
                x.GenerationId,
                x.FeedbackMessage,
                x.CreatedAtUtc))
            .ToList();

        var recentActivity = recentGenerations
            .Select(x => new AdminUserTemplateActivityResponse(
                "generation",
                $"Generation {x.Status}",
                x.TemplateTitle,
                x.CompletedAtUtc ?? x.CreatedAtUtc))
            .Concat(recentTemplateEvents.Select(x => new AdminUserTemplateActivityResponse(
                "template-event",
                x.EventType,
                x.TemplateTitle,
                x.CreatedAtUtc)))
            .ToList();

        return Result.Success(new AdminUserTemplateAnalyticsResponse(
            generationSummary?.TotalGenerations ?? 0,
            generationSummary?.CompletedGenerations ?? 0,
            generationSummary?.FailedGenerations ?? 0,
            generationSummary?.LastGenerationAtUtc,
            templateEventSummary?.TotalViews ?? 0,
            templateEventSummary?.TotalVideoViews ?? 0,
            templateEventSummary?.TemplateAnalyticsEvents ?? 0,
            templateEventSummary?.LastTemplateEventAtUtc,
            recentGenerations,
            recentTemplateEvents,
            failureBreakdownItems,
            recentActivity));
    }
}
