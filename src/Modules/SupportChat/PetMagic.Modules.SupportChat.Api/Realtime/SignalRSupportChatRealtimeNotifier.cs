using Microsoft.AspNetCore.SignalR;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Api.Realtime;

public sealed class SignalRSupportChatRealtimeNotifier(IHubContext<SupportChatHub> hubContext) : ISupportChatRealtimeNotifier
{
    public Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken)
    {
        var payload = new
        {
            conversationId = notification.ConversationId,
            initiatorUserId = notification.InitiatorUserId,
            updatedAtUtc = notification.UpdatedAtUtc,
        };

        return Task.WhenAll(
            hubContext.Clients.Group(SupportChatHub.AdminInboxGroup)
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, payload, cancellationToken),
            hubContext.Clients.Group(SupportChatHub.UserGroup(notification.InitiatorUserId))
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, payload, cancellationToken));
    }
}