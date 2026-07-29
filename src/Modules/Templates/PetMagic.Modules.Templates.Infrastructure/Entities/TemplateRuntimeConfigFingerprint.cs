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

    public long? AppliedPolicyRevision { get; set; }

    public DateTime? LastProgressAtUtc { get; set; }

    public bool? GenerationSchedulerV2Enabled { get; set; }

    public int? GenerationDispatchConcurrency { get; set; }

    public int? ProviderReconciliationConcurrency { get; set; }

    public int? MediaImportConcurrency { get; set; }

    public int? GenerationMaintenanceConcurrency { get; set; }
}
