namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class UserChallengeProgress
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid ChallengeId { get; set; }
    public int CurrentValue { get; set; }
    public bool Completed { get; set; }
    public DateTime? CompletedAtUtc { get; set; }
    public bool RewardCredited { get; set; }
}
