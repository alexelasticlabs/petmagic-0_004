namespace PetMagic.BuildingBlocks.Notifications;

public enum PushOutboxStatus
{
    Queued = 1,
    Processing = 2,
    Sent = 3,
    DeadLetter = 4
}

public enum PushDeliveryDisposition
{
    Delivered = 1,
    Retry = 2,
    PermanentFailure = 3
}

public sealed record PushDeliveryResult(PushDeliveryDisposition Disposition, string? ErrorCode = null)
{
    public static PushDeliveryResult Delivered { get; } = new(PushDeliveryDisposition.Delivered);

    public static PushDeliveryResult Retry(string errorCode) => new(PushDeliveryDisposition.Retry, errorCode);

    public static PushDeliveryResult PermanentFailure(string errorCode) => new(PushDeliveryDisposition.PermanentFailure, errorCode);
}

public sealed class PushOutboxMessage
{
    public Guid Id { get; set; }

    public string DeduplicationKey { get; set; } = string.Empty;

    public string Kind { get; set; } = string.Empty;

    public Guid UserId { get; set; }

    public string PayloadJson { get; set; } = string.Empty;

    public PushOutboxStatus Status { get; set; }

    public int AttemptCount { get; set; }

    public DateTime NextAttemptAtUtc { get; set; }

    public Guid? LockId { get; set; }

    public DateTime? LockExpiresAtUtc { get; set; }

    public string? LastErrorCode { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }

    public DateTime? SentAtUtc { get; set; }
}

public static class PushOutboxPolicy
{
    public const int MaxAttempts = 8;

    public static readonly TimeSpan LeaseDuration = TimeSpan.FromMinutes(2);

    public static readonly TimeSpan SentRetention = TimeSpan.FromDays(7);

    public static TimeSpan RetryDelay(int attemptCount)
    {
        var delays = new[]
        {
            TimeSpan.FromSeconds(5),
            TimeSpan.FromSeconds(30),
            TimeSpan.FromMinutes(2),
            TimeSpan.FromMinutes(10),
            TimeSpan.FromMinutes(30)
        };
        return delays[Math.Clamp(attemptCount - 1, 0, delays.Length - 1)];
    }
}
