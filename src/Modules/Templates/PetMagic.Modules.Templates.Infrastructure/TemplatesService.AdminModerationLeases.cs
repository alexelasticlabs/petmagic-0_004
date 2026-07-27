using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private const int AdminModerationDefaultLeaseMinutes = 15;
    private const int AdminModerationMinLeaseMinutes = 5;
    private const int AdminModerationMaxLeaseMinutes = 30;

    public async Task<Result<AdminModerationQueueItemResponse>> ClaimAdminModerationItemAsync(
        AdminModerationClaimCommand command,
        CancellationToken cancellationToken)
    {
        if (!TryResolveModerationLeaseRequest(
                command.ActorUserId,
                command.ExpectedVersion,
                command.LeaseMinutes,
                out var expectedVersion,
                out var leaseDuration))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationLease);
        }

        var analyticsEvent = await LoadTrackedAdminModerationEventAsync(command.EventId, cancellationToken);
        if (analyticsEvent is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.NotFound);
        }

        var pendingError = ValidatePendingModerationLeaseMutation(analyticsEvent, expectedVersion);
        if (pendingError is not null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(pendingError);
        }

        var now = DateTime.UtcNow;
        if (HasActiveModerationLease(analyticsEvent, now)
            && analyticsEvent.ModerationLeaseOwnerUserId != command.ActorUserId)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseNotOwned);
        }

        var previousOwner = analyticsEvent.ModerationLeaseOwnerUserId;
        analyticsEvent.ModerationLeaseOwnerUserId = command.ActorUserId;
        analyticsEvent.ModerationLeaseClaimedAtUtc = now;
        analyticsEvent.ModerationLeaseExpiresAtUtc = now.Add(leaseDuration);
        analyticsEvent.ModerationVersion++;

        var pendingAudit = EnqueueModerationAudit(
            analyticsEvent,
            command.ActorUserId,
            command.ActorRole,
            "admin.content.moderation_claimed",
            FormatModerationOwner(previousOwner),
            FormatModerationOwner(command.ActorUserId),
            $"lease_minutes={(int)leaseDuration.TotalMinutes}",
            now);

        return await PersistModerationMutationAsync(analyticsEvent, pendingAudit, cancellationToken);
    }

    public async Task<Result<AdminModerationQueueItemResponse>> ReleaseAdminModerationItemAsync(
        AdminModerationReleaseCommand command,
        CancellationToken cancellationToken)
    {
        if (!TryResolveModerationExpectedVersion(command.ActorUserId, command.ExpectedVersion, out var expectedVersion))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationLease);
        }

        var reason = NormalizeModerationDecisionReason(command.Reason);
        if (reason is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationLeaseReason);
        }

        var analyticsEvent = await LoadTrackedAdminModerationEventAsync(command.EventId, cancellationToken);
        if (analyticsEvent is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.NotFound);
        }

        var pendingError = ValidatePendingModerationLeaseMutation(analyticsEvent, expectedVersion);
        if (pendingError is not null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(pendingError);
        }

        var previousOwner = analyticsEvent.ModerationLeaseOwnerUserId;
        if (!previousOwner.HasValue)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseRequired);
        }

        if (previousOwner.Value != command.ActorUserId && !command.CanManageOtherLeases)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseNotOwned);
        }

        var now = DateTime.UtcNow;
        ClearModerationLease(analyticsEvent);
        analyticsEvent.ModerationVersion++;

        var pendingAudit = EnqueueModerationAudit(
            analyticsEvent,
            command.ActorUserId,
            command.ActorRole,
            "admin.content.moderation_released",
            FormatModerationOwner(previousOwner),
            "unassigned",
            $"reason={reason}",
            now);

        return await PersistModerationMutationAsync(analyticsEvent, pendingAudit, cancellationToken);
    }

    public async Task<Result<AdminModerationQueueItemResponse>> HandoffAdminModerationItemAsync(
        AdminModerationHandoffCommand command,
        CancellationToken cancellationToken)
    {
        if (command.AssigneeUserId == Guid.Empty
            || !TryResolveModerationLeaseRequest(
                command.ActorUserId,
                command.ExpectedVersion,
                command.LeaseMinutes,
                out var expectedVersion,
                out var leaseDuration))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationLease);
        }

        var reason = NormalizeModerationDecisionReason(command.Reason);
        if (reason is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationLeaseReason);
        }

        if (identityUserLookupService is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationAssignee);
        }

        var activeOperatorIds = await identityUserLookupService.GetActiveUserIdsInRolesAsync(
            [SystemRoles.Admin, SystemRoles.Moderator],
            cancellationToken);
        if (!activeOperatorIds.Contains(command.AssigneeUserId))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.InvalidModerationAssignee);
        }

        var analyticsEvent = await LoadTrackedAdminModerationEventAsync(command.EventId, cancellationToken);
        if (analyticsEvent is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.NotFound);
        }

        var pendingError = ValidatePendingModerationLeaseMutation(analyticsEvent, expectedVersion);
        if (pendingError is not null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(pendingError);
        }

        var now = DateTime.UtcNow;
        if (!HasActiveModerationLease(analyticsEvent, now))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseRequired);
        }

        var previousOwner = analyticsEvent.ModerationLeaseOwnerUserId;
        analyticsEvent.ModerationLeaseOwnerUserId = command.AssigneeUserId;
        analyticsEvent.ModerationLeaseClaimedAtUtc = now;
        analyticsEvent.ModerationLeaseExpiresAtUtc = now.Add(leaseDuration);
        analyticsEvent.ModerationVersion++;

        var pendingAudit = EnqueueModerationAudit(
            analyticsEvent,
            command.ActorUserId,
            command.ActorRole,
            "admin.content.moderation_handed_off",
            FormatModerationOwner(previousOwner),
            FormatModerationOwner(command.AssigneeUserId),
            $"reason={reason};lease_minutes={(int)leaseDuration.TotalMinutes}",
            now);

        return await PersistModerationMutationAsync(analyticsEvent, pendingAudit, cancellationToken);
    }

    private async Task<Result<AdminModerationQueueItemResponse>> DecideAdminModerationItemWithLeaseAsync(
        AdminModerationDecisionCommand command,
        string action,
        string reason,
        CancellationToken cancellationToken)
    {
        var analyticsEvent = await LoadTrackedAdminModerationEventAsync(command.EventId, cancellationToken);
        if (analyticsEvent is null)
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.NotFound);
        }

        if (!string.Equals(analyticsEvent.ModerationStatus, PendingModerationStatus, StringComparison.Ordinal))
        {
            return ResolveExistingModerationDecision(analyticsEvent, action, reason);
        }

        if (command.ExpectedVersion.HasValue
            && (command.ExpectedVersion.Value < 0
                || analyticsEvent.ModerationVersion != command.ExpectedVersion.Value))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationDecisionConflict);
        }

        var now = DateTime.UtcNow;
        if (HasActiveModerationLease(analyticsEvent, now)
            && (!command.ActorUserId.HasValue
                || analyticsEvent.ModerationLeaseOwnerUserId != command.ActorUserId.Value))
        {
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseNotOwned);
        }

        var previousStatus = analyticsEvent.ModerationStatus;
        analyticsEvent.ModerationStatus = action;
        analyticsEvent.ModerationComment = reason;
        analyticsEvent.ModeratedAtUtc = now;
        ClearModerationLease(analyticsEvent);
        analyticsEvent.ModerationVersion++;

        var pendingAudit = EnqueueModerationAudit(
            analyticsEvent,
            command.ActorUserId,
            command.ActorRole,
            action == ApprovedModerationStatus ? "admin.content.approved" : "admin.content.rejected",
            previousStatus,
            action,
            $"reason={reason}",
            now);

        return await PersistModerationMutationAsync(analyticsEvent, pendingAudit, cancellationToken);
    }

    private async Task<TemplateAnalyticsEvent?> LoadTrackedAdminModerationEventAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        return await dbContext.TemplateAnalyticsEvents
            .Include(templateAnalyticsEvent => templateAnalyticsEvent.Template)
            .FirstOrDefaultAsync(templateAnalyticsEvent =>
                templateAnalyticsEvent.Id == eventId
                && (templateAnalyticsEvent.EventType == TemplateAnalyticsEventTypes.Complaint
                    || templateAnalyticsEvent.EventType == TemplateAnalyticsEventTypes.Feedback),
                cancellationToken);
    }

    private async Task<Result<AdminModerationQueueItemResponse>> PersistModerationMutationAsync(
        TemplateAnalyticsEvent analyticsEvent,
        TemplateAdminAuditOutbox.PendingAdminAudit pendingAudit,
        CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            return Result.Failure<AdminModerationQueueItemResponse>(TemplatesErrors.ModerationLeaseConflict);
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);

        return Result.Success(MapModerationQueueItem(analyticsEvent));
    }

    private TemplateAdminAuditOutbox.PendingAdminAudit EnqueueModerationAudit(
        TemplateAnalyticsEvent analyticsEvent,
        Guid? actorUserId,
        string? actorRole,
        string action,
        string? oldValue,
        string? newValue,
        string details,
        DateTime occurredAtUtc)
    {
        var entry = new AdminAuditEntry(
            action,
            "template_analytics_event",
            analyticsEvent.Id.ToString("D"),
            oldValue,
            newValue,
            details,
            analyticsEvent.UserId,
            Guid.NewGuid(),
            actorUserId)
        {
            ActorRole = actorRole,
            OccurredAtUtc = occurredAtUtc
        };

        return TemplateAdminAuditOutbox.Enqueue(dbContext, entry);
    }

    private static Error? ValidatePendingModerationLeaseMutation(
        TemplateAnalyticsEvent analyticsEvent,
        long expectedVersion)
    {
        if (!string.Equals(analyticsEvent.ModerationStatus, PendingModerationStatus, StringComparison.Ordinal))
        {
            return TemplatesErrors.ModerationItemNotPending;
        }

        return analyticsEvent.ModerationVersion == expectedVersion
            ? null
            : TemplatesErrors.ModerationLeaseConflict;
    }

    private static bool TryResolveModerationLeaseRequest(
        Guid actorUserId,
        long? requestedVersion,
        int? requestedLeaseMinutes,
        out long expectedVersion,
        out TimeSpan leaseDuration)
    {
        leaseDuration = TimeSpan.Zero;
        if (!TryResolveModerationExpectedVersion(actorUserId, requestedVersion, out expectedVersion))
        {
            return false;
        }

        var leaseMinutes = requestedLeaseMinutes ?? AdminModerationDefaultLeaseMinutes;
        if (leaseMinutes is < AdminModerationMinLeaseMinutes or > AdminModerationMaxLeaseMinutes)
        {
            return false;
        }

        leaseDuration = TimeSpan.FromMinutes(leaseMinutes);
        return true;
    }

    private static bool TryResolveModerationExpectedVersion(
        Guid actorUserId,
        long? requestedVersion,
        out long expectedVersion)
    {
        expectedVersion = requestedVersion ?? -1;
        return actorUserId != Guid.Empty && expectedVersion >= 0;
    }

    private static bool HasActiveModerationLease(TemplateAnalyticsEvent analyticsEvent, DateTime now) =>
        analyticsEvent.ModerationLeaseOwnerUserId.HasValue
        && analyticsEvent.ModerationLeaseExpiresAtUtc > now;

    private static void ClearModerationLease(TemplateAnalyticsEvent analyticsEvent)
    {
        analyticsEvent.ModerationLeaseOwnerUserId = null;
        analyticsEvent.ModerationLeaseClaimedAtUtc = null;
        analyticsEvent.ModerationLeaseExpiresAtUtc = null;
    }

    private static string FormatModerationOwner(Guid? ownerUserId) =>
        ownerUserId.HasValue ? ownerUserId.Value.ToString("D") : "unassigned";
}
