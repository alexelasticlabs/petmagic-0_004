namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class TemplateRenderScaleOperation
{
    public Guid Id { get; set; }

    public Guid ActorUserId { get; set; }

    public string IdempotencyKey { get; set; } = string.Empty;

    public string RequestHash { get; set; } = string.Empty;

    public string Status { get; set; } = string.Empty;

    public int? InitialInstances { get; set; }

    public int TargetInstances { get; set; }

    public int LoopsPerInstance { get; set; }

    public string Reason { get; set; } = string.Empty;

    public string CorrelationId { get; set; } = string.Empty;

    public long? DrainRuntimeVersion { get; set; }

    public DateTime? DrainStartedAtUtc { get; set; }

    public DateTime? ScaleRequestedAtUtc { get; set; }

    public DateTime? VerificationDeadlineAtUtc { get; set; }

    public DateTime? CompletedAtUtc { get; set; }

    public DateTime? CancelledAtUtc { get; set; }

    public string? ErrorCode { get; set; }

    public string? ErrorMessage { get; set; }

    public int AttemptCount { get; set; }

    public DateTime NextAttemptAtUtc { get; set; }

    public Guid? LockId { get; set; }

    public DateTime? LockExpiresAtUtc { get; set; }

    public long Version { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
