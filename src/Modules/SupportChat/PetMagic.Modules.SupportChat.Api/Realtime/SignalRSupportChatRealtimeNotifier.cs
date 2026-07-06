using Microsoft.AspNetCore.SignalR;

using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Api.Realtime;

public sealed class SignalRSupportChatRealtimeNotifier(IHubContext<SupportChatHub> hubContext) : ISupportChatRealtimeNotifier
{
    public Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken)
    {
        var adminPayload = new
        {
            conversationId = notification.ConversationId,
            initiatorUserId = notification.InitiatorUserId,
            updatedAtUtc = notification.UpdatedAtUtc,
            lastMessageAtUtc = notification.LastMessageAtUtc,
            lastMessageSenderType = notification.LastMessageSenderType,
            adminUnreadCount = notification.AdminUnreadCount,
        };

        var userPayload = new
        {
            conversationId = notification.ConversationId,
            updatedAtUtc = notification.UpdatedAtUtc,
            lastMessageAtUtc = notification.LastMessageAtUtc,
            lastMessageSenderType = notification.LastMessageSenderType,
            userUnreadCount = notification.UserUnreadCount,
        };

        return Task.WhenAll(
            hubContext.Clients.Group(SupportChatHub.AdminInboxGroup)
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, adminPayload, cancellationToken),
            hubContext.Clients.Group(SupportChatHub.UserGroup(notification.InitiatorUserId))
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, userPayload, cancellationToken));
    }
}
