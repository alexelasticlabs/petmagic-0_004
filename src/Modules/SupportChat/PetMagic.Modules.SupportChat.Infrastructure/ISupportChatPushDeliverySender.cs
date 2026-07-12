using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal interface ISupportChatPushDeliverySender
{
    Task<PushDeliveryResult> DeliverUserAsync(
        SupportChatPushNotification notification,
        CancellationToken cancellationToken);
}
