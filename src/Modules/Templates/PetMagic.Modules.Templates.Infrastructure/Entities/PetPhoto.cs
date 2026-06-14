namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class PetPhoto
{
    public Guid Id { get; set; }

    public Guid PetId { get; set; }

    public Guid UserId { get; set; }

    public Guid MediaAssetId { get; set; }

    public string? ThumbnailUrl { get; set; }

    public string? ThumbnailStoragePath { get; set; }

    public bool IsFavorite { get; set; }

    public bool IsAvatar { get; set; }

    public int SortOrder { get; set; }

    public string Status { get; set; } = "active";

    public DateTime CreatedAtUtc { get; set; }

    public bool IsDeleted { get; set; }

    public DateTime? DeletedAtUtc { get; set; }

    public Pet Pet { get; set; } = null!;

    public TemplateMediaRecord MediaAsset { get; set; } = null!;
}
