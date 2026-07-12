namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class DailyStreak
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public int CurrentStreak { get; set; }
    public int LongestStreak { get; set; }
    public DateOnly LastActiveDate { get; set; }
    public int StreakFreezesAvailable { get; set; } = 1;
    public int WeeklyFreezeAllowance { get; set; } = 1;
    public DateOnly? StreakFreezeUsedAt { get; set; }
    public DateOnly? FreezesResetAt { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}
