using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateGenerationJob
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid TemplateId { get; set; }

    public TemplateGenerationStatus Status { get; set; }

    public int TokenCost { get; set; }

    public string SourceImageUrl { get; set; } = string.Empty;

    public string SourceImageFileName { get; set; } = string.Empty;

    public string SourceImageContentType { get; set; } = string.Empty;

    public long? SourceImageFileSizeBytes { get; set; }

    public string? NormalizedImageUrl { get; set; }

    public string? ReferenceMotionUrl { get; set; }

    public string? OutputUrl { get; set; }

    public int AttemptCount { get; set; }

    public string? FailureCode { get; set; }

    public string? FailureMessage { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime QueuedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? LastAttemptAtUtc { get; set; }

    public DateTime? ChargedAtUtc { get; set; }

    public DateTime? RefundedAtUtc { get; set; }

    public int RefundAttemptCount { get; set; }

    public string? RefundLastErrorCode { get; set; }

    public DateTime? RefundLastAttemptedAtUtc { get; set; }

    public DateTime? StartedAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public DateTime? UserMediaDeletedAtUtc { get; set; }

    public DateTime? LastUserMediaCleanupAttemptAtUtc { get; set; }

    public string? UserMediaCleanupFailureCode { get; set; }

    public TemplateItem Template { get; set; } = null!;

    public List<TemplateMediaRecord> MediaRecords { get; set; } = [];
}
