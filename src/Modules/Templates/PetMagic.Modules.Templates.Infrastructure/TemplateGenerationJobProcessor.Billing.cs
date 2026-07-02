using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationJobProcessor
{
    private static readonly TimeSpan BillingCommandRetryDelay = TimeSpan.FromMinutes(2);

    private async Task<bool> SettleNextPendingGenerationBillingCommandAsync(CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var retryBefore = now.Subtract(BillingCommandRetryDelay);
        var command = await dbContext.TemplateGenerationBillingCommands
            .Include(x => x.Generation)
            .ThenInclude(x => x.Template)
            .Where(x => x.Status == TemplateGenerationBillingCommandStatuses.Pending
                || (x.Status == TemplateGenerationBillingCommandStatuses.Processing
                    && (x.LastAttemptedAtUtc == null || x.LastAttemptedAtUtc <= retryBefore)))
            .OrderBy(x => x.LastAttemptedAtUtc ?? x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (command is null)
        {
            return false;
        }

        var job = command.Generation;
        if (job.ChargedAtUtc is not null)
        {
            command.Status = TemplateGenerationBillingCommandStatuses.Succeeded;
            command.CompletedAtUtc ??= job.ChargedAtUtc;
            command.UpdatedAtUtc = now;
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }

        if (job.Status != TemplateGenerationStatus.Queued || job.UserId == TemplateGenerationService.AdminTestUserId)
        {
            return await CompleteBillingCommandWithoutChargeAsync(command, job, cancellationToken);
        }

        command.Status = TemplateGenerationBillingCommandStatuses.Processing;
        command.AttemptCount++;
        command.LastAttemptedAtUtc = now;
        command.UpdatedAtUtc = now;
        command.LastErrorCode = null;
        command.LastErrorMessage = null;
        await dbContext.SaveChangesAsync(cancellationToken);

        var charge = await billing.ChargeAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (charge.IsFailure)
        {
            var failedAt = DateTime.UtcNow;
            var previousStatus = job.Status;
            command.Status = TemplateGenerationBillingCommandStatuses.Failed;
            command.LastErrorCode = charge.Error.Code;
            command.LastErrorMessage = charge.Error.Message;
            command.UpdatedAtUtc = failedAt;
            command.CompletedAtUtc = failedAt;
            job.Status = TemplateGenerationStatus.Failed;
            job.LastErrorCode = charge.Error.Code;
            job.LastErrorMessage = charge.Error.Message;
            job.UpdatedAtUtc = failedAt;
            job.CompletedAtUtc = failedAt;
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, charge.Error.Code);
            await PublishStatusChangedAsync(job, cancellationToken);
            return true;
        }

        var chargedAt = DateTime.UtcNow;
        command.Status = TemplateGenerationBillingCommandStatuses.Succeeded;
        command.UpdatedAtUtc = chargedAt;
        command.CompletedAtUtc = chargedAt;
        job.ChargedAtUtc = chargedAt;
        job.UpdatedAtUtc = chargedAt;
        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordJobAccepted(job);
        logger.LogInformation(
            "Recovered template generation billing command. GenerationId={GenerationId} AttemptCount={AttemptCount}",
            job.Id,
            command.AttemptCount);
        await PublishStatusChangedAsync(job, cancellationToken);
        return true;
    }

    private async Task<bool> CompleteBillingCommandWithoutChargeAsync(
        TemplateGenerationBillingCommand command,
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        command.Status = job.ChargedAtUtc is not null
            ? TemplateGenerationBillingCommandStatuses.Succeeded
            : TemplateGenerationBillingCommandStatuses.Failed;
        command.LastErrorCode = job.ChargedAtUtc is null ? TemplatesErrors.GenerationQueueOrphaned.Code : null;
        command.LastErrorMessage = job.ChargedAtUtc is null ? TemplatesErrors.GenerationQueueOrphaned.Message : null;
        command.UpdatedAtUtc = now;
        command.CompletedAtUtc ??= now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return true;
    }
}
