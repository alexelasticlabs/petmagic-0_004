namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class WeeklyChallenge
{
    public Guid Id { get; set; }
    public DateOnly WeekStartDate { get; set; }
    public string ChallengeType { get; set; } = string.Empty;
    public int TargetValue { get; set; }
    public string TitleKey { get; set; } = string.Empty;
    public string DescriptionKey { get; set; } = string.Empty;
    public int RewardSpark { get; set; }
    public string? IconEmoji { get; set; }
    public int SortOrder { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
