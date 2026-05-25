namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplatePushDeviceToken
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public required string Token { get; set; }

    public required string Platform { get; set; }

    public string? DeviceId { get; set; }

    public string? AppVersion { get; set; }

    public string? Locale { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime LastSeenAtUtc { get; set; }

    public DateTime? DisabledAtUtc { get; set; }
}
