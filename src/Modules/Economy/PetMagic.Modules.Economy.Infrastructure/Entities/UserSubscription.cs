namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class UserSubscription
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string PurchaseChannel { get; set; } = string.Empty;

    public string Region { get; set; } = string.Empty;

    public string PlanId { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    public string? ExternalCustomerId { get; set; }

    public string? ExternalSubscriptionId { get; set; }

    public string? ExternalTransactionId { get; set; }

    public DateTime? CurrentPeriodStartUtc { get; set; }

    public DateTime? CurrentPeriodEndUtc { get; set; }

    public bool CancelAtPeriodEnd { get; set; }

    public int MonthlyTokenLimit { get; set; }

    public int MonthlyTokensGranted { get; set; }

    public DateTime? LastTokenGrantAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}