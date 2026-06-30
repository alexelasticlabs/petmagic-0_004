using Microsoft.Extensions.Logging;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private async Task NotifyConversationUpdatedAsync(
        SupportConversation conversation,
        CancellationToken cancellationToken)
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
        catch (Exception exception)
        {
            logger?.LogWarning(
                exception,
                "Support chat notification fan-out failed. Operation={Operation} Channel={Channel} ConversationId={ConversationId} InitiatorUserId={InitiatorUserId}",
                "conversation_update",
                "realtime",
                conversation.Id,
                conversation.InitiatorUserId);
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
        catch (Exception exception)
        {
            logger?.LogWarning(
                exception,
                "Support chat notification fan-out failed. Operation={Operation} Channel={Channel} ConversationId={ConversationId} InitiatorUserId={InitiatorUserId} MessageId={MessageId} SenderType={SenderType} HasAttachments={HasAttachments}",
                "message_delivery",
                "push",
                conversation.Id,
                conversation.InitiatorUserId,
                message.MessageId,
                message.SenderType,
                message.Attachments.Count > 0 || message.PendingAttachment is not null);
            // Push delivery is best-effort and must not block support replies.
        }
    }
}
