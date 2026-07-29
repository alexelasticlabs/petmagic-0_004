namespace PetMagic.Modules.Templates.Domain.Enums;

public enum TemplateGenerationProviderAttemptState
{
    SubmitReserved = 1,
    Submitting = 2,
    ProviderQueued = 3,
    ProviderProcessing = 4,
    SubmissionUnknown = 5,
    Completed = 6,
    Failed = 7,
    Cancelled = 8
}
