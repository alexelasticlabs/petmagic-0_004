using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private Task<SupportConversationDetailResponse> BuildConversationDetailAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
        => BuildConversationDetailAsync(conversationId, query: null, cancellationToken);

    private async Task<SupportConversationDetailResponse> BuildConversationDetailAsync(
        Guid conversationId,
        SupportConversationMessagesQuery? query,
        CancellationToken cancellationToken)
    {
        var normalizedTake = Math.Clamp(
            query?.Take ?? DefaultConversationMessagesTake,
            1,
            MaxConversationMessagesTake);

        var conversation = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .Select(x => new
            {
                x.Id,
                x.InitiatorUserId,
                x.AssignedAdminId,
                x.Version,
                x.Status,
                x.Priority,
                x.Source,
                x.TagsJson,
                x.AssistantScenario,
                x.RelatedGenerationId,
                x.RelatedPaymentId,
                x.RelatedSubscriptionId,
                x.CreatedAtUtc,
                x.UpdatedAtUtc,
                x.LastMessageAtUtc,
                x.LastMessagePreview,
                x.LastMessageSenderType,
                x.WaitingSinceUtc,
                x.FirstResponseAtUtc,
                x.ResolutionSlaPausedAtUtc,
                x.ResolutionSlaPausedSeconds,
                x.ResolvedAtUtc,
                x.ReopenUntilUtc,
                x.ClosedAtUtc,
                x.ClosedByUserId,
                x.ReopenedAtUtc,
                x.ReopenedByUserId,
                x.FeedbackRating,
                x.FeedbackComment,
                x.FeedbackSubmittedAtUtc,
                UserUnreadCount = x.Messages.Count(message => message.IsFromAdmin && message.ReadAtUtc == null),
                AdminUnreadCount = x.Messages.Count(message => !message.IsFromAdmin && message.ReadAtUtc == null)
            })
            .FirstAsync(x => x.Id == conversationId, cancellationToken);

        var messagesQuery = supportChatDbContext.ConversationMessages
            .AsNoTracking()
            .Where(x => x.ConversationId == conversationId)
            .Include(x => x.Attachments)
            .AsQueryable();

        if (query?.BeforeMessageCreatedAtUtc is { } beforeMessageCreatedAtUtc)
        {
            messagesQuery = query.BeforeMessageId is { } beforeMessageId
                ? messagesQuery.Where(x =>
                    x.CreatedAtUtc < beforeMessageCreatedAtUtc ||
                    (x.CreatedAtUtc == beforeMessageCreatedAtUtc && x.Id.CompareTo(beforeMessageId) < 0))
                : messagesQuery.Where(x => x.CreatedAtUtc < beforeMessageCreatedAtUtc);
        }

        var pagedMessages = await messagesQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);
        var hasOlderMessages = pagedMessages.Count > normalizedTake;
        var visibleMessages = pagedMessages
            .Take(normalizedTake)
            .ToList();
        visibleMessages.Reverse();

        var userIds = visibleMessages
            .Select(x => x.SenderUserId)
            .Append(conversation.InitiatorUserId)
            .Concat(conversation.AssignedAdminId.HasValue ? [conversation.AssignedAdminId.Value] : [])
            .Distinct()
            .ToList();

        var users = await identityUserLookupService.GetUsersByIdsAsync(userIds, cancellationToken);

        users.TryGetValue(conversation.InitiatorUserId, out var initiator);
        IdentityUserLookup? assignedAdmin = null;
        if (conversation.AssignedAdminId.HasValue)
        {
            users.TryGetValue(conversation.AssignedAdminId.Value, out assignedAdmin);
        }

        var messages = new List<SupportMessageResponse>(visibleMessages.Count);
        foreach (var message in visibleMessages)
        {
            users.TryGetValue(message.SenderUserId, out var sender);
            var resolvedSenderType = ResolveSenderDisplayType(message.SenderType, message.IsFromAdmin);
            var messageAttachments = BuildAttachmentResponses(message);
            var pendingAttachment = BuildPendingAttachmentResponse(message, messageAttachments);
            messages.Add(new SupportMessageResponse(
                message.Id,
                message.ConversationId,
                message.SenderUserId,
                ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
                message.IsFromAdmin,
                resolvedSenderType,
                message.Body ?? string.Empty,
                message.ReplyToMessageId,
                message.ReplyToPreview,
                ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
                message.AttachmentUploadErrorCode,
                pendingAttachment,
                messageAttachments,
                message.ReadAtUtc.HasValue,
                message.ReadAtUtc,
                message.DeliveredAtUtc,
                message.IsInternalNote,
                message.CreatedAtUtc));
        }

        var oldestLoadedMessageCreatedAtUtc = visibleMessages.FirstOrDefault()?.CreatedAtUtc;

        var now = DateTime.UtcNow;
        var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var normalizedSource = ToCanonicalSource(conversation.Source);
        var lastVisibleMessage = visibleMessages.LastOrDefault(message =>
            message.SenderType != SupportMessageSenderType.System && !message.IsInternalNote);
        var waitingSince = conversation.WaitingSinceUtc
            ?? ResolveWaitingSince(
                normalizedStatus,
                conversation.LastMessageAtUtc ?? lastVisibleMessage?.CreatedAtUtc,
                conversation.CreatedAtUtc);

        return new SupportConversationDetailResponse(
            conversation.Id,
            conversation.InitiatorUserId,
            initiator?.Email ?? string.Empty,
            initiator?.DisplayName,
            conversation.AssignedAdminId,
            ResolveDisplayName(assignedAdmin?.Email, assignedAdmin?.DisplayName, isAdminSender: true),
            normalizedStatus.ToString(),
            conversation.Priority.ToString(),
            normalizedSource.ToString(),
            ParseTags(conversation.TagsJson),
            conversation.AssistantScenario,
            conversation.RelatedGenerationId,
            conversation.RelatedPaymentId,
            conversation.RelatedSubscriptionId,
            conversation.UserUnreadCount,
            conversation.AdminUnreadCount,
            conversation.CreatedAtUtc,
            conversation.UpdatedAtUtc,
            conversation.LastMessageAtUtc ?? lastVisibleMessage?.CreatedAtUtc,
            conversation.LastMessagePreview ?? (lastVisibleMessage is null ? null : Truncate(lastVisibleMessage.Body, 280)),
            (conversation.LastMessageSenderType ?? lastVisibleMessage?.SenderType)?.ToString(),
            waitingSince,
            CalculateWaitingMinutes(waitingSince, now),
            conversation.ResolvedAtUtc,
            ResolveReopenUntil(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc),
            conversation.ClosedAtUtc,
            conversation.ClosedByUserId,
            conversation.ReopenedAtUtc,
            conversation.ReopenedByUserId,
            conversation.FeedbackRating,
            conversation.FeedbackComment,
            conversation.FeedbackSubmittedAtUtc,
            IsConversationReadOnly(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, conversation.ClosedAtUtc, now),
            CanReopenConversation(normalizedStatus, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now),
            ResolveAvailableActions(normalizedStatus, conversation.AssignedAdminId.HasValue),
            hasOlderMessages,
            oldestLoadedMessageCreatedAtUtc,
            messages,
            conversation.Version,
            BuildSla(
                conversation.Priority,
                conversation.CreatedAtUtc,
                conversation.FirstResponseAtUtc,
                conversation.ResolvedAtUtc,
                conversation.ResolutionSlaPausedAtUtc,
                conversation.ResolutionSlaPausedSeconds,
                now));
    }

    private async Task<SupportMessageResponse> BuildMessageResponseAsync(
        ConversationMessage message,
        CancellationToken cancellationToken,
        bool isIdempotencyReplay = false)
    {
        var sender = await identityUserLookupService.GetUserByIdAsync(message.SenderUserId, cancellationToken);
        var messageAttachments = BuildAttachmentResponses(message);
        var pendingAttachment = BuildPendingAttachmentResponse(message, messageAttachments);

        return new SupportMessageResponse(
            message.Id,
            message.ConversationId,
            message.SenderUserId,
            ResolveMessageSenderDisplayName(message.SenderType, sender?.Email, sender?.DisplayName, message.IsFromAdmin),
            message.IsFromAdmin,
            ResolveSenderDisplayType(message.SenderType, message.IsFromAdmin),
            message.Body ?? string.Empty,
            message.ReplyToMessageId,
            message.ReplyToPreview,
            ParseAttachmentUploadStatus(message.AttachmentUploadStatus)?.ToString(),
            message.AttachmentUploadErrorCode,
            pendingAttachment,
            messageAttachments,
            message.ReadAtUtc.HasValue,
            message.ReadAtUtc,
            message.DeliveredAtUtc,
            message.IsInternalNote,
            message.CreatedAtUtc,
            isIdempotencyReplay);
    }
}
