using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationWatermarkUnlock
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid GenerationJobId { get; set; }

    public Guid? UnlockedByUserId { get; set; }

    public TemplateWatermarkUnlockMethod UnlockMethod { get; set; }

    public int CreditsSpent { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public TemplateGenerationJob GenerationJob { get; set; } = null!;
}
