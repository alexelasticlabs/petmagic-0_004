using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IAdminNotificationService
{
    Task<Result<AdminNotificationsPageResponse>> ListAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        AdminNotificationsQuery query,
        CancellationToken cancellationToken);

    Task<Result<AdminNotificationItemResponse>> MarkReadAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken cancellationToken);

    Task<Result<int>> MarkAllReadAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        DateTime cutoffUtc,
        CancellationToken cancellationToken);

    Task<Result<AdminNotificationItemResponse>> ArchiveAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken cancellationToken);

    Task<AdminNotificationAcknowledgeResult> AcknowledgeAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        string reason,
        int expectedVersion,
        CancellationToken cancellationToken);
}

public interface IAdminNotificationRealtimeNotifier
{
    Task NotifyChangedAsync(
        IReadOnlyCollection<string> audienceRoles,
        Guid? targetUserId,
        CancellationToken cancellationToken);
}
