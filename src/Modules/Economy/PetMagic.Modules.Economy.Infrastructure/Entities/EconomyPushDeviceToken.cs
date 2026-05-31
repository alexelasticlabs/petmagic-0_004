namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class EconomyPushDeviceToken
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Token { get; set; } = string.Empty;

    public string Platform { get; set; } = "unknown";

    public string? DeviceId { get; set; }

    public string? AppVersion { get; set; }

    public string? Locale { get; set; }

    public DateTime LastSeenAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? DisabledAtUtc { get; set; }
}
