using Microsoft.AspNetCore.SignalR;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Api.Realtime;

public sealed class SignalRSupportChatRealtimeNotifier(
    IHubContext<SupportChatHub> hubContext,
    IIdentityUserLookupService identityUserLookupService) : ISupportChatRealtimeNotifier
{
    public async Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken)
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

        // Do not fan out sensitive inbox data to the persistent operator group:
        // an already-open SignalR connection can retain stale JWT role claims.
        // Resolve the active operator audience at send time instead.
        var activeOperatorUserIds = await identityUserLookupService.GetActiveUserIdsInRolesAsync(
            SupportChatHub.OperatorRoles,
            cancellationToken);
        var operatorUserIds = activeOperatorUserIds
            .Select(userId => userId.ToString("D"))
            .ToArray();

        await Task.WhenAll(
            hubContext.Clients.Users(operatorUserIds)
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, adminPayload, cancellationToken),
            hubContext.Clients.Group(SupportChatHub.UserGroup(notification.InitiatorUserId))
                .SendAsync(SupportChatHub.ConversationUpdatedEvent, userPayload, cancellationToken));
    }
}
