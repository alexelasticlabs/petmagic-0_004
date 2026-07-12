using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private const string LegacyGamificationMarkDeliveredAction = "mark_delivered";
    private const string LegacyGamificationReplayAction = "replay";

    public async Task<Result<AdminGamificationLegacyDeliveryResolutionResponse>> ResolveLegacyDeliveryAsync(
        Guid adminUserId,
        AdminGamificationLegacyDeliveryResolutionCommand command,
        CancellationToken cancellationToken)
    {
        var action = command.Action?.Trim().ToLowerInvariant();
        if (action is not (LegacyGamificationMarkDeliveredAction or LegacyGamificationReplayAction))
        {
            return Result.Failure<AdminGamificationLegacyDeliveryResolutionResponse>(
                TemplatesErrors.GamificationLegacyReviewActionInvalid);
        }

        var reason = command.Reason?.Trim();
        if (string.IsNullOrWhiteSpace(reason) || reason.Length > 1000)
        {
            return Result.Failure<AdminGamificationLegacyDeliveryResolutionResponse>(
                TemplatesErrors.GamificationLegacyReviewReasonRequired);
        }

        await using var transaction = await BeginGenerationAdminActionTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await LockGenerationRowForAdminActionAsync(command.GenerationId, cancellationToken);
        }

        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(job => job.Id == command.GenerationId, cancellationToken);
        if (job is null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<AdminGamificationLegacyDeliveryResolutionResponse>(TemplatesErrors.GenerationJobNotFound);
        }

        if (job.Status != TemplateGenerationStatus.Completed
            || job.GamificationProcessedAtUtc is null
            || job.GamificationAttemptCount >= 0)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<AdminGamificationLegacyDeliveryResolutionResponse>(
                TemplatesErrors.GamificationLegacyReviewNotRequired);
        }

        var now = DateTime.UtcNow;
        var replayQueued = action == LegacyGamificationReplayAction;
        job.GamificationAttemptCount = 0;
        job.GamificationLastErrorCode = null;
        job.GamificationNextAttemptAtUtc = replayQueued ? now : null;
        job.GamificationProcessedAtUtc = replayQueued ? null : job.GamificationProcessedAtUtc;
        job.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    $"admin.templates.gamification_legacy.{action}",
                    "TemplateGenerationJob",
                    job.Id.ToString("D"),
                    "legacy_review_required",
                    replayQueued ? "replay_queued" : "delivery_confirmed",
                    reason,
                    adminUserId),
                cancellationToken);
        }

        logger?.LogWarning(
            "ADMIN ACTION: legacy Gamification delivery resolved. AdminUserIdHash={AdminUserIdHash} GenerationIdHash={GenerationIdHash} Action={Action} ReplayQueued={ReplayQueued} ReasonHash={ReasonHash}",
            TemplateLogSanitizer.SafeId(adminUserId),
            TemplateLogSanitizer.SafeId(job.Id),
            action,
            replayQueued,
            SafeLogValues.StableHash(reason));

        return Result.Success(new AdminGamificationLegacyDeliveryResolutionResponse(
            job.Id,
            action,
            replayQueued,
            now));
    }
}
