namespace PetMagic.Modules.Gamification.Infrastructure.Entities;

public sealed class PetProgress
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public Guid PetId { get; set; }
    public int Xp { get; set; }
    public int Level { get; set; } = 1;
    public string EvolutionStage { get; set; } = "egg";
    public int TotalGenerations { get; set; }
    public Guid? FavoriteTemplateId { get; set; }
    public DateTime? FirstGenerationAtUtc { get; set; }
    public DateTime? LastGenerationAtUtc { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime UpdatedAtUtc { get; set; }
}
