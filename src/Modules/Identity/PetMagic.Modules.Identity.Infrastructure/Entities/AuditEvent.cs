namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AuditEvent
{
    public Guid Id { get; set; }

    public Guid? SubjectUserId { get; set; }

    public Guid? ActorUserId { get; set; }

    public string? ActorRole { get; set; }

    public string Action { get; set; } = string.Empty;

    public string? TargetType { get; set; }

    public string? TargetId { get; set; }

    public string? OldValue { get; set; }

    public string? NewValue { get; set; }

    public string? IpAddress { get; set; }

    public string? UserAgent { get; set; }

    public string? CorrelationId { get; set; }

    public string Details { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime OccurredAtUtc { get; set; }
}
