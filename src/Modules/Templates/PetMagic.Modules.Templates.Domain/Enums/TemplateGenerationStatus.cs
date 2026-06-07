namespace PetMagic.Modules.Templates.Domain.Enums;

public enum TemplateGenerationStatus
{
    Queued = 1,
    Processing = 2,
    Succeeded = 3,
    Completed = Succeeded,
    Failed = 4,
    Cancelled = 5,
    Retrying = 6
}
