namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateOfTheDay
{
    public Guid Id { get; set; }

    public Guid TemplateId { get; set; }

    public TemplateItem Template { get; set; } = null!;

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public bool IsActive { get; set; }

    public bool IsManual { get; set; }

    public int Priority { get; set; }

    public string? TitleOverride { get; set; }

    public string? SubtitleOverride { get; set; }

    public string? BadgeTextOverride { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public Guid? CreatedByAdminId { get; set; }
}
