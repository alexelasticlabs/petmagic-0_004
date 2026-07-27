namespace PetMagic.Modules.Identity.Application.Contracts;

public static class AdminEmailBroadcastStatuses
{
    public const string Legacy = "legacy";
    public const string Queued = "queued";
    public const string Processing = "processing";
    public const string Completed = "completed";
    public const string PartiallyFailed = "partially-failed";
    public const string Failed = "failed";

    public static IReadOnlyList<string> All { get; } =
    [
        Legacy,
        Queued,
        Processing,
        Completed,
        PartiallyFailed,
        Failed
    ];
}

public sealed record AdminEmailBroadcastQueueResponse(
    Guid BroadcastId,
    int RecipientCount,
    string Status,
    DateTime CreatedAtUtc);

public sealed record AdminEmailBroadcastListItemResponse(
    Guid BroadcastId,
    string Audience,
    string? Subject,
    string Status,
    int RecipientCount,
    int PendingCount,
    int SentCount,
    int FailedCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? CompletedAtUtc);

public sealed record AdminEmailBroadcastsPageResponse(
    IReadOnlyList<AdminEmailBroadcastListItemResponse> Items,
    int Skip,
    int Take,
    int TotalCount,
    bool HasMore);

public sealed record AdminEmailBroadcastDetailResponse(
    Guid BroadcastId,
    string Audience,
    string? Subject,
    string Status,
    int RecipientCount,
    int PendingCount,
    int SentCount,
    int FailedCount,
    int RetryableFailedCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? CompletedAtUtc);

public sealed record AdminEmailBroadcastRetryResponse(
    Guid BroadcastId,
    int RetriedCount,
    string Status,
    int PendingCount,
    int SentCount,
    int FailedCount,
    DateTime UpdatedAtUtc);
