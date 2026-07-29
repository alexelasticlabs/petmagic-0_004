namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AdminNotificationEvent
{
    public Guid Id { get; set; }

    public string Type { get; set; } = string.Empty;

    public int SchemaVersion { get; set; }

    public string PayloadJson { get; set; } = "{}";

    public string Category { get; set; } = string.Empty;

    public string Priority { get; set; } = string.Empty;

    public string AudienceRoles { get; set; } = string.Empty;

    public Guid? TargetUserId { get; set; }

    public string? Href { get; set; }

    public string Source { get; set; } = string.Empty;

    public string DeduplicationKey { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }

    public Guid? AcknowledgedByUserId { get; set; }

    public DateTime? AcknowledgedAtUtc { get; set; }

    public string? AcknowledgementReason { get; set; }

    public int Version { get; set; }

    public ICollection<AdminNotificationReceipt> Receipts { get; set; } = [];
}
