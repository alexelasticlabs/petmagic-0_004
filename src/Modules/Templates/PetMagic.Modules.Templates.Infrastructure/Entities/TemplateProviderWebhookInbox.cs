using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateProviderWebhookInbox
{
    public Guid Id { get; set; }

    public Guid? ProviderAttemptId { get; set; }

    public Guid? GenerationJobId { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string DeduplicationKey { get; set; } = string.Empty;

    public string? CallbackTokenHash { get; set; }

    public string? ProviderRequestId { get; set; }

    public string EventType { get; set; } = string.Empty;

    public string PayloadJson { get; set; } = "{}";

    public TemplateProviderWebhookInboxStatus Status { get; set; }

    public DateTime SignatureVerifiedAtUtc { get; set; }

    public DateTime ReceivedAtUtc { get; set; }

    public DateTime NextAttemptAtUtc { get; set; }

    public int AttemptCount { get; set; }

    public int FailureCount { get; set; }

    public string? LockedBy { get; set; }

    public DateTime? LockedAtUtc { get; set; }

    public DateTime? ProcessedAtUtc { get; set; }

    public DateTime? DeadLetteredAtUtc { get; set; }

    public string? LastErrorCode { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public TemplateGenerationProviderAttempt? ProviderAttempt { get; set; }

    public TemplateGenerationJob? GenerationJob { get; set; }
}
