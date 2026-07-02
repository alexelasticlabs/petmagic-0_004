namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class EconomyIncident
{
    public Guid Id { get; set; }

    public string Type { get; set; } = string.Empty;

    public string Severity { get; set; } = "Warning";

    public string Status { get; set; } = "Open";

    public string DeduplicationKey { get; set; } = string.Empty;

    public Guid? UserId { get; set; }

    public Guid? PurchaseOrderId { get; set; }

    public Guid? UserSubscriptionId { get; set; }

    public string? Provider { get; set; }

    public string? ExternalReferenceId { get; set; }

    public string Summary { get; set; } = string.Empty;

    public string? DetailsJson { get; set; }

    public int DetectionCount { get; set; }

    public int RetryCount { get; set; }

    public DateTime FirstDetectedAtUtc { get; set; }

    public DateTime LastDetectedAtUtc { get; set; }

    public DateTime? NextRetryAtUtc { get; set; }

    public DateTime? ResolvedAtUtc { get; set; }

    public string? ResolutionNote { get; set; }

    public bool AutoFixApplied { get; set; }

    public string? LastError { get; set; }
}
