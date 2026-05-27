namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportChatPushOptions
{
    public bool Enabled { get; init; }

    public string ProjectId { get; init; } = string.Empty;

    public string ServiceAccountJson { get; init; } = string.Empty;

    public string ServiceAccountJsonPath { get; init; } = string.Empty;

    public bool IsConfigured => Enabled
        && !string.IsNullOrWhiteSpace(ProjectId)
        && (!string.IsNullOrWhiteSpace(ServiceAccountJson) || !string.IsNullOrWhiteSpace(ServiceAccountJsonPath));
}
