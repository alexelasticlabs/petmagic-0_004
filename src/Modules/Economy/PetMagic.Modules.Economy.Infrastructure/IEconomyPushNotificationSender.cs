using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Infrastructure;

public interface IEconomyPushNotificationSender
{
    Task NotifyWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken);

    Task NotifyPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken);
}

public sealed record WalletPushNotification(
    string Status,
    string? Title = null,
    string? Body = null,
    Guid? OrderId = null,
    int? SparkDelta = null);

public sealed record PremiumPushNotification(
    string Status,
    string? Title = null,
    string? Body = null,
    string? Provider = null,
    string? PlanCode = null);
