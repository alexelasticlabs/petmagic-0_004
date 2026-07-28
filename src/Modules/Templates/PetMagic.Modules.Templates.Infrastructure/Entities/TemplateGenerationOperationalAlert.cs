namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationOperationalAlert
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string Severity { get; set; } = "warning";

    public string Title { get; set; } = string.Empty;

    public string Message { get; set; } = string.Empty;

    public DateTime ActivatedAtUtc { get; set; }

    public DateTime LastObservedAtUtc { get; set; }

    public DateTime? ResolvedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public ICollection<TemplateGenerationOperationalAlertAcknowledgement> Acknowledgements { get; set; } = [];
}

public sealed class TemplateGenerationOperationalAlertAcknowledgement
{
    public Guid AlertId { get; set; }

    public Guid AdminUserId { get; set; }

    public DateTime AlertActivatedAtUtc { get; set; }

    public DateTime AcknowledgedAtUtc { get; set; }

    public TemplateGenerationOperationalAlert Alert { get; set; } = null!;
}
