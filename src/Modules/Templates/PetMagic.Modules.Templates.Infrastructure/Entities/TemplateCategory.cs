namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateCategory
{
    public Guid Id { get; set; }

    public string Name { get; set; } = string.Empty;

    public string NormalizedName { get; set; } = string.Empty;

    public bool IsArchived { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
