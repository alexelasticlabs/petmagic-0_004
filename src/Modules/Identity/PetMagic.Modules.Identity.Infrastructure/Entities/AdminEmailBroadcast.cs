using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class AdminEmailBroadcast
{
    public Guid Id { get; set; }

    public Guid? ActorUserId { get; set; }

    public string Audience { get; set; } = string.Empty;

    public string? Subject { get; set; }

    public string RequestHash { get; set; } = string.Empty;

    public AdminEmailBroadcastStatus Status { get; set; }

    public int RecipientCount { get; set; }

    public int SentCount { get; set; }

    public int FailedCount { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public ICollection<EmailDispatchJob> DispatchJobs { get; set; } = [];
}
