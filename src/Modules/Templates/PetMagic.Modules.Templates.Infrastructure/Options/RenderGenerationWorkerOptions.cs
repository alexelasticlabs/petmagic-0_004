namespace PetMagic.Modules.Templates.Infrastructure.Options;

internal sealed class RenderGenerationWorkerOptions
{
    public const string SectionName = "RenderGenerationWorker";
    public const int DefaultMinimumInstances = 1;
    public const int DefaultMaximumInstances = 8;

    public string ApiKey { get; init; } = string.Empty;

    public string ServiceId { get; init; } = string.Empty;

    public string ExpectedOwnerId { get; init; } = string.Empty;

    public string ExpectedServiceName { get; init; } = string.Empty;

    public string ExpectedServiceType { get; init; } = "background_worker";

    public string ExpectedRepository { get; init; } = string.Empty;

    public int MinimumInstances { get; init; } = DefaultMinimumInstances;

    public int MaximumInstances { get; init; } = DefaultMaximumInstances;

    public bool IsConfigured => MissingConfigurationFields.Count == 0;

    public IReadOnlyList<string> MissingConfigurationFields
    {
        get
        {
            var missing = new List<string>();
            AddIfMissing(missing, ApiKey, "api_key");
            AddIfMissing(missing, ServiceId, "service_id");
            AddIfMissing(missing, ExpectedOwnerId, "expected_owner_id");
            AddIfMissing(missing, ExpectedServiceName, "expected_service_name");
            AddIfMissing(missing, ExpectedServiceType, "expected_service_type");
            AddIfMissing(missing, ExpectedRepository, "expected_repository");
            return missing;
        }
    }

    private static void AddIfMissing(ICollection<string> target, string value, string name)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            target.Add(name);
        }
    }
}
