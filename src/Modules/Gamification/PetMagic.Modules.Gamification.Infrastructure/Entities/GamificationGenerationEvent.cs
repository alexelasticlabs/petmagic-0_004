namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class GamificationGenerationEvent
{
    public Guid GenerationId { get; set; }

    public Guid UserId { get; set; }

    public Guid PetId { get; set; }

    public Guid TemplateId { get; set; }

    public DateOnly WeekStartDate { get; set; }

    public DateTime OccurredAtUtc { get; set; }

    public DateTime ProcessedAtUtc { get; set; }
}
