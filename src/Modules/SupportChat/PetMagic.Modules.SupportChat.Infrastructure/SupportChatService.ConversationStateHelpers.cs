using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private static Error? ValidateConversationCanAcceptMessage(
        SupportConversation conversation,
        bool isAdmin,
        DateTime now)
    {
        var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (normalizedStatus == SupportConversationStatus.Closed)
        {
            return isAdmin ? SupportChatErrors.ConversationReadOnly : null;
        }

        return null;
    }

    private static bool ShouldReactivateConversationForUserMessage(SupportConversation conversation, DateTime now)
    {
        return ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
    }

    private static void MarkClosed(SupportConversation conversation, DateTime now, Guid? closedByUserId)
    {
        UpdateResolutionSlaPause(conversation, SupportConversationStatus.Closed, now);
        conversation.Status = SupportConversationStatus.Closed;
        conversation.ResolvedAtUtc ??= now;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = now;
        conversation.ClosedByUserId = closedByUserId;
        conversation.WaitingSinceUtc = null;
        conversation.UpdatedAtUtc = now;
    }

    private static void MarkActive(
        SupportConversation conversation,
        SupportConversationStatus status,
        DateTime now,
        Guid? reopenedByUserId = null)
    {
        var wasClosed = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
        UpdateResolutionSlaPause(conversation, status, now);
        conversation.Status = status;
        conversation.ResolvedAtUtc = null;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = null;
        conversation.ClosedByUserId = null;
        if (wasClosed || reopenedByUserId.HasValue)
        {
            conversation.ReopenedAtUtc = now;
            conversation.ReopenedByUserId = reopenedByUserId;
        }

        conversation.WaitingSinceUtc = ResolveWaitingSince(status, conversation.LastMessageAtUtc, conversation.CreatedAtUtc);
        conversation.UpdatedAtUtc = now;
    }

    private static void UpdateResolutionSlaPause(
        SupportConversation conversation,
        SupportConversationStatus nextStatus,
        DateTime now)
    {
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (currentStatus == SupportConversationStatus.WaitingForUser
            && nextStatus != SupportConversationStatus.WaitingForUser
            && conversation.ResolutionSlaPausedAtUtc.HasValue)
        {
            var pauseSeconds = Math.Max(
                0,
                (long)Math.Floor((now - conversation.ResolutionSlaPausedAtUtc.Value).TotalSeconds));
            conversation.ResolutionSlaPausedSeconds += pauseSeconds;
            conversation.ResolutionSlaPausedAtUtc = null;
        }
        else if (currentStatus != SupportConversationStatus.WaitingForUser
                 && nextStatus == SupportConversationStatus.WaitingForUser)
        {
            conversation.ResolutionSlaPausedAtUtc = now;
        }
    }

    private Task AppendStatusChangedEventAsync(
        SupportConversation conversation,
        SupportConversationStatus currentStatus,
        SupportConversationStatus nextStatus)
    {
        return AppendSystemEventAsync(conversation, $"Status changed: {currentStatus} -> {nextStatus}");
    }

    private static DateTime? ResolveWaitingSince(
        SupportConversationStatus status,
        DateTime? lastMessageAtUtc,
        DateTime createdAtUtc)
    {
        return status switch
        {
            SupportConversationStatus.New or SupportConversationStatus.InProgress => lastMessageAtUtc ?? createdAtUtc,
            _ => null
        };
    }

    private static int CalculateWaitingMinutes(DateTime? waitingSinceUtc, DateTime now)
    {
        if (!waitingSinceUtc.HasValue)
        {
            return 0;
        }

        return Math.Max(0, (int)Math.Floor((now - waitingSinceUtc.Value).TotalMinutes));
    }

    private static IReadOnlyList<string> ResolveAvailableActions(
        SupportConversationStatus status,
        bool hasAssignment)
    {
        if (!hasAssignment)
        {
            return [];
        }

        return status switch
        {
            SupportConversationStatus.New => ["close"],
            SupportConversationStatus.InProgress => ["close", "unassign"],
            SupportConversationStatus.WaitingForUser => ["close"],
            SupportConversationStatus.Closed => ["reopen"],
            _ => []
        };
    }

    private static DateTime? ResolveReopenUntil(SupportConversation conversation)
    {
        return ResolveReopenUntil(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc);
    }

    private static DateTime? ResolveReopenUntil(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc)
    {
        return null;
    }

    private static bool CanReopenConversation(SupportConversation conversation, DateTime now)
    {
        return CanReopenConversation(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now);
    }

    private static bool CanReopenConversation(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static bool IsConversationReadOnly(SupportConversation conversation, DateTime now)
    {
        return IsConversationReadOnly(
            conversation.Status,
            conversation.ResolvedAtUtc,
            conversation.ReopenUntilUtc,
            conversation.ClosedAtUtc,
            now);
    }

    private static bool IsConversationReadOnly(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime? closedAtUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static SupportConversationStatus ToCanonicalStatus(
        SupportConversationStatus status,
        Guid? assignedAdminId = null)
    {
        _ = assignedAdminId;

        return status switch
        {
            SupportConversationStatus.New => SupportConversationStatus.New,
            SupportConversationStatus.InProgress => SupportConversationStatus.InProgress,
            SupportConversationStatus.Closed => SupportConversationStatus.Closed,
            SupportConversationStatus.WaitingForUser => SupportConversationStatus.WaitingForUser,
            _ => SupportConversationStatus.New
        };
    }

    private static SupportConversationSource ToCanonicalSource(SupportConversationSource source)
    {
        return source switch
        {
            SupportConversationSource.MobileAssistant => SupportConversationSource.MobileAssistant,
            SupportConversationSource.MobileChat => SupportConversationSource.MobileChat,
            SupportConversationSource.AdminCreated => SupportConversationSource.AdminCreated,
            SupportConversationSource.System => SupportConversationSource.System,
            _ => SupportConversationSource.MobileChat
        };
    }
}
