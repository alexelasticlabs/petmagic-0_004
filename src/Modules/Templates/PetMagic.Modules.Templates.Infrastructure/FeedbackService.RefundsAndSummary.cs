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
        var feedback = await dbContext.TemplateGenerationFeedback
            .Include(x => x.Generation)
            .FirstOrDefaultAsync(x => x.Id == command.FeedbackId, cancellationToken);
        if (feedback is null)
        {
            return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackNotFound);
        }

        var generation = feedback.Generation;
        if (generation is null || feedback.UserId is null || generation.ChargedAtUtc is null || generation.TokenCost <= 0)
        {
            return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackRefundUnavailable);
        }

        var existingRefund = await dbContext.CreditRefunds
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.FeedbackId == feedback.Id || x.GenerationId == generation.Id,
                cancellationToken);
        if (existingRefund is not null)
        {
            return Result.Failure<CreditRefundResponse>(TemplatesErrors.FeedbackRefundAlreadyIssued);
        }

        var amount = generation.TokenCost;
        if (command.Amount.HasValue)
        {
            if (command.Amount.Value <= 0 || command.Amount.Value > generation.TokenCost)
            {
                return Result.Failure<CreditRefundResponse>(TemplatesErrors.InvalidFeedbackRefundAmount);
            }

            amount = command.Amount.Value;
        }

        var reason = NormalizeOptionalText(command.Reason, 500) ?? $"Feedback refund {feedback.Id}";
        var creditResult = await economyService.CreditAsync(
            new CreditBalanceCommand(
                feedback.UserId.Value,
                amount,
                WalletLedgerSource.GenerationRefund,
                reason,
                $"feedback_refund:{feedback.Id:N}"),
            cancellationToken);
        if (creditResult.IsFailure)
        {
            return Result.Failure<CreditRefundResponse>(creditResult.Error);
        }

        var now = DateTime.UtcNow;
        var refund = new CreditRefund
        {
            Id = Guid.NewGuid(),
            UserId = feedback.UserId.Value,
            FeedbackId = feedback.Id,
            GenerationId = generation.Id,
            Amount = amount,
            Reason = reason,
            AdminId = command.AdminUserId,
            CreatedAtUtc = now
        };
        dbContext.CreditRefunds.Add(refund);
        generation.RefundedAtUtc ??= now;
        generation.RefundLastAttemptedAtUtc = now;
        feedback.Status = "Resolved";
        feedback.ReviewedAtUtc = now;
        feedback.ReviewedByAdminId = command.AdminUserId;
        AddFeedbackAnalytics(feedback, generation, TemplateAnalyticsEventTypes.AdminRefundIssued, now);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAdminFeedbackAuditAsync(
            action: "admin.feedback.refunded",
            feedbackId: feedback.Id,
            oldValue: null,
            newValue: amount.ToString(System.Globalization.CultureInfo.InvariantCulture),
            details: $"Refunded {amount} credits for generation {generation.Id:D}.",
            subjectUserId: feedback.UserId,
            cancellationToken: cancellationToken);

        return Result.Success(MapRefund(refund));
    }

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
