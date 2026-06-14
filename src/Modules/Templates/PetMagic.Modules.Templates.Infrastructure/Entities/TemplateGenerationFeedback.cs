namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationFeedback
{
    public Guid Id { get; set; }

    public Guid? UserId { get; set; }

    public string Type { get; set; } = "GenerationResult";

    public string Category { get; set; } = string.Empty;

    public int? Rating { get; set; }

    public string? Message { get; set; }

    public Guid? GenerationId { get; set; }

    public Guid? TemplateId { get; set; }

    public Guid? PetId { get; set; }

    public string SourceScreen { get; set; } = string.Empty;

    public string? AppVersion { get; set; }

    public string? Platform { get; set; }

    public string? DeviceModel { get; set; }

    public string? Locale { get; set; }

    public string? ErrorCode { get; set; }

    public string? ProviderName { get; set; }

    public string Status { get; set; } = "New";

    public string Priority { get; set; } = "Low";

    public string SelectedReasons { get; set; } = string.Empty;

    public string? Comment { get; set; }

    public double? InputPhotoQualityScore { get; set; }

    public string? ModelUsed { get; set; }

    public double? GenerationDurationSeconds { get; set; }

    public string? ProviderRequestId { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? ReviewedAtUtc { get; set; }

    public Guid? ReviewedByAdminId { get; set; }

    public string? AdminNote { get; set; }

    public TemplateGenerationJob? Generation { get; set; }

    public TemplateItem? Template { get; set; }
}
