namespace PetMagic.Host.Api.Observability;

public sealed record AdminOperationsStatusDto(
    string OverallStatus,
    DateTime GeneratedAtUtc,
    int CacheDurationSeconds,
    int StaleAfterSeconds,
    AdminOperationsQueueStatusDto Email,
    AdminOperationsQueueStatusDto AuditOutbox,
    AdminOperationsQueueStatusDto PushOutbox,
    AdminGenerationOperationsStatusDto Generations,
    AdminEconomyOperationsStatusDto Economy,
    AdminWorkerOperationsStatusDto Workers,
    IReadOnlyList<string> UnavailableSources);

public sealed record AdminOperationsQueueStatusDto(
    string Status,
    int BacklogCount,
    int DeadLetterCount,
    long? OldestItemAgeSeconds,
    DateTime? LastSuccessfulRunAtUtc);

public sealed record AdminGenerationOperationsStatusDto(
    string Status,
    int QueueDepth,
    long? OldestQueuedItemAgeSeconds);

public sealed record AdminEconomyOperationsStatusDto(
    string Status,
    int OpenIncidentCount,
    int CriticalIncidentCount);

public sealed record AdminWorkerOperationsStatusDto(
    string Status,
    DateTime? LastSuccessfulRunAtUtc,
    DateTime? GenerationWorkerHeartbeatAtUtc,
    long? GenerationWorkerHeartbeatAgeSeconds);

public sealed record AdminOperationsProblemListDto(
    string Source,
    IReadOnlyList<AdminOperationsProblemDto> Items);

public sealed record AdminOperationsProblemDto(
    string Source,
    string Module,
    string Id,
    string Kind,
    string Status,
    int AttemptCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? NextAttemptAtUtc,
    string? ErrorCode);

public sealed record AdminOperationsSnapshot(
    int EmailBacklogCount,
    int EmailDeadLetterCount,
    DateTime? OldestEmailQueuedAtUtc,
    DateTime? LastEmailSentAtUtc,
    int AuditBacklogCount,
    int AuditDeadLetterCount,
    DateTime? OldestAuditQueuedAtUtc,
    DateTime? LastAuditSentAtUtc,
    int PushBacklogCount,
    int PushDeadLetterCount,
    DateTime? OldestPushQueuedAtUtc,
    DateTime? LastPushSentAtUtc,
    int GenerationQueueDepth,
    DateTime? OldestGenerationQueuedAtUtc,
    DateTime? LastGenerationCompletedAtUtc,
    int OpenEconomyIncidentCount,
    int CriticalEconomyIncidentCount,
    DateTime? GenerationWorkerHeartbeatAtUtc,
    IReadOnlyList<string> UnavailableSources);
