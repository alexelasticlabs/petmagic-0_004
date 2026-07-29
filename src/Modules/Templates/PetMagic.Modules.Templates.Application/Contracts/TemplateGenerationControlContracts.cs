namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record AdminTemplateGenerationControlResponse(
    long Revision,
    bool AdmissionEnabled,
    int ConfirmedFalConcurrencyLimit,
    DateTime ConfirmedAtUtc,
    int ReservedHeadroom,
    int ApplicationHardCeiling,
    int EffectiveGlobalLimit,
    AdminTemplateGenerationConcurrencyProfileResponse Policy,
    AdminTemplateGenerationConcurrencyProfileResponse EffectiveProfile,
    AdminTemplateGenerationProviderBalanceResponse Balance,
    AdminTemplateGenerationQueueCapacityResponse Queue,
    AdminTemplateGenerationLaneCapacityResponse Lanes,
    AdminTemplateGenerationWorkerCapacityResponse Worker,
    IReadOnlyList<AdminTemplateGenerationControlAlertResponse> Alerts,
    DateTime GeneratedAtUtc);

public sealed record AdminTemplateGenerationConcurrencyProfileResponse(
    int GlobalMaxConcurrentGenerations,
    int ImageReservedConcurrentGenerations,
    int ImageProtectedConcurrentGenerations,
    int ImageMaxConcurrentGenerations,
    int VideoReservedConcurrentGenerations,
    int VideoMaxConcurrentGenerations,
    int VideoBorrowMaxConcurrentGenerations,
    int VideoPreprocessingMaxConcurrentGenerations);

public sealed record AdminTemplateGenerationProviderBalanceResponse(
    string State,
    decimal? CurrentBalanceUsd,
    DateTime? LastSuccessfulAtUtc,
    DateTime? CheckedAtUtc);

public sealed record AdminTemplateGenerationQueueCapacityResponse(
    int TotalDepth,
    int ImageDepth,
    int VideoDepth,
    DateTime? OldestQueuedAtUtc,
    IReadOnlyList<AdminTemplateGenerationQueueStageResponse> Stages);

public sealed record AdminTemplateGenerationQueueStageResponse(
    string Stage,
    int Count,
    DateTime? OldestAtUtc);

public sealed record AdminTemplateGenerationLaneCapacityResponse(
    int InFlightTotal,
    int ImageInFlight,
    int VideoInFlight,
    int VideoPreprocessingInFlight,
    int NativeSlotsInUse,
    int BorrowedSlotsInUse,
    int ReservedSlotsAvailable,
    int SubmissionUnknownCount);

public sealed record AdminTemplateGenerationWorkerCapacityResponse(
    int InstanceCount,
    DateTime? HeartbeatAtUtc,
    long? AppliedPolicyRevision,
    bool? SchedulerV2Enabled,
    int? DispatchConcurrency,
    int? ReconciliationConcurrency,
    int? MediaImportConcurrency,
    int? MaintenanceConcurrency,
    DateTime? LastProgressAtUtc);

public sealed record AdminTemplateGenerationControlAlertResponse(
    string AlertId,
    DateTime StatusChangedAtUtc,
    string Severity,
    string Title,
    string Message);

public sealed record UpdateAdminTemplateGenerationControlPolicyCommand(
    Guid ActorUserId,
    string IdempotencyKey,
    long ExpectedRevision,
    string Reason,
    bool AdmissionEnabled,
    int ConfirmedFalConcurrencyLimit,
    int ReservedHeadroom,
    int ApplicationHardCeiling);

public sealed record ResolveAdminTemplateProviderAttemptCommand(
    Guid ActorUserId,
    Guid ProviderAttemptId,
    string IdempotencyKey,
    long ExpectedAttemptVersion,
    string Resolution,
    string Reason,
    string EvidenceReference,
    string? ProviderRequestId,
    string? ProviderStatusUrl,
    string? ProviderResponseUrl,
    string? ProviderCancelUrl);

public sealed record AdminTemplateProviderAttemptResolutionResponse(
    Guid ProviderAttemptId,
    Guid GenerationId,
    string Resolution,
    string AttemptState,
    long AttemptVersion,
    bool RefundScheduled,
    DateTime ResolvedAtUtc);
