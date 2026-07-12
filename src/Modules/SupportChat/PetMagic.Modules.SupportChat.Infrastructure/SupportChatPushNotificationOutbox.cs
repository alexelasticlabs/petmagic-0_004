using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal sealed class SupportChatPushNotificationOutbox(
    SupportChatDbContext dbContext,
    SupportChatPushOptions options) : ISupportChatPushNotificationSender
{
    internal const string UserMessageKind = "user_message";
    internal const string AdminAuditKind = "admin_audit";
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

    internal static void EnqueueAdminAudit(
        SupportChatDbContext dbContext,
        AdminAuditEntry entry)
    {
        var eventId = entry.EventId
            ?? throw new InvalidOperationException("Durable admin audit entries require an event id.");
        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"support_admin_audit:{eventId:D}",
            Kind = AdminAuditKind,
            UserId = entry.SubjectUserId ?? Guid.Empty,
            PayloadJson = JsonSerializer.Serialize(entry, JsonOptions),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
    }
}
