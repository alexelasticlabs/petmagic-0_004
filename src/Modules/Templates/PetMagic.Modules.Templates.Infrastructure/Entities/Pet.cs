namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class Pet
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Name { get; set; } = string.Empty;

    public string Type { get; set; } = "other";

    public string? Breed { get; set; }

    public Guid? AvatarMediaAssetId { get; set; }

    public string Status { get; set; } = "active";

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public List<PetPhoto> Photos { get; set; } = [];
}
