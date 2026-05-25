namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationFeedback
{
    public Guid Id { get; set; }

    public Guid GenerationId { get; set; }

    public Guid UserId { get; set; }

    public Guid TemplateId { get; set; }

    public int Rating { get; set; }

    public string SelectedReasons { get; set; } = string.Empty;

    public string? Comment { get; set; }

    public double? InputPhotoQualityScore { get; set; }

    public string? ModelUsed { get; set; }

    public double? GenerationDurationSeconds { get; set; }

    public string? ProviderRequestId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public TemplateGenerationJob Generation { get; set; } = null!;

    public TemplateItem Template { get; set; } = null!;
}
