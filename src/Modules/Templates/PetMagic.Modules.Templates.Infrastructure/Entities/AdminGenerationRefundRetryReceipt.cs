namespace PetMagic.Modules.Templates.Infrastructure.Entities;

public sealed class AdminGenerationRefundRetryReceipt
{
    public Guid Id { get; set; }

    public Guid ActorUserId { get; set; }

    public Guid GenerationId { get; set; }

    public string IdempotencyKey { get; set; } = string.Empty;

    public string RequestHash { get; set; } = string.Empty;

    public string? Reason { get; set; }

    public int PreviousRefundAttemptCount { get; set; }

    public DateTime? PreviousRefundLastAttemptedAtUtc { get; set; }

    public string? PreviousRefundLastErrorCode { get; set; }

    public string CorrelationId { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }
}
