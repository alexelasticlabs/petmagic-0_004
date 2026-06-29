namespace PetMagic.Modules.Templates.Domain.Enums;

public enum TemplateGenerationStatus
{
    Queued = 1,
    Processing = 2,
    Completed = 3,
    Failed = 4,
    Cancelled = 5,
    Retrying = 6
}
