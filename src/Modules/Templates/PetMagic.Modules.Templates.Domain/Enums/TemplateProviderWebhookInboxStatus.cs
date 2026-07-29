namespace PetMagic.Modules.Templates.Domain.Enums;

public enum TemplateProviderWebhookInboxStatus
{
    Queued = 1,
    Processing = 2,
    Processed = 3,
    Failed = 4,
    DeadLettered = 5
}
