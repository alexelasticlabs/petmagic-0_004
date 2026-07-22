using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private static TemplateGenerationBillingCommand CreateGenerationBillingCommand(
        TemplateGenerationJob job,
        DateTime now,
        bool reserveForImmediateSettlement = false)
    {
        return new TemplateGenerationBillingCommand
        {
            Id = Guid.NewGuid(),
            GenerationId = job.Id,
            UserId = job.UserId,
            TokenCost = job.TokenCost,
            Status = reserveForImmediateSettlement
                ? TemplateGenerationBillingCommandStatuses.Processing
                : TemplateGenerationBillingCommandStatuses.Pending,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            LastAttemptedAtUtc = reserveForImmediateSettlement ? now : null
        };
    }

    private async Task<Result<TemplateGenerationResponse>> SettleGenerationBillingAndMapAsync(
        TemplateGenerationJob job,
        string? insufficientCreditsAnalyticsEvent,
        CancellationToken cancellationToken)
    {
        var settlement = await SettleGenerationBillingAsync(job, insufficientCreditsAnalyticsEvent, cancellationToken);
        if (settlement.IsFailure)
        {
            return Result.Failure<TemplateGenerationResponse>(settlement.Error);
        }

        return Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken));
    }

    private async Task<Result> SettleGenerationBillingAsync(
        TemplateGenerationJob job,
        string? insufficientCreditsAnalyticsEvent,
        CancellationToken cancellationToken)
    {
        if (job.ChargedAtUtc is not null || job.UserId == AdminTestUserId || job.TokenCost <= 0)
        {
            if (job.ChargedAtUtc is null && job.UserId != AdminTestUserId)
            {
                job.ChargedAtUtc = DateTime.UtcNow;
                job.UpdatedAtUtc = job.ChargedAtUtc.Value;
                await dbContext.SaveChangesAsync(cancellationToken);
                TemplateGenerationMetrics.RecordJobAccepted(job);
            }

            return Result.Success();
        }

        var command = await dbContext.TemplateGenerationBillingCommands
            .FirstOrDefaultAsync(x => x.GenerationId == job.Id, cancellationToken);
        if (command is null)
        {
            command = CreateGenerationBillingCommand(job, DateTime.UtcNow);
            dbContext.TemplateGenerationBillingCommands.Add(command);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        if (command.Status == TemplateGenerationBillingCommandStatuses.Succeeded)
        {
            job.ChargedAtUtc ??= command.CompletedAtUtc ?? DateTime.UtcNow;
            job.UpdatedAtUtc = job.ChargedAtUtc.Value;
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobAccepted(job);
            return Result.Success();
        }

        var attemptStartedAt = DateTime.UtcNow;
        command.Status = TemplateGenerationBillingCommandStatuses.Processing;
        command.AttemptCount++;
        command.LastAttemptedAtUtc = attemptStartedAt;
        command.UpdatedAtUtc = attemptStartedAt;
        command.LastErrorCode = null;
        command.LastErrorMessage = null;
        await dbContext.SaveChangesAsync(cancellationToken);

        var charge = await billing.ChargeAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
        if (charge.IsFailure)
        {
            var safeErrorCode = AdminFailureMessageSanitizer.SanitizeCode(charge.Error.Code);
            var safeErrorMessage = AdminFailureMessageSanitizer.Sanitize(charge.Error.Message);
            if (insufficientCreditsAnalyticsEvent is not null)
            {
                AddAnalyticsEvent(job, insufficientCreditsAnalyticsEvent);
            }

            var failedAt = DateTime.UtcNow;
            var previousStatus = job.Status;
            command.Status = TemplateGenerationBillingCommandStatuses.Failed;
            command.LastErrorCode = safeErrorCode;
            command.LastErrorMessage = safeErrorMessage;
            command.UpdatedAtUtc = failedAt;
            command.CompletedAtUtc = failedAt;
            job.Status = TemplateGenerationStatus.Failed;
            job.LastErrorCode = safeErrorCode;
            job.LastErrorMessage = safeErrorMessage;
            job.UpdatedAtUtc = failedAt;
            job.CompletedAtUtc = failedAt;
            await dbContext.SaveChangesAsync(cancellationToken);
            TemplateGenerationMetrics.RecordJobFailed(job, previousStatus, safeErrorCode ?? "templates.billing_failed");
            return Result.Failure(charge.Error);
        }

        var chargedAt = DateTime.UtcNow;
        command.Status = TemplateGenerationBillingCommandStatuses.Succeeded;
        command.UpdatedAtUtc = chargedAt;
        command.CompletedAtUtc = chargedAt;
        job.ChargedAtUtc = chargedAt;
        job.UpdatedAtUtc = chargedAt;
        await dbContext.SaveChangesAsync(cancellationToken);
        TemplateGenerationMetrics.RecordJobAccepted(job);
        return Result.Success();
    }
}
