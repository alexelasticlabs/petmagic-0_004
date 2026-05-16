using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class EmailDispatchJob
{
    public Guid Id { get; set; }

    public Guid? UserId { get; set; }

    public string RecipientEmail { get; set; } = string.Empty;

    public EmailDispatchKind Kind { get; set; }

    public EmailDispatchStatus Status { get; set; }

    public string Subject { get; set; } = string.Empty;

    public string HtmlBody { get; set; } = string.Empty;

    public string TextBody { get; set; } = string.Empty;

    public int AttemptCount { get; set; }

    public DateTime QueuedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? LastAttemptAtUtc { get; set; }

    public DateTime? NextAttemptAtUtc { get; set; }

    public DateTime? SentAtUtc { get; set; }

    public string? FailureCode { get; set; }

    public string? FailureMessage { get; set; }
}