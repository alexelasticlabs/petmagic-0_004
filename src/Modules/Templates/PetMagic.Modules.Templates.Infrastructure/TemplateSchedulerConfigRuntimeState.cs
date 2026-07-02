namespace PetMagic.Modules.Templates.Infrastructure;

public sealed record TemplateSchedulerConfigComponent(string Value);

public sealed class TemplateSchedulerConfigRuntimeState
{
    private readonly object gate = new();
    private TemplateSchedulerConfigRuntimeSnapshot snapshot = TemplateSchedulerConfigRuntimeSnapshot.NotInitialized;

    public TemplateSchedulerConfigRuntimeSnapshot Snapshot
    {
        get
        {
            lock (gate)
            {
                return snapshot;
            }
        }
    }

    public void MarkHealthy(string component, string profileName, string checksum)
    {
        lock (gate)
        {
            snapshot = new TemplateSchedulerConfigRuntimeSnapshot(
                Initialized: true,
                Component: component,
                ProfileName: profileName,
                Checksum: checksum,
                IsMismatchDetected: false,
                MismatchDetails: null);
        }
    }

    public void MarkMismatch(string component, string profileName, string checksum, string details)
    {
        lock (gate)
        {
            snapshot = new TemplateSchedulerConfigRuntimeSnapshot(
                Initialized: true,
                Component: component,
                ProfileName: profileName,
                Checksum: checksum,
                IsMismatchDetected: true,
                MismatchDetails: details);
        }
    }
}

public sealed record TemplateSchedulerConfigRuntimeSnapshot(
    bool Initialized,
    string Component,
    string ProfileName,
    string Checksum,
    bool IsMismatchDetected,
    string? MismatchDetails)
{
    public static TemplateSchedulerConfigRuntimeSnapshot NotInitialized { get; } = new(
        Initialized: false,
        Component: string.Empty,
        ProfileName: string.Empty,
        Checksum: string.Empty,
        IsMismatchDetected: false,
        MismatchDetails: null);
}
