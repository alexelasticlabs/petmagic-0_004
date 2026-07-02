using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationBillingReconciliationService(
    TemplatesDbContext dbContext) : IGenerationBillingReconciliationService
{
    public async Task<Result<IReadOnlyList<GenerationBillingSnapshot>>> ListGenerationBillingSnapshotsAsync(
        DateTime changedAfterUtc,
        int take,
        CancellationToken cancellationToken)
    {
        var normalizedTake = Math.Clamp(take, 1, 1000);
        var snapshots = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.CreatedAtUtc >= changedAfterUtc
                || x.UpdatedAtUtc >= changedAfterUtc
                || x.ChargedAtUtc >= changedAfterUtc
                || x.RefundedAtUtc >= changedAfterUtc
                || (x.Status == TemplateGenerationStatus.Failed && x.RefundedAtUtc == null)
                || (x.Status == TemplateGenerationStatus.Cancelled && x.RefundedAtUtc == null))
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(normalizedTake)
            .Select(x => ToSnapshot(x))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<GenerationBillingSnapshot>>(snapshots);
    }

    public async Task<Result<GenerationBillingSnapshot>> GetGenerationBillingSnapshotAsync(
        Guid generationId,
        CancellationToken cancellationToken)
    {
        var snapshot = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Id == generationId)
            .Select(x => ToSnapshot(x))
            .FirstOrDefaultAsync(cancellationToken);

        return snapshot is null
            ? Result.Failure<GenerationBillingSnapshot>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(snapshot);
    }

    public async Task<Result<GenerationBillingRecoveryResponse>> RestoreGenerationChargeMarkerAsync(
        Guid generationId,
        DateTime chargedAtUtc,
        string reason,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<GenerationBillingRecoveryResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        job.ChargedAtUtc ??= chargedAtUtc;
        if (job.UpdatedAtUtc < chargedAtUtc)
        {
            job.UpdatedAtUtc = chargedAtUtc;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToRecoveryResponse(job));
    }

    public async Task<Result<GenerationBillingRecoveryResponse>> MarkGenerationRefundedAsync(
        Guid generationId,
        DateTime refundedAtUtc,
        string reason,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);
        if (job is null)
        {
            return Result.Failure<GenerationBillingRecoveryResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        job.RefundedAtUtc ??= refundedAtUtc;
        job.RefundLastErrorCode = null;
        job.RefundLastAttemptedAtUtc ??= refundedAtUtc;
        if (job.UpdatedAtUtc < refundedAtUtc)
        {
            job.UpdatedAtUtc = refundedAtUtc;
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(ToRecoveryResponse(job));
    }

    private static GenerationBillingSnapshot ToSnapshot(TemplateGenerationJob job)
    {
        return new GenerationBillingSnapshot(
            job.Id,
            job.UserId,
            job.TokenCost,
            job.Status.ToString(),
            job.CreatedAtUtc,
            job.UpdatedAtUtc,
            job.ChargedAtUtc,
            job.RefundedAtUtc,
            job.RefundAttemptCount,
            job.RefundLastErrorCode,
            job.RefundLastAttemptedAtUtc,
            job.CompletedAtUtc,
            job.LastErrorCode,
            job.IdempotencyKey,
            job.RequestHash);
    }

    private static GenerationBillingRecoveryResponse ToRecoveryResponse(TemplateGenerationJob job)
    {
        return new GenerationBillingRecoveryResponse(
            job.Id,
            job.UserId,
            job.Status.ToString(),
            job.ChargedAtUtc,
            job.RefundedAtUtc,
            job.UpdatedAtUtc);
    }
}
