using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private const int AdminModerationDefaultTake = 25;
    private const int AdminModerationMaxTake = 100;

    public async Task<Result<AdminModerationQueuePageResponse>> GetAdminModerationQueueAsync(
        AdminModerationQueueQuery query,
        CancellationToken cancellationToken)
    {
        var skip = Math.Max(0, query.Skip ?? 0);
        var take = Math.Clamp(query.Take ?? AdminModerationDefaultTake, 1, AdminModerationMaxTake);
        var status = NormalizeModerationStatus(query.Status);
        var search = NormalizeQueryValue(query.Search);

        var events = dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Include(analyticsEvent => analyticsEvent.Template)
            .Where(analyticsEvent =>
                analyticsEvent.EventType == TemplateAnalyticsEventTypes.Complaint ||
                analyticsEvent.EventType == TemplateAnalyticsEventTypes.Feedback);

        if (!string.IsNullOrEmpty(status))
        {
            events = events.Where(analyticsEvent => analyticsEvent.ModerationStatus == status);
        }

        if (!string.IsNullOrEmpty(search))
        {
            events = events.Where(analyticsEvent =>
                (analyticsEvent.Template.Title ?? string.Empty).ToLower().Contains(search) ||
                (analyticsEvent.FeedbackMessage != null && analyticsEvent.FeedbackMessage.ToLower().Contains(search)) ||
                (analyticsEvent.UserId != null && analyticsEvent.UserId.ToString()!.ToLower().Contains(search)) ||
                (analyticsEvent.GenerationId != null && analyticsEvent.GenerationId.ToString()!.ToLower().Contains(search)));
        }

        var totalCount = await events.CountAsync(cancellationToken);
        var items = await events
            .OrderBy(analyticsEvent => analyticsEvent.ModerationStatus == "pending" ? 0 : 1)
            .ThenByDescending(analyticsEvent => analyticsEvent.CreatedAtUtc)
            .ThenByDescending(analyticsEvent => analyticsEvent.Id)
            .Skip(skip)
            .Take(take + 1)
            .Select(analyticsEvent => MapModerationQueueItem(analyticsEvent))
            .ToListAsync(cancellationToken);

        var hasMore = items.Count > take;
        if (hasMore)
        {
            items.RemoveAt(items.Count - 1);
        }

        return Result.Success(new AdminModerationQueuePageResponse(
            items,
            skip,
            take,
            totalCount,
            hasMore,
            DateTime.UtcNow));
    }

    public async Task<Result<AdminModerationQueueItemResponse>> DecideAdminModerationItemAsync(
        AdminModerationDecisionCommand command,
        CancellationToken cancellationToken)
    {
        var action = NormalizeModerationDecision(command.Action);
        if (string.IsNullOrEmpty(action))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidFeedback);
        }

        var analyticsEvent = await dbContext.TemplateAnalyticsEvents
            .Include(templateAnalyticsEvent => templateAnalyticsEvent.Template)
            .FirstOrDefaultAsync(templateAnalyticsEvent => templateAnalyticsEvent.Id == command.EventId, cancellationToken);
        if (analyticsEvent is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.NotFound);
        }

        var previousStatus = analyticsEvent.ModerationStatus;
        analyticsEvent.ModerationStatus = action;
        analyticsEvent.ModerationComment = NormalizeOptionalModerationComment(command.Reason);
        analyticsEvent.ModeratedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteModerationAuditAsync(analyticsEvent, previousStatus, action, cancellationToken);

        return Result.Success(MapModerationQueueItem(analyticsEvent));
    }

    private async Task WriteModerationAuditAsync(
        Entities.TemplateAnalyticsEvent analyticsEvent,
        string oldValue,
        string newValue,
        CancellationToken cancellationToken)
    {
        if (adminAuditLog is null)
        {
            return;
        }

        await adminAuditLog.WriteAsync(
            new AdminAuditEntry(
                newValue == "approved" ? "admin.content.approved" : "admin.content.rejected",
                "template_analytics_event",
                analyticsEvent.Id.ToString("D"),
                oldValue,
                newValue,
                SubjectUserId: analyticsEvent.UserId),
            cancellationToken);
    }

    private static AdminModerationQueueItemResponse MapModerationQueueItem(Entities.TemplateAnalyticsEvent analyticsEvent)
    {
        return new AdminModerationQueueItemResponse(
            analyticsEvent.Id,
            analyticsEvent.TemplateId,
            analyticsEvent.Template.Title ?? string.Empty,
            analyticsEvent.Template.TemplateType.ToString(),
            analyticsEvent.EventType ?? string.Empty,
            analyticsEvent.ModerationStatus ?? string.Empty,
            analyticsEvent.FeedbackMessage,
            analyticsEvent.Source ?? string.Empty,
            analyticsEvent.DeviceClass ?? string.Empty,
            analyticsEvent.CountryCode ?? string.Empty,
            analyticsEvent.UserId,
            analyticsEvent.GenerationId,
            analyticsEvent.ModerationComment,
            analyticsEvent.CreatedAtUtc,
            analyticsEvent.ModeratedAtUtc);
    }

    private static string NormalizeModerationStatus(string? value)
    {
        var normalized = NormalizeQueryValue(value);
        return normalized switch
        {
            "" or "all" => string.Empty,
            "approved" or "approve" => "approved",
            "rejected" or "reject" => "rejected",
            "pending" => "pending",
            _ => string.Empty
        };
    }

    private static string NormalizeModerationDecision(string? value)
    {
        var normalized = NormalizeQueryValue(value);
        return normalized switch
        {
            "approved" or "approve" => "approved",
            "rejected" or "reject" => "rejected",
            _ => string.Empty
        };
    }

    private static string? NormalizeOptionalModerationComment(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return null;
        }

        return trimmed.Length <= 500 ? trimmed : trimmed[..500];
    }
}
