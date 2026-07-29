using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Application.Abstractions;

namespace PetMagic.Modules.Identity.Api.Realtime;

internal sealed class SignalRAdminNotificationRealtimeNotifier(
    IHubContext<AdminNotificationsHub> hubContext,
    IServiceProvider serviceProvider) : IAdminNotificationRealtimeNotifier
{
    public async Task NotifyChangedAsync(
        IReadOnlyCollection<string> audienceRoles,
        Guid? targetUserId,
        CancellationToken cancellationToken)
    {
        // IdentityApiModule is also composed in isolated contract-test hosts. Resolve the
        // Infrastructure-owned audience lookup only when an event is actually published;
        // production still fails closed if the required RBAC resolver is not registered.
        var identityUserLookupService = serviceProvider.GetRequiredService<IIdentityUserLookupService>();
        var activeAudience = await identityUserLookupService.GetActiveUserIdsInRolesAsync(
            audienceRoles,
            cancellationToken);
        var userIds = activeAudience
            .Where(userId => !targetUserId.HasValue || userId == targetUserId.Value)
            .Select(userId => userId.ToString("D"))
            .ToArray();
        if (userIds.Length == 0)
        {
            return;
        }

        await hubContext.Clients.Users(userIds).SendAsync(
            AdminNotificationsHub.NotificationsChangedEvent,
            new { asOfUtc = DateTime.UtcNow },
            cancellationToken);
    }
}
