namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class GamificationShareEvent
{
    public Guid GenerationId { get; set; }

    public Guid UserId { get; set; }

    public DateOnly WeekStartDate { get; set; }

    public DateTime SharedAtUtc { get; set; }
}
