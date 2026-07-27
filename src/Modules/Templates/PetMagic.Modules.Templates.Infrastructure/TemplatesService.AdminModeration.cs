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
    private const int AdminModerationDecisionReasonMinLength = 3;
    private const int AdminModerationDecisionReasonMaxLength = 500;
    private const string PendingModerationStatus = "pending";
    private const string ApprovedModerationStatus = "approved";
    private const string RejectedModerationStatus = "rejected";

    public async Task<Result<AdminModerationQueuePageResponse>> GetAdminModerationQueueAsync(
        AdminModerationQueueQuery query,
        CancellationToken cancellationToken)
    {
        var skip = Math.Max(0, query.Skip ?? 0);
        var take = Math.Clamp(query.Take ?? AdminModerationDefaultTake, 1, AdminModerationMaxTake);
        var status = NormalizeModerationStatus(query.Status);
        var search = NormalizeQueryValue(query.Search);

        var moderationEvents = dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(analyticsEvent =>
                analyticsEvent.EventType == TemplateAnalyticsEventTypes.Complaint ||
                analyticsEvent.EventType == TemplateAnalyticsEventTypes.Feedback);
        var summaryProjection = await moderationEvents
            .GroupBy(_ => 1)
            .Select(group => new AdminModerationSummaryProjection(
                group.Count(analyticsEvent => analyticsEvent.ModerationStatus == PendingModerationStatus),
                group.Count(analyticsEvent => analyticsEvent.ModerationStatus == ApprovedModerationStatus),
                group.Count(analyticsEvent => analyticsEvent.ModerationStatus == RejectedModerationStatus),
                group.Count(analyticsEvent =>
                    analyticsEvent.ModerationStatus == PendingModerationStatus
                    && analyticsEvent.EventType == TemplateAnalyticsEventTypes.Complaint),
                group.Count(analyticsEvent =>
                    analyticsEvent.ModerationStatus == PendingModerationStatus
                    && analyticsEvent.EventType == TemplateAnalyticsEventTypes.Feedback),
                group.Where(analyticsEvent => analyticsEvent.ModerationStatus == PendingModerationStatus)
                    .Min(analyticsEvent => (DateTime?)analyticsEvent.CreatedAtUtc)))
            .SingleOrDefaultAsync(cancellationToken);

        IQueryable<Entities.TemplateAnalyticsEvent> events = moderationEvents
            .Include(analyticsEvent => analyticsEvent.Template);

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
            .OrderBy(analyticsEvent => analyticsEvent.ModerationStatus == PendingModerationStatus ? 0 : 1)
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

        var generatedAtUtc = DateTime.UtcNow;
        var summary = new AdminModerationQueueSummaryResponse(
            summaryProjection?.PendingCount ?? 0,
            summaryProjection?.ApprovedCount ?? 0,
            summaryProjection?.RejectedCount ?? 0,
            summaryProjection?.PendingComplaintsCount ?? 0,
            summaryProjection?.PendingFeedbackCount ?? 0,
            summaryProjection?.OldestPendingAtUtc,
            generatedAtUtc);

        return Result.Success(new AdminModerationQueuePageResponse(
            items,
            skip,
            take,
            totalCount,
            hasMore,
            generatedAtUtc,
            summary));
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

        var reason = NormalizeModerationDecisionReason(command.Reason);
        if (reason is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationDecisionReason);
        }

        return await DecideAdminModerationItemWithLeaseAsync(command, action, reason, cancellationToken);
    }

    private static Result<AdminModerationQueueItemResponse> ResolveExistingModerationDecision(
        Entities.TemplateAnalyticsEvent analyticsEvent,
        string action,
        string reason)
    {
        if (string.Equals(analyticsEvent.ModerationStatus, action, StringComparison.Ordinal)
            && string.Equals(
                NormalizePersistedModerationReason(analyticsEvent.ModerationComment),
                reason,
                StringComparison.Ordinal))
        {
            return Result.Success(MapModerationQueueItem(analyticsEvent));
        }

        return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationDecisionConflict);
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
            analyticsEvent.ModeratedAtUtc,
            analyticsEvent.ModerationLeaseOwnerUserId,
            analyticsEvent.ModerationLeaseClaimedAtUtc,
            analyticsEvent.ModerationLeaseExpiresAtUtc,
            analyticsEvent.ModerationVersion);
    }

    private static string NormalizeModerationStatus(string? value)
    {
        var normalized = NormalizeQueryValue(value);
        return normalized switch
        {
            "" or "all" => string.Empty,
            "approved" or "approve" => ApprovedModerationStatus,
            "rejected" or "reject" => RejectedModerationStatus,
            "pending" => PendingModerationStatus,
            _ => string.Empty
        };
    }

    private static string NormalizeModerationDecision(string? value)
    {
        var normalized = NormalizeQueryValue(value);
        return normalized switch
        {
            "approved" or "approve" => ApprovedModerationStatus,
            "rejected" or "reject" => RejectedModerationStatus,
            _ => string.Empty
        };
    }

    private static string? NormalizeModerationDecisionReason(string? value)
    {
        var normalized = value?.Trim() ?? string.Empty;
        return normalized.Length is >= AdminModerationDecisionReasonMinLength and <= AdminModerationDecisionReasonMaxLength
            ? normalized
            : null;
    }

    private static string NormalizePersistedModerationReason(string? value)
    {
        return value?.Trim() ?? string.Empty;
    }

    private sealed record AdminModerationSummaryProjection(
        int PendingCount,
        int ApprovedCount,
        int RejectedCount,
        int PendingComplaintsCount,
        int PendingFeedbackCount,
        DateTime? OldestPendingAtUtc);
}
