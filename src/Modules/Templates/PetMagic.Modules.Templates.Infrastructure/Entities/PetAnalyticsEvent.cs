namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class PetAnalyticsEvent
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid PetId { get; set; }

    public Guid? PetPhotoId { get; set; }

    public Guid? TemplateId { get; set; }

    public Guid? GenerationId { get; set; }

    public string EventType { get; set; } = string.Empty;

    public string PetType { get; set; } = "other";

    public int PhotosCount { get; set; }

    public string UserPlan { get; set; } = "unknown";

    public string SourceScreen { get; set; } = "unknown";

    public DateTime CreatedAtUtc { get; set; }
}
