namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class RedeemCode
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string CodeHash { get; set; } = string.Empty;

    public string CodePrefix { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public string RewardKind { get; set; } = Domain.Enums.RedeemCodeRewardKind.Spark;

    public int RewardValue { get; set; }

    public int MaxRedemptions { get; set; }

    public int MaxRedemptionsPerUser { get; set; } = 1;

    public int RedeemedCount { get; set; }

    public bool IsActive { get; set; }

    public DateTime? StartsAtUtc { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
