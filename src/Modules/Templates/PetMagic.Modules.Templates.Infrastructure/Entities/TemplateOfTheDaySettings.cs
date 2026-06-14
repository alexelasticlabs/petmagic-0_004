namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateOfTheDaySettings
{
    public Guid Id { get; set; }

    public bool AutoModeEnabled { get; set; }

    public string AllowedTypes { get; set; } = "both";

    public int ExcludeRecentDays { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public Guid? UpdatedByAdminId { get; set; }
}
