using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateItem
{
    public Guid Id { get; set; }

    public TemplateType TemplateType { get; set; }

    public string Title { get; set; } = string.Empty;

    public string ShortDescription { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public string Tags { get; set; } = string.Empty;

    public bool IsPremium { get; set; }

    public int TokenCost { get; set; }

    public TemplateStatus Status { get; set; }

    public TemplatePromoBadgeMode PromoBadgeMode { get; set; } = TemplatePromoBadgeMode.Auto;

    public string? MusicDescription { get; set; }

    public double? ReferenceVideoDurationSeconds { get; set; }

    public CharacterOrientation? CharacterOrientation { get; set; }

    public string? PreprocessingModel { get; set; }

    public string? PreprocessingPrompt { get; set; }

    public string? KlingModel { get; set; }

    public string? KlingPrompt { get; set; }

    public bool? KeepOriginalSound { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public List<TemplateAsset> Assets { get; set; } = [];
}
