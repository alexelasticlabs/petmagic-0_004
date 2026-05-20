using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace PetMagic.Modules.SupportChat.Api.Realtime;

[Authorize]
public sealed class SupportChatHub : Hub
{
    public const string RoutePattern = "/hubs/support-chat";
    public const string AdminInboxGroup = "support:admins";
    public const string ConversationUpdatedEvent = "conversation-updated";

    public override async Task OnConnectedAsync()
    {
        var userId = ResolveUserId(Context.User);
        if (userId.HasValue)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, UserGroup(userId.Value));
        }

        if (Context.User?.IsInRole("Admin") == true || Context.User?.IsInRole("Moderator") == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, AdminInboxGroup);
        }

        await base.OnConnectedAsync();
    }

    public static string UserGroup(Guid userId) => $"support:user:{userId:D}";

    private static Guid? ResolveUserId(ClaimsPrincipal? user)
    {
        var rawUserId = user?.FindFirstValue("sub") ?? user?.FindFirstValue(ClaimTypes.NameIdentifier);
        return Guid.TryParse(rawUserId, out var userId) ? userId : null;
    }
}