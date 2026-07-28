using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record AdminRenderScaleCommand(
    int TargetInstances,
    int? ExpectedCurrentInstances,
    string Reason,
    bool Confirmed);

public sealed record AdminRenderScaleOperationResponse(
    Guid OperationId,
    string Status,
    int? InitialInstances,
    int TargetInstances,
    int LoopsPerInstance,
    string Reason,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? DrainStartedAtUtc,
    DateTime? ScaleRequestedAtUtc,
    DateTime? CompletedAtUtc,
    DateTime? CancelledAtUtc,
    string? ErrorCode,
    bool CanCancel);

public static class AdminGenerationRenderControlErrors
{
    public static readonly Error InvalidRequest = new(
        "templates.render.scale_invalid_request",
        "Render scale request is invalid.");

    public static readonly Error ReasonRequired = new(
        "templates.render.scale_reason_required",
        "Render scale request requires a reason between 3 and 500 characters.");

    public static readonly Error ConfirmationRequired = new(
        "templates.render.scale_confirmation_required",
        "Render scale request requires explicit confirmation.");

    public static readonly Error IdempotencyKeyInvalid = new(
        "templates.render.scale_idempotency_key_invalid",
        "Render scale request requires a valid idempotency key.");

    public static readonly Error IdempotencyConflict = new(
        "templates.render.scale_idempotency_conflict",
        "The idempotency key was already used for a different Render scale request.");

    public static readonly Error OperationInProgress = new(
        "templates.render.scale_operation_in_progress",
        "Another Render scale operation is already active.");

    public static readonly Error CurrentInstancesChanged = new(
        "templates.render.scale_current_instances_changed",
        "Render worker instance count changed. Reload the page before scaling.");

    public static readonly Error OperationNotFound = new(
        "templates.render.scale_operation_not_found",
        "Render scale operation was not found.");

    public static readonly Error CancellationNotAllowed = new(
        "templates.render.scale_cancellation_not_allowed",
        "Render scale operation can no longer be cancelled.");
}
