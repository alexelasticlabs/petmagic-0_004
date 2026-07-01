using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class FeedbackService
{
    public async Task<Result<AdminFeedbackPageResponse>> ListAdminAsync(
        AdminFeedbackQuery query,
        CancellationToken cancellationToken)
    {
        if (!TryValidateAdminFilters(query, out var filterError))
        {
            return Result.Failure<AdminFeedbackPageResponse>(filterError);
        }

        var skip = Math.Max(0, query.Skip ?? 0);
        var take = Math.Clamp(query.Take ?? DefaultTake, 1, MaxTake);
        var rows = ApplyAdminFilters(dbContext.TemplateGenerationFeedback.AsNoTracking(), query);
        var total = await rows.CountAsync(cancellationToken);
        var items = await rows
            .OrderByDescending(x => x.CreatedAtUtc)
            .Skip(skip)
            .Take(take)
            .Select(x => new AdminFeedbackListItemResponse(
                x.Id,
                x.UserId,
                x.Type,
                x.Category,
                x.Rating,
                x.GenerationId,
                x.TemplateId,
                x.Template != null ? x.Template.Title : null,
                x.PetId,
                x.SourceScreen,
                x.Platform,
                x.Status,
                x.Priority,
                x.Message ?? x.Comment,
                x.Generation != null ? (x.Generation.WatermarkedResultUrl ?? x.Generation.ResultUrl ?? x.Generation.SourceImageUrl) : null,
                x.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(new AdminFeedbackPageResponse(
            items,
            total,
            skip,
            take,
            skip + items.Count < total,
            DateTime.UtcNow));
    }

    public async Task<Result<AdminFeedbackDetailsResponse>> GetAdminAsync(
        Guid feedbackId,
        CancellationToken cancellationToken)
    {
        var feedback = await LoadFeedbackDetailsAsync(feedbackId, cancellationToken);
        return feedback is null
            ? Result.Failure<AdminFeedbackDetailsResponse>(TemplatesErrors.FeedbackNotFound)
            : Result.Success(await MapDetailsAsync(feedback, cancellationToken));
    }

    public async Task<Result<AdminFeedbackDetailsResponse>> UpdateAdminAsync(
        UpdateFeedbackAdminCommand command,
        CancellationToken cancellationToken)
    {
        var feedback = await dbContext.TemplateGenerationFeedback
            .Include(x => x.Generation)
            .ThenInclude(x => x!.Template)
            .FirstOrDefaultAsync(x => x.Id == command.FeedbackId, cancellationToken);
        if (feedback is null)
        {
            return Result.Failure<AdminFeedbackDetailsResponse>(TemplatesErrors.FeedbackNotFound);
        }

        var oldStatus = feedback.Status;
        var oldPriority = feedback.Priority;
        var oldAdminNote = feedback.AdminNote;
        var changed = false;
        if (!string.IsNullOrWhiteSpace(command.Status))
        {
            if (!TryNormalizeStatus(command.Status, out var normalizedStatus))
            {
                return Result.Failure<AdminFeedbackDetailsResponse>(TemplatesErrors.InvalidFeedbackStatus);
            }

            feedback.Status = normalizedStatus;
            changed = true;
        }

        if (!string.IsNullOrWhiteSpace(command.Priority))
        {
            if (!TryNormalizePriority(command.Priority, out var normalizedPriority))
            {
                return Result.Failure<AdminFeedbackDetailsResponse>(TemplatesErrors.InvalidFeedbackPriority);
            }

            feedback.Priority = normalizedPriority;
            changed = true;
        }

        if (command.AdminNote is not null)
        {
            feedback.AdminNote = NormalizeOptionalText(command.AdminNote, 2000);
            changed = true;
        }

        if (changed)
        {
            var now = DateTime.UtcNow;
            feedback.ReviewedAtUtc = now;
            feedback.ReviewedByAdminId = command.AdminUserId;
            AddFeedbackAnalytics(feedback, feedback.Generation, TemplateAnalyticsEventTypes.AdminStatusChanged, now);
            await dbContext.SaveChangesAsync(cancellationToken);
            await WriteAdminFeedbackAuditAsync(
                action: "admin.feedback.updated",
                feedbackId: feedback.Id,
                oldValue: BuildFeedbackAuditSnapshot(oldStatus, oldPriority, oldAdminNote),
                newValue: BuildFeedbackAuditSnapshot(feedback.Status, feedback.Priority, feedback.AdminNote),
                details: $"Updated feedback status={feedback.Status}, priority={feedback.Priority}.",
                subjectUserId: feedback.UserId,
                cancellationToken: cancellationToken);
        }

        return Result.Success(await MapDetailsAsync(feedback, cancellationToken));
    }

    private static IQueryable<TemplateGenerationFeedback> ApplyAdminFilters(
        IQueryable<TemplateGenerationFeedback> query,
        AdminFeedbackQuery filters)
    {
        if (!string.IsNullOrWhiteSpace(filters.Status))
        {
            _ = TryNormalizeStatus(filters.Status, out var status);
            query = query.Where(x => x.Status == status);
        }

        if (!string.IsNullOrWhiteSpace(filters.Priority))
        {
            _ = TryNormalizePriority(filters.Priority, out var priority);
            query = query.Where(x => x.Priority == priority);
        }

        if (!string.IsNullOrWhiteSpace(filters.Type))
        {
            _ = TryNormalizeType(filters.Type, allowUnknownAsGeneral: false, out var type);
            query = query.Where(x => x.Type == type);
        }

        if (!string.IsNullOrWhiteSpace(filters.Category))
        {
            var category = NormalizeText(filters.Category, 80);
            query = query.Where(x => x.Category == category);
        }

        if (filters.TemplateId is Guid templateId)
        {
            query = query.Where(x => x.TemplateId == templateId);
        }

        if (filters.GenerationId is Guid generationId)
        {
            query = query.Where(x => x.GenerationId == generationId);
        }

        if (!string.IsNullOrWhiteSpace(filters.Platform))
        {
            var platform = NormalizeText(filters.Platform, 32);
            query = query.Where(x => x.Platform == platform);
        }

        if (filters.FromUtc is DateTime fromUtc)
        {
            query = query.Where(x => x.CreatedAtUtc >= fromUtc.ToUniversalTime());
        }

        if (filters.ToUtc is DateTime toUtc)
        {
            query = query.Where(x => x.CreatedAtUtc <= toUtc.ToUniversalTime());
        }

        if (filters.UserId is Guid userId)
        {
            query = query.Where(x => x.UserId == userId);
        }

        return query;
    }

    private async Task<TemplateGenerationFeedback?> LoadFeedbackDetailsAsync(Guid feedbackId, CancellationToken cancellationToken)
    {
        return await dbContext.TemplateGenerationFeedback
            .Include(x => x.Generation)
            .ThenInclude(x => x!.Template)
            .FirstOrDefaultAsync(x => x.Id == feedbackId, cancellationToken);
    }

    private async Task<AdminFeedbackDetailsResponse> MapDetailsAsync(
        TemplateGenerationFeedback feedback,
        CancellationToken cancellationToken)
    {
        var refund = await dbContext.CreditRefunds
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.FeedbackId == feedback.Id, cancellationToken);
        var generation = feedback.Generation;
        var canRefund = generation is not null
            && feedback.UserId is not null
            && generation.ChargedAtUtc is not null
            && generation.TokenCost > 0
            && refund is null;

        return new AdminFeedbackDetailsResponse(
            feedback.Id,
            feedback.UserId,
            null,
            null,
            null,
            feedback.Type,
            feedback.Category,
            feedback.Rating,
            feedback.Message ?? feedback.Comment,
            feedback.SourceScreen,
            feedback.AppVersion,
            feedback.Platform,
            feedback.DeviceModel,
            feedback.Locale,
            feedback.ErrorCode,
            feedback.ProviderName,
            feedback.Status,
            feedback.Priority,
            feedback.CreatedAtUtc,
            feedback.ReviewedAtUtc,
            feedback.ReviewedByAdminId,
            feedback.AdminNote,
            generation is null ? null : new AdminFeedbackGenerationContextResponse(
                generation.Id,
                generation.UserId,
                generation.TemplateId,
                generation.Template.Title,
                generation.PetId,
                generation.SourceImageUrl,
                generation.WatermarkedResultUrl ?? generation.ResultUrl,
                ResolveProviderName(generation),
                generation.LastErrorCode,
                generation.TokenCost,
                generation.ChargedAtUtc,
                generation.RefundedAtUtc),
            canRefund,
            refund is null ? null : MapRefund(refund));
    }

    private static CreditRefundResponse MapRefund(CreditRefund refund) =>
        new(refund.Id, refund.UserId, refund.FeedbackId, refund.GenerationId, refund.Amount, refund.Reason, refund.AdminId, refund.CreatedAtUtc);
}
