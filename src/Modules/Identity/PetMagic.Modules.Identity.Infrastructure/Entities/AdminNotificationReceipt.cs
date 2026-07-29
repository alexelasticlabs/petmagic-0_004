namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AdminNotificationReceipt
{
    public Guid EventId { get; set; }

    public Guid UserId { get; set; }

    public DateTime? ReadAtUtc { get; set; }

    public DateTime? ArchivedAtUtc { get; set; }

    public AdminNotificationEvent Event { get; set; } = null!;
}
