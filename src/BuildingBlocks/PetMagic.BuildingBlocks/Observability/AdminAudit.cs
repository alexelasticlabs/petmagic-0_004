namespace PetMagic.BuildingBlocks.Observability;

public sealed record AdminAuditEntry(
    string Action,
    string TargetType,
    string TargetId,
    string? OldValue = null,
    string? NewValue = null,
    string? Details = null,
    Guid? SubjectUserId = null,
    Guid? EventId = null,
    Guid? ActorUserId = null,
    string? CorrelationId = null)
{
    public string? ActorRole { get; init; }

    public string? IpAddress { get; init; }

    public string? UserAgent { get; init; }

    public DateTime? OccurredAtUtc { get; init; }
}

public interface IAdminAuditLog
{
    Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken);
}
