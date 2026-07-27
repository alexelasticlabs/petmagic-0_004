using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class FeedbackService
{
    public async Task<Result<CreditRefundResponse>> RefundCreditsAsync(
        RefundFeedbackCreditsCommand command,
        CancellationToken cancellationToken)
    {
        var intentResult = await GetOrCreateRefundIntentAsync(command, cancellationToken);
        if (intentResult.IsFailure)
        {
            return Result.Failure<CreditRefundResponse>(intentResult.Error);
        }

        var intent = intentResult.Value;
        var creditResult = await economyService.CreditAsync(
            new CreditBalanceCommand(
                intent.UserId,
                intent.Amount,
                WalletLedgerSource.GenerationRefund,
                intent.Reason,
                // Share the generation-level ledger key with automatic refunds so a race
                // between the worker and an admin action cannot credit the generation twice.
                $"generation_refund:{intent.GenerationId:N}",
                PreviousIdempotencyKeys: [$"feedback_refund:{intent.FeedbackId:N}"]),
            cancellationToken);
        if (creditResult.IsFailure)
        {
            return Result.Failure<CreditRefundResponse>(creditResult.Error);
        }

        // A zero delta means Economy found a current generation refund or the
        // historical feedback-level key. The durable intent below makes either
        // response safe to finish after a restart without issuing another credit.
        return await CompleteRefundIntentAsync(intent, cancellationToken);
    }

    private async Task<Result<PendingRefundIntent>> GetOrCreateRefundIntentAsync(
        RefundFeedbackCreditsCommand command,
        CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 2; attempt++)
        {
            var feedback = await LoadFeedbackDetailsAsync(command.FeedbackId, cancellationToken);
            if (feedback is null)
            {
                return Result.Failure<PendingRefundIntent>(TemplatesErrors.FeedbackNotFound);
            }

            var generation = feedback.Generation;
            var existingRefund = await FindExistingRefundAsync(
                feedback.Id,
                generation?.Id,
                cancellationToken,
                track: true);
            if (existingRefund is not null)
            {
                if (IsPendingRefund(existingRefund)
                    && existingRefund.FeedbackId == feedback.Id
                    && generation is not null
                    && existingRefund.GenerationId == generation.Id)
                {
                    return Result.Success(ToPendingRefundIntent(existingRefund));
                }

                return Result.Failure<PendingRefundIntent>(TemplatesErrors.FeedbackRefundAlreadyIssued);
            }

            var refundUnavailableReason = GetRefundUnavailableReason(feedback, generation, refund: null);
            if (refundUnavailableReason is not null)
            {
                return Result.Failure<PendingRefundIntent>(
                    refundUnavailableReason == TemplatesErrors.FeedbackRefundAlreadyIssued.Code
                        ? TemplatesErrors.FeedbackRefundAlreadyIssued
                        : TemplatesErrors.FeedbackRefundUnavailable);
            }

            var refundableGeneration = generation!;
            var amount = refundableGeneration.TokenCost;
            if (command.Amount.HasValue)
            {
                if (command.Amount.Value <= 0 || command.Amount.Value > refundableGeneration.TokenCost)
                {
                    return Result.Failure<PendingRefundIntent>(TemplatesErrors.InvalidFeedbackRefundAmount);
                }

                amount = command.Amount.Value;
            }

            var reason = NormalizeOptionalText(command.Reason, 500) ?? $"Feedback refund {feedback.Id}";

            var refund = CreatePendingRefundIntent(
                feedback,
                refundableGeneration,
                feedback.UserId!.Value,
                amount,
                reason,
                command.AdminUserId,
                DateTime.UtcNow);
            dbContext.CreditRefunds.Add(refund);
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return Result.Success(ToPendingRefundIntent(refund));
            }
            catch (DbUpdateException) when (attempt == 0)
            {
                // Another request may have persisted the unique feedback/generation
                // intent. Reload it and either continue it or report it as completed.
                dbContext.ChangeTracker.Clear();
            }
        }

        throw new DbUpdateException("Could not persist a unique feedback refund intent.");
    }

    private async Task<Result<CreditRefundResponse>> CompleteRefundIntentAsync(
        PendingRefundIntent intent,
        CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 2; attempt++)
        {
            var feedback = await LoadFeedbackDetailsAsync(intent.FeedbackId, cancellationToken);
            if (feedback is null)
            {
                return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackNotFound);
            }

            var generation = feedback.Generation;
            if (generation is null || generation.Id != intent.GenerationId)
            {
                return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackRefundUnavailable);
            }

            var refund = await dbContext.CreditRefunds
                .FirstOrDefaultAsync(x => x.Id == intent.RefundId, cancellationToken);
            if (refund is null
                || refund.FeedbackId != feedback.Id
                || refund.GenerationId != generation.Id)
            {
                return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackRefundUnavailable);
            }

            if (!IsPendingRefund(refund))
            {
                return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackRefundAlreadyIssued);
            }

            CompleteRefundMarker(feedback, generation, refund, DateTime.UtcNow);
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
            }
            catch (DbUpdateException) when (attempt == 0)
            {
                // SettlementStatus is a concurrency token, so a concurrent completion
                // is reloaded instead of recording a duplicate audit entry.
                dbContext.ChangeTracker.Clear();
                continue;
            }

            await WriteAdminFeedbackAuditAsync(
                action: "admin.feedback.refunded",
                feedbackId: feedback.Id,
                oldValue: null,
                newValue: refund.Amount.ToString(System.Globalization.CultureInfo.InvariantCulture),
                details: $"Refunded {refund.Amount} credits for generation {generation.Id:D}.",
                subjectUserId: feedback.UserId,
                cancellationToken: cancellationToken);

            return Result.Success(MapRefund(refund));
        }

        throw new DbUpdateException("Could not complete a feedback refund intent.");
    }

    private Task<CreditRefund?> FindExistingRefundAsync(
        Guid feedbackId,
        Guid? generationId,
        CancellationToken cancellationToken,
        bool track = false)
    {
        IQueryable<CreditRefund> refunds = track
            ? dbContext.CreditRefunds
            : dbContext.CreditRefunds.AsNoTracking();
        return generationId is Guid id
            ? refunds.FirstOrDefaultAsync(
                x => x.FeedbackId == feedbackId || x.GenerationId == id,
                cancellationToken)
            : refunds.FirstOrDefaultAsync(x => x.FeedbackId == feedbackId, cancellationToken);
    }

    private static CreditRefund CreatePendingRefundIntent(
        TemplateGenerationFeedback feedback,
        TemplateGenerationJob generation,
        Guid userId,
        int amount,
        string reason,
        Guid adminUserId,
        DateTime createdAtUtc)
    {
        var refund = new CreditRefund
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            FeedbackId = feedback.Id,
            GenerationId = generation.Id,
            Amount = amount,
            Reason = reason,
            AdminId = adminUserId,
            CreatedAtUtc = createdAtUtc,
            SettlementStatus = CreditRefundSettlementStatus.Pending
        };
        return refund;
    }

    private void CompleteRefundMarker(
        TemplateGenerationFeedback feedback,
        TemplateGenerationJob generation,
        CreditRefund refund,
        DateTime completedAtUtc)
    {
        refund.SettlementStatus = CreditRefundSettlementStatus.Completed;
        generation.RefundedAtUtc ??= completedAtUtc;
        generation.RefundLastAttemptedAtUtc = completedAtUtc;
        feedback.Status = "Resolved";
        feedback.ReviewedAtUtc = completedAtUtc;
        feedback.ReviewedByAdminId = refund.AdminId;
        AddFeedbackAnalytics(feedback, generation, TemplateAnalyticsEventTypes.AdminRefundIssued, completedAtUtc);
    }

    private static string? GetRefundUnavailableReason(
        TemplateGenerationFeedback feedback,
        TemplateGenerationJob? generation,
        CreditRefund? refund)
    {
        if (!IsPendingRefund(refund)
            && (refund is not null || generation?.RefundedAtUtc is not null))
        {
            return TemplatesErrors.FeedbackRefundAlreadyIssued.Code;
        }

        return generation is null
            || feedback.UserId is null
            || generation.ChargedAtUtc is null
            || generation.TokenCost <= 0
                ? TemplatesErrors.FeedbackRefundUnavailable.Code
                : null;
    }

    private static bool IsPendingRefund(CreditRefund? refund) =>
        string.Equals(refund?.SettlementStatus, CreditRefundSettlementStatus.Pending, StringComparison.Ordinal);

    private static PendingRefundIntent ToPendingRefundIntent(CreditRefund refund) =>
        new(refund.Id, refund.FeedbackId!.Value, refund.GenerationId!.Value, refund.UserId, refund.Amount, refund.Reason, refund.AdminId);

    private sealed record PendingRefundIntent(
        Guid RefundId,
        Guid FeedbackId,
        Guid GenerationId,
        Guid UserId,
        int Amount,
        string Reason,
        Guid AdminId);

    public async Task<Result<TemplateFeedbackSummaryResponse>> GetTemplateSummaryAsync(
        Guid templateId,
        CancellationToken cancellationToken)
    {
        var templateFeedback = dbContext.TemplateGenerationFeedback
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId);

        var counts = await templateFeedback
            .GroupBy(_ => 1)
            .Select(group => new
            {
                Positive = group.Count(x => x.Rating > 0),
                Neutral = group.Count(x => x.Rating == 0),
                Negative = group.Count(x => x.Rating < 0)
            })
            .SingleOrDefaultAsync(cancellationToken);

        var positive = counts?.Positive ?? 0;
        var neutral = counts?.Neutral ?? 0;
        var negative = counts?.Negative ?? 0;
        var rated = Math.Max(1, positive + neutral + negative);
        var topIssues = await templateFeedback
            .Where(x => x.Rating <= 0)
            .GroupBy(x => x.Category)
            .Select(group => new TemplateFeedbackIssueResponse(group.Key, group.Count()))
            .OrderByDescending(x => x.Count)
            .ThenBy(x => x.Category)
            .Take(5)
            .ToListAsync(cancellationToken);

        var negativeRate = negative * 100d / rated;
        return Result.Success(new TemplateFeedbackSummaryResponse(
            templateId,
            positive,
            neutral,
            negative,
            positive * 100d / rated,
            neutral * 100d / rated,
            negativeRate,
            topIssues,
            negative >= 5 && negativeRate >= 35d));
    }
}
