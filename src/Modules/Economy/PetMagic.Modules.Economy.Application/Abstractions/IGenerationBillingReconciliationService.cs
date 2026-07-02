using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Economy.Application.Abstractions;

public interface IGenerationBillingReconciliationService
{
    Task<Result<IReadOnlyList<GenerationBillingSnapshot>>> ListGenerationBillingSnapshotsAsync(
        DateTime changedAfterUtc,
        int take,
        CancellationToken cancellationToken);

    Task<Result<GenerationBillingSnapshot>> GetGenerationBillingSnapshotAsync(
        Guid generationId,
        CancellationToken cancellationToken);

    Task<Result<GenerationBillingRecoveryResponse>> RestoreGenerationChargeMarkerAsync(
        Guid generationId,
        DateTime chargedAtUtc,
        string reason,
        CancellationToken cancellationToken);

    Task<Result<GenerationBillingRecoveryResponse>> MarkGenerationRefundedAsync(
        Guid generationId,
        DateTime refundedAtUtc,
        string reason,
        CancellationToken cancellationToken);
}

public sealed record GenerationBillingSnapshot(
    Guid GenerationId,
    Guid UserId,
    int TokenCost,
    string Status,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? ChargedAtUtc,
    DateTime? RefundedAtUtc,
    int RefundAttemptCount,
    string? RefundLastErrorCode,
    DateTime? RefundLastAttemptedAtUtc,
    DateTime? CompletedAtUtc,
    string? LastErrorCode,
    string? IdempotencyKey,
    string? RequestHash);

public sealed record GenerationBillingRecoveryResponse(
    Guid GenerationId,
    Guid UserId,
    string Status,
    DateTime? ChargedAtUtc,
    DateTime? RefundedAtUtc,
    DateTime UpdatedAtUtc);
