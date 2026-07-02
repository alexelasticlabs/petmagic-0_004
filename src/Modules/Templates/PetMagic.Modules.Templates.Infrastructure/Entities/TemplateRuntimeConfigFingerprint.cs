namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateRuntimeConfigFingerprint
{
    public Guid Id { get; set; }

    public string Component { get; set; } = string.Empty;

    public string ProfileName { get; set; } = string.Empty;

    public string Checksum { get; set; } = string.Empty;

    public string ConfigJson { get; set; } = "{}";

    public DateTime StartedAtUtc { get; set; }

    public DateTime LastSeenAtUtc { get; set; }

    public bool MismatchDetected { get; set; }

    public string? MismatchDetails { get; set; }
}
