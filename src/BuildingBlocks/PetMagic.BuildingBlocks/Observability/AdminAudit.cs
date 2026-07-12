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
    string? CorrelationId = null);

public interface IAdminAuditLog
{
    Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken);
}
