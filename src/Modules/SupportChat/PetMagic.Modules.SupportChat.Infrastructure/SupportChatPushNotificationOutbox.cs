using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportChatPushNotificationOutbox(
    SupportChatDbContext dbContext,
    SupportChatPushOptions options) : ISupportChatPushNotificationSender
{
    internal const string UserMessageKind = "user_message";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task NotifyUserAsync(
        SupportChatPushNotification notification,
        CancellationToken cancellationToken)
    {
        if (!options.IsConfigured)
        {
            return;
        }

        var deduplicationKey = $"support_chat:{notification.ConversationId:D}:{notification.MessageId:D}";
        if (dbContext.PushOutboxMessages.Local.Any(x => x.DeduplicationKey == deduplicationKey)
            || await dbContext.PushOutboxMessages.AsNoTracking().AnyAsync(
                x => x.DeduplicationKey == deduplicationKey,
                cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = deduplicationKey,
            Kind = UserMessageKind,
            UserId = notification.UserId,
            PayloadJson = JsonSerializer.Serialize(notification, JsonOptions),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
    }
}
