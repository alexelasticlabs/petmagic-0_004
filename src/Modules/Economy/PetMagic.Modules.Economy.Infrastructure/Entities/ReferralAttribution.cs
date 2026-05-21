namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class ReferralAttribution
{
    public Guid Id { get; set; }

    public Guid ReferrerUserId { get; set; }

    public Guid RefereeUserId { get; set; }

    public string ReferrerCode { get; set; } = string.Empty;

    public string Status { get; set; } = ReferralAttributionStatus.Pending;

    public int RewardSpark { get; set; }

    public Guid? ReferrerLedgerEntryId { get; set; }

    public Guid? RefereeLedgerEntryId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? QualifiedAtUtc { get; set; }
}

public static class ReferralAttributionStatus
{
    public const string Pending = "pending";

    public const string Rewarded = "rewarded";
}
