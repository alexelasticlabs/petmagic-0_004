namespace PetMagic.Modules.Templates.Domain.Enums;

public enum TemplateGenerationStatus
{
    Queued = 1,
    Processing = 2,
    Succeeded = 3,
    Completed = Succeeded,
    Failed = 4,
    Uploading = 5,
    Preprocessing = 6,
    Generating = 7,
    Finalizing = 8
}
