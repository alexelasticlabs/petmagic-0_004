using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class AdminUserTemplateAnalyticsReader(
    TemplatesDbContext dbContext,
    IMediaStorage mediaStorage,
    TemplatesOptions options) : IAdminUserTemplateAnalyticsReader
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

        var recentGenerations = new List<AdminUserTemplateGenerationResponse>(recentGenerationRows.Count);
        foreach (var row in recentGenerationRows)
        {
            var signedOutputUrl = await CreateAdminReadUrlAsync(row.OutputUrl, cancellationToken);
            recentGenerations.Add(new AdminUserTemplateGenerationResponse(
                row.Id,
                row.TemplateId,
                row.TemplateTitle ?? string.Empty,
                row.TemplateType.ToString(),
                row.Status.ToString(),
                row.TokenCost,
                row.FailureCode,
                AdminFailureMessageSanitizer.Sanitize(row.FailureMessage),
                signedOutputUrl,
                row.CreatedAtUtc,
                row.CompletedAtUtc));
        }

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

    public async Task<IReadOnlyDictionary<Guid, DateTime>> GetAdminUserLastActivityAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, DateTime>();
        }

        var generationActivity = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(generation => userIds.Contains(generation.UserId))
            .GroupBy(generation => generation.UserId)
            .Select(group => new
            {
                UserId = group.Key,
                LastActivityAtUtc = group.Max(generation => (DateTime?)generation.CreatedAtUtc)
            })
            .ToListAsync(cancellationToken);

        var templateEventActivity = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(templateEvent => templateEvent.UserId.HasValue && userIds.Contains(templateEvent.UserId.Value))
            .GroupBy(templateEvent => templateEvent.UserId!.Value)
            .Select(group => new
            {
                UserId = group.Key,
                LastActivityAtUtc = group.Max(templateEvent => (DateTime?)templateEvent.CreatedAtUtc)
            })
            .ToListAsync(cancellationToken);

        var lastActivityByUserId = new Dictionary<Guid, DateTime>();
        foreach (var row in generationActivity.Concat(templateEventActivity))
        {
            if (!row.LastActivityAtUtc.HasValue)
            {
                continue;
            }

            if (!lastActivityByUserId.TryGetValue(row.UserId, out var current)
                || row.LastActivityAtUtc.Value > current)
            {
                lastActivityByUserId[row.UserId] = row.LastActivityAtUtc.Value;
            }
        }

        return lastActivityByUserId;
    }

    private async Task<string?> CreateAdminReadUrlAsync(string? assetUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return null;
        }

        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }
}
