namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class SubscriptionEventLog
{
    public Guid Id { get; set; }

    public Guid? UserId { get; set; }

    public Guid? UserSubscriptionId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string EventType { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    public string? ExternalEventId { get; set; }

    public string? ExternalSubscriptionId { get; set; }

    public string? PayloadJson { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? ProcessedAtUtc { get; set; }
}
