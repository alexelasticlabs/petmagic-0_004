namespace PetMagic.Modules.Templates.Infrastructure.Options;

public sealed class TemplatesOptions
{
    public const string SectionName = "Templates";

    public required string PublicBaseUrl { get; init; }

    public required string LocalMediaRootPath { get; init; }

    public required string DefaultPreprocessingPrompt { get; init; }

    public required string DefaultKlingPrompt { get; init; }

    public required string[] AllowedPreprocessingModels { get; init; }

    public required string[] AllowedKlingModels { get; init; }

    public long PreviewMaxFileSizeBytes { get; init; } = 25 * 1024 * 1024;

    public long ReferenceMotionMaxFileSizeBytes { get; init; } = 100 * 1024 * 1024;

    public bool SeedSampleTemplates { get; init; } = true;
}
