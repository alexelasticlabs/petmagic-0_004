using System.Text.Json;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Gamification.Infrastructure.Data;

namespace PetMagic.Modules.Gamification.Infrastructure;

internal static class GamificationAdminAuditOutbox
{
    internal const string AdminAuditKind = "admin_audit";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    internal static void Enqueue(
        GamificationDbContext dbContext,
        AdminAuditEntry entry)
    {
        var eventId = entry.EventId
            ?? throw new InvalidOperationException("Durable admin audit entries require an event id.");
        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"gamification_admin_audit:{eventId:D}",
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
