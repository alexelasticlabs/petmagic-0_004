using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private async Task NotifyConversationUpdatedAsync(SupportConversation conversation, CancellationToken cancellationToken)
    {
        try
        {
            var snapshot = await supportChatDbContext.SupportConversations
                .AsNoTracking()
                .Where(x => x.Id == conversation.Id)
                .Select(x => new
                {
                    x.Id,
                    x.InitiatorUserId,
                    x.UpdatedAtUtc,
                    x.LastMessagePreview,
                    x.LastMessageAtUtc,
                    x.LastMessageSenderType,
                    AdminUnreadCount = x.Messages.Count(message => !message.IsFromAdmin && message.ReadAtUtc == null),
                    UserUnreadCount = x.Messages.Count(message => message.IsFromAdmin && message.ReadAtUtc == null)
                })
                .FirstOrDefaultAsync(cancellationToken);

            if (snapshot is null)
            {
                return;
            }

            await realtimeNotifier.NotifyConversationUpdatedAsync(
                new SupportConversationRealtimeEvent(
                    snapshot.Id,
                    snapshot.InitiatorUserId,
                    snapshot.UpdatedAtUtc,
                    snapshot.LastMessagePreview,
                    snapshot.LastMessageAtUtc,
                    snapshot.LastMessageSenderType?.ToString(),
                    snapshot.AdminUnreadCount,
                    snapshot.UserUnreadCount),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Realtime fan-out is best-effort and must not break the primary support flow.
        }
    }

    private async Task NotifyUserMessageAsync(
        SupportConversation conversation,
        SupportMessageResponse message,
        CancellationToken cancellationToken)
    {
        try
        {
            await pushNotificationSender.NotifyUserAsync(
                new SupportChatPushNotification(
                    conversation.Id,
                    conversation.InitiatorUserId,
                    message.MessageId,
                    message.SenderDisplayName,
                    message.Body,
                    message.Attachments.Count > 0 || message.PendingAttachment is not null,
                    await supportChatDbContext.ConversationMessages.CountAsync(
                        x => x.ConversationId == conversation.Id && x.IsFromAdmin && x.ReadAtUtc == null,
                        cancellationToken)),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception)
        {
            // Push delivery is best-effort and must not block support replies.
        }
    }

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
                message.Body,
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
            messages);
    }

    private async Task<SupportMessageResponse> BuildMessageResponseAsync(ConversationMessage message, CancellationToken cancellationToken)
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
            message.Body,
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
            message.CreatedAtUtc);
    }

    private async Task<Result<ResolvedReplyTarget?>> ResolveReplyTargetAsync(
        Guid conversationId,
        Guid? replyToMessageId,
        CancellationToken cancellationToken)
    {
        if (!replyToMessageId.HasValue)
        {
            return Result.Success<ResolvedReplyTarget?>(null);
        }

        var sourceMessage = await supportChatDbContext.ConversationMessages
            .AsNoTracking()
            .Include(message => message.Attachments)
            .FirstOrDefaultAsync(
                message => message.Id == replyToMessageId.Value && message.ConversationId == conversationId,
                cancellationToken);
        if (sourceMessage is null)
        {
            return Result.Failure<ResolvedReplyTarget?>(MessageNotFound);
        }

        return Result.Success<ResolvedReplyTarget?>(
            new ResolvedReplyTarget(
                sourceMessage.Id,
                BuildReplyPreview(sourceMessage)));
    }

    private static string BuildReplyPreview(ConversationMessage sourceMessage)
    {
        var trimmedBody = sourceMessage.Body.Trim();
        var orderedAttachments = sourceMessage.Attachments
            .OrderBy(attachment => attachment.SortOrder)
            .ToList();
        if (orderedAttachments.Count > 0)
        {
            if (!string.IsNullOrWhiteSpace(trimmedBody)
                && !orderedAttachments.Any(attachment => string.Equals(
                    attachment.FileName.Trim(),
                    trimmedBody,
                    StringComparison.OrdinalIgnoreCase)))
            {
                return Truncate(trimmedBody, 160) ?? trimmedBody;
            }

            if (orderedAttachments.Count > 1)
            {
                return $"Attachments ({orderedAttachments.Count})";
            }

            var attachment = orderedAttachments[0];
            if (attachment.IsDeleted)
            {
                return "Attachment deleted";
            }

            if (attachment.MimeType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
            {
                return "Photo";
            }

            if (attachment.MimeType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
            {
                return "Video";
            }

            return string.IsNullOrWhiteSpace(attachment.FileName) ? "Attachment" : attachment.FileName;
        }

        if (!string.IsNullOrWhiteSpace(trimmedBody))
        {
            return Truncate(trimmedBody, 160) ?? trimmedBody;
        }

        if (!string.IsNullOrWhiteSpace(sourceMessage.AttachmentFileName))
        {
            return sourceMessage.AttachmentFileName;
        }

        return "Message";
    }

    private sealed record ResolvedReplyTarget(Guid MessageId, string Preview);
}
