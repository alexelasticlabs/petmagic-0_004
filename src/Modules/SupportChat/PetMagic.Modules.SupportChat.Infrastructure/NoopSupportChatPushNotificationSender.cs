using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class NoopSupportChatPushNotificationSender : ISupportChatPushNotificationSender
{
    public Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}
