namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateAnalyticsEvent
{
    public Guid Id { get; set; }

    public Guid TemplateId { get; set; }

    public Guid? UserId { get; set; }

    public Guid? GenerationId { get; set; }

    public string EventType { get; set; } = string.Empty;

    public string Source { get; set; } = string.Empty;

    public string DeviceClass { get; set; } = string.Empty;

    public string CountryCode { get; set; } = string.Empty;

    public string? FeedbackMessage { get; set; }

    public string? MetadataJson { get; set; }

    public string ModerationStatus { get; set; } = "pending";

    public string? ModerationComment { get; set; }

    public DateTime? ModeratedAtUtc { get; set; }

    public Guid? ModerationLeaseOwnerUserId { get; set; }

    public DateTime? ModerationLeaseClaimedAtUtc { get; set; }

    public DateTime? ModerationLeaseExpiresAtUtc { get; set; }

    public long ModerationVersion { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public TemplateItem Template { get; set; } = null!;
}
