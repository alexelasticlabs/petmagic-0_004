namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class Wallet
{
    public Guid UserId { get; set; }

    public int Balance { get; set; }

    public DateTime? LastWeeklyGrantAtUtc { get; set; }

    public DateTime? AdRewardWindowStartedAtUtc { get; set; }

    public int AdRewardsClaimedInWindow { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
