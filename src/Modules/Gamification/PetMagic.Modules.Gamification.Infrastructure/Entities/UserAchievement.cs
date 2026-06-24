namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class UserAchievement
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string AchievementKey { get; set; } = string.Empty;
    public DateTime UnlockedAtUtc { get; set; }
    public bool RewardCredited { get; set; }
}
