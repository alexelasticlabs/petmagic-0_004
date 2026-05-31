namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class NoopEconomyPushNotificationSender : IEconomyPushNotificationSender
{
    public Task NotifyWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }

    public Task NotifyPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
