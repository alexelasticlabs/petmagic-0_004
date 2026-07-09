using Microsoft.Extensions.Logging;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
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
                "Support chat notification fan-out failed. Operation={Operation} Channel={Channel} ConversationIdHash={ConversationIdHash} InitiatorUserIdHash={InitiatorUserIdHash} ExceptionType={ExceptionType}",
                "conversation_update",
                "realtime",
                SafeLogValues.StableHash(conversation.Id.ToString("D")),
                SafeLogValues.StableHash(conversation.InitiatorUserId.ToString("D")),
                SafeLogValues.ExceptionType(exception));
            // Realtime fan-out is best-effort and must not break the primary support flow.
        }
    }

    private async Task EnqueueUserMessageNotificationAsync(
        SupportConversation conversation,
        Guid messageId,
        bool hasAttachments,
        int unreadCountDelta,
        CancellationToken cancellationToken)
    {
        var persistedUnreadCount = await supportChatDbContext.ConversationMessages.CountAsync(
            x => x.ConversationId == conversation.Id && x.IsFromAdmin && x.ReadAtUtc == null,
            cancellationToken);
        await pushNotificationSender.NotifyUserAsync(
            new SupportChatPushNotification(
                conversation.Id,
                conversation.InitiatorUserId,
                messageId,
                hasAttachments,
                persistedUnreadCount + unreadCountDelta),
            cancellationToken);
    }
}
