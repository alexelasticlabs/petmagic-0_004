namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class AchievementDefinition
{
    public Guid Id { get; set; }
    public string Key { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Rarity { get; set; } = "common";
    public string TitleKey { get; set; } = string.Empty;
    public string DescriptionKey { get; set; } = string.Empty;
    public string? IconEmoji { get; set; }
    public string RequirementType { get; set; } = string.Empty;
    public int RequirementValue { get; set; }
    public int RewardSpark { get; set; }
    public bool IsSecret { get; set; }
    public int SortOrder { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}
