using System.Security.Claims;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.SignalR;

namespace PetMagic.Modules.SupportChat.Api.Realtime;

public sealed class SupportChatUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection)
    {
        var rawUserId = connection.User?.FindFirstValue("sub")
            ?? connection.User?.FindFirstValue(ClaimTypes.NameIdentifier);

        return Guid.TryParse(rawUserId, out var userId) ? userId.ToString("D") : null;
    }
}
