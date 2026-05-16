namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AuditEvent
{
    public Guid Id { get; set; }

    public Guid? SubjectUserId { get; set; }

    public string Action { get; set; } = string.Empty;

    public string Details { get; set; } = string.Empty;

    public DateTime OccurredAtUtc { get; set; }
}
