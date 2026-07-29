using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationProviderAttempt
{
    public Guid Id { get; set; }

    public Guid GenerationJobId { get; set; }

    public TemplateGenerationProviderAttemptStage Stage { get; set; }

    public int Ordinal { get; set; }

    public TemplateGenerationProviderAttemptState State { get; set; }

    public bool IsBorrowedCapacity { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string SubmissionTokenHash { get; set; } = string.Empty;

    public string? ProviderRequestId { get; set; }

    public string? ProviderStatusUrl { get; set; }

    public string? ProviderResponseUrl { get; set; }

    public string? ProviderCancelUrl { get; set; }

    public DateTime? NextPollAtUtc { get; set; }

    public DateTime SubmissionDeadlineAtUtc { get; set; }

    public DateTime ProcessingDeadlineAtUtc { get; set; }

    public DateTime ReconciliationDeadlineAtUtc { get; set; }

    public int SubmitAttemptCount { get; set; }

    public int PollAttemptCount { get; set; }

    public int CancelAttemptCount { get; set; }

    public string? LastErrorCode { get; set; }

    public string? LockedBy { get; set; }

    public DateTime? LockedAtUtc { get; set; }

    public long Version { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? SubmittedAtUtc { get; set; }

    public DateTime? ProviderCompletedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public TemplateGenerationJob GenerationJob { get; set; } = null!;

    public List<TemplateProviderWebhookInbox> WebhookEvents { get; set; } = [];
}
