using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace PetMagic.Modules.Identity.Api.Realtime;

[Authorize(Policy = "ModeratorOrAdmin")]
public sealed class AdminNotificationsHub : Hub
{
    public const string RoutePattern = "/hubs/admin-notifications";
    public const string NotificationsChangedEvent = "notifications-changed";
}
