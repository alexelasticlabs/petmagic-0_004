namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class EconomyIncidentAuditEntry
{
    public Guid Id { get; set; }

    public Guid IncidentId { get; set; }

    public string Action { get; set; } = string.Empty;

    public string Reason { get; set; } = string.Empty;

    public string? OldStatus { get; set; }

    public string? NewStatus { get; set; }

    public string? DetailsJson { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
