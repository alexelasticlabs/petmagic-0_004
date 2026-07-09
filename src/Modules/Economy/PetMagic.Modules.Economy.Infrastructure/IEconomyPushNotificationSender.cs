using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.BuildingBlocks.Notifications;

namespace PetMagic.Modules.Economy.Infrastructure;

public interface IEconomyPushNotificationSender
{
    Task NotifyWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken);

    Task NotifyPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken);
}

internal interface IEconomyPushDeliverySender
{
    Task<PushDeliveryResult> DeliverWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken);

    Task<PushDeliveryResult> DeliverPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken);
}

public sealed record WalletPushNotification(
    string Status,
    Guid? OrderId = null,
    int? SparkDelta = null);

public sealed record PremiumPushNotification(
    string Status,
    string? Provider = null,
    string? PlanCode = null);
