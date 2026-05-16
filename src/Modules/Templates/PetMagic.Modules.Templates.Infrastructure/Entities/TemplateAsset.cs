using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateAsset
{
    public Guid Id { get; set; }

    public Guid TemplateId { get; set; }

    public TemplateAssetKind AssetKind { get; set; }

    public string Url { get; set; } = string.Empty;

    public string FileName { get; set; } = string.Empty;

    public string ContentType { get; set; } = string.Empty;

    public long? FileSizeBytes { get; set; }

    public double? DurationSeconds { get; set; }

    public TemplateItem Template { get; set; } = null!;
}
