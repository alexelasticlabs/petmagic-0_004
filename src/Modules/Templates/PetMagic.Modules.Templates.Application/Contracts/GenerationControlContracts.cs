namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record AdminGenerationRuntimeSettingsResponse(
    long Version,
    int GlobalMaxConcurrent,
    int ImageMaxConcurrent,
    int ImageProtectedConcurrent,
    int VideoGuaranteedConcurrent,
    int VideoMaxConcurrent,
    int VideoBorrowMaxConcurrent,
    int WorkerLoopsPerInstance,
    int FalConfiguredConcurrency,
    int FalReservedConcurrency,
    decimal FalBalanceLowThresholdUsd,
    decimal FalBalanceCriticalThresholdUsd,
    DateTime UpdatedAtUtc,
    Guid? UpdatedByAdminId);

public sealed record AdminGenerationCapacityStatusResponse(
    DateTime GeneratedAtUtc,
    long ActiveGlobal,
    long ActiveImage,
    long ActiveVideo,
    long QueuedImage,
    long QueuedVideo,
    int EffectiveImageMaxConcurrent,
    long BorrowedVideo,
    bool IsDraining,
    string Health);

public sealed record AdminFalProviderStatusResponse(
    int ConfiguredConcurrency,
    int ReservedConcurrency,
    int UsableConcurrency,
    long InflightRequests,
    decimal? BalanceUsd,
    string BalanceStatus,
    DateTime? CheckedAtUtc,
    DateTime? LastSuccessAtUtc,
    bool IsStale,
    bool ProviderSubmissionsAllowed,
    string? SubmissionBlockReason,
    string ConfiguredProvider,
    bool IsEnabled,
    bool BillingAdminKeyConfigured,
    string? LastErrorCode,
    int ConsecutiveFailures,
    bool LastAttemptSucceeded);

public sealed record AdminGenerationWorkerResponse(
    string InstanceId,
    DateTime LastSeenAtUtc,
    long HeartbeatAgeSeconds,
    long AppliedSettingsVersion,
    int ConfiguredLoops,
    bool IsStale,
    bool IsConfigCurrent,
    bool IsDraining);

public sealed record AdminGenerationOperationalAlertResponse(
    Guid Id,
    string Code,
    string Severity,
    string Title,
    string Message,
    DateTime ActivatedAtUtc,
    DateTime? ResolvedAtUtc,
    DateTime? AcknowledgedAtUtc,
    bool IsActive,
    bool IsAcknowledged);

public sealed record AdminGenerationRenderStatusResponse(
    bool IsConfigured,
    string? ServiceId,
    string? ServiceName,
    string? ServiceType,
    string? Plan,
    string? Region,
    int? DesiredInstances,
    int? ActiveInstances,
    bool AutoscalingEnabled,
    string? ConfigurationError,
    AdminRenderScaleOperationResponse? Operation);

public sealed record AdminGenerationControlResponse(
    AdminGenerationRuntimeSettingsResponse Settings,
    AdminGenerationCapacityStatusResponse Status,
    AdminFalProviderStatusResponse Fal,
    IReadOnlyList<AdminGenerationWorkerResponse> Workers,
    AdminGenerationRenderStatusResponse? Render,
    IReadOnlyList<AdminGenerationOperationalAlertResponse> Alerts);

public sealed record UpdateAdminGenerationControlCommand(
    long ExpectedVersion,
    int GlobalMaxConcurrent,
    int ImageMaxConcurrent,
    int ImageProtectedConcurrent,
    int VideoGuaranteedConcurrent,
    int VideoMaxConcurrent,
    int VideoBorrowMaxConcurrent,
    int WorkerLoopsPerInstance,
    int FalConfiguredConcurrency,
    int FalReservedConcurrency,
    decimal FalBalanceLowThresholdUsd,
    decimal FalBalanceCriticalThresholdUsd,
    string Reason,
    Guid ActorUserId,
    string ActorRole,
    string CorrelationId);

public sealed record TemplateGenerationRuntimeSnapshot(
    long Version,
    int GlobalMaxConcurrent,
    int ImageMaxConcurrent,
    int ImageProtectedConcurrent,
    int VideoGuaranteedConcurrent,
    int VideoMaxConcurrent,
    int VideoBorrowMaxConcurrent,
    int WorkerLoopsPerInstance,
    int FalConfiguredConcurrency,
    int FalReservedConcurrency,
    decimal FalBalanceLowThresholdUsd,
    decimal FalBalanceCriticalThresholdUsd,
    bool NewClaimsPaused,
    Guid? DrainOperationId,
    DateTime UpdatedAtUtc)
{
    public int FalUsableConcurrency => Math.Max(0, FalConfiguredConcurrency - FalReservedConcurrency);
}
