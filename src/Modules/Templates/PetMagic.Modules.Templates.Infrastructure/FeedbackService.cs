using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class FeedbackService(
    TemplatesDbContext dbContext,
    IEconomyService economyService) : IFeedbackService
{
    private const int DefaultTake = 50;
    private const int MaxTake = 100;

    public async Task<Result<SubmitFeedbackResponse>> SubmitAsync(
        SubmitFeedbackCommand command,
        CancellationToken cancellationToken)
    {
        var type = NormalizeType(command.Type);
        var category = NormalizeText(command.Category, 80);
        if (string.IsNullOrWhiteSpace(type) || string.IsNullOrWhiteSpace(category))
        {
            return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.InvalidFeedback);
        }

        var userId = command.UserId;
        var now = DateTime.UtcNow;
        TemplateGenerationJob? generation = null;
        if (command.GenerationId is Guid generationId)
        {
            generation = await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Include(x => x.Template)
                .FirstOrDefaultAsync(x => x.Id == generationId, cancellationToken);

            if (generation is null)
            {
                return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.GenerationJobNotFound);
            }

            if (userId is Guid currentUserId && generation.UserId != currentUserId)
            {
                return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackForbidden);
            }
        }

        if (command.PetId is Guid petId && userId is Guid petOwnerId)
        {
            var ownsPet = await dbContext.Pets
                .AsNoTracking()
                .AnyAsync(x => x.Id == petId && x.UserId == petOwnerId && !x.IsDeleted, cancellationToken);
            if (!ownsPet)
            {
                return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackForbidden);
            }
        }

        if (userId is Guid rateLimitedUserId)
        {
            var hourlyCount = await dbContext.TemplateGenerationFeedback
                .AsNoTracking()
                .CountAsync(x => x.UserId == rateLimitedUserId && x.CreatedAtUtc >= now.AddHours(-1), cancellationToken);
            if (hourlyCount >= 10)
            {
                return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackRateLimited);
            }

            if (generation is not null)
            {
                var generationCount = await dbContext.TemplateGenerationFeedback
                    .AsNoTracking()
                    .CountAsync(
                        x => x.UserId == rateLimitedUserId
                            && x.GenerationId == generation.Id,
                        cancellationToken);
                if (generationCount >= 3)
                {
                    return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackRateLimited);
                }
            }
            else if (type is "General" or "FeatureRequest")
            {
                var generalCount = await dbContext.TemplateGenerationFeedback
                    .AsNoTracking()
                    .CountAsync(
                        x => x.UserId == rateLimitedUserId
                            && x.GenerationId == null
                            && x.CreatedAtUtc >= now.AddDays(-1),
                        cancellationToken);
                if (generalCount >= 5)
                {
                    return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackRateLimited);
                }
            }
        }

        var templateId = generation?.TemplateId ?? command.TemplateId;
        var rating = NormalizeRating(command.Rating);
        var feedback = new TemplateGenerationFeedback
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Type = type,
            Category = category,
            Rating = rating,
            Message = NormalizeOptionalText(command.Message, 2000),
            GenerationId = generation?.Id ?? command.GenerationId,
            TemplateId = templateId,
            PetId = generation?.PetId ?? command.PetId,
            SourceScreen = NormalizeText(command.SourceScreen ?? "unknown", 80),
            AppVersion = NormalizeOptionalText(command.AppVersion, 64),
            Platform = NormalizeOptionalText(command.Platform, 32),
            DeviceModel = NormalizeOptionalText(command.DeviceModel, 128),
            Locale = NormalizeOptionalText(command.Locale, 16),
            ErrorCode = generation?.LastErrorCode,
            ProviderName = ResolveProviderName(generation),
            Status = "New",
            Priority = ResolvePriority(type, category, rating),
            SelectedReasons = JsonSerializer.Serialize(new[] { category }),
            Comment = NormalizeOptionalText(command.Message, 2000),
            ModelUsed = ResolveModel(generation),
            GenerationDurationSeconds = ResolveGenerationDurationSeconds(generation),
            ProviderRequestId = ResolveProviderRequestId(generation),
            CreatedAtUtc = now
        };

        dbContext.TemplateGenerationFeedback.Add(feedback);
        AddFeedbackAnalytics(feedback, generation, TemplateAnalyticsEventTypes.FeedbackSubmitted, now);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(new SubmitFeedbackResponse(feedback.Id, feedback.Status));
    }

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
            feedback.ReviewedAtUtc = DateTime.UtcNow;
            feedback.ReviewedByAdminId = command.AdminUserId;
            AddFeedbackAnalytics(feedback, feedback.Generation, TemplateAnalyticsEventTypes.AdminStatusChanged, DateTime.UtcNow);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Result.Success(await MapDetailsAsync(feedback, cancellationToken));
    }

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

        var amount = Math.Clamp(command.Amount ?? generation.TokenCost, 1, generation.TokenCost);
        var reason = NormalizeText(command.Reason ?? $"Feedback refund {feedback.Id}", 500);
        var creditResult = await economyService.CreditAsync(
            new CreditBalanceCommand(feedback.UserId.Value, amount, WalletLedgerSource.GenerationRefund, reason),
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

    private void AddFeedbackAnalytics(
        TemplateGenerationFeedback feedback,
        TemplateGenerationJob? generation,
        string eventType,
        DateTime now)
    {
        if (feedback.TemplateId is not Guid templateId)
        {
            return;
        }

        var metadata = JsonSerializer.Serialize(new
        {
            feedbackType = feedback.Type,
            category = feedback.Category,
            rating = feedback.Rating,
            generationId = feedback.GenerationId,
            templateId,
            platform = feedback.Platform,
            userPlan = (string?)null
        });

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            UserId = feedback.UserId,
            GenerationId = feedback.GenerationId,
            EventType = eventType,
            Source = feedback.SourceScreen,
            DeviceClass = feedback.Platform ?? "unknown",
            CountryCode = feedback.Locale ?? string.Empty,
            FeedbackMessage = feedback.Message ?? feedback.Comment,
            MetadataJson = metadata.Length <= 2000 ? metadata : metadata[..2000],
            ModerationStatus = "approved",
            CreatedAtUtc = now
        });
    }

    private static string ResolveProviderName(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return string.Empty;
        }

        if (!string.IsNullOrWhiteSpace(generation.MotionProviderRequestId))
        {
            return "fal";
        }

        if (!string.IsNullOrWhiteSpace(generation.PreprocessingProviderRequestId))
        {
            return "fal";
        }

        return string.Empty;
    }

    private static string? ResolveModel(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return null;
        }

        return !string.IsNullOrWhiteSpace(generation.UsedKlingModel)
            ? generation.UsedKlingModel
            : generation.UsedPreprocessingModel;
    }

    private static string? ResolveProviderRequestId(TemplateGenerationJob? generation)
    {
        if (generation is null)
        {
            return null;
        }

        return !string.IsNullOrWhiteSpace(generation.MotionProviderRequestId)
            ? generation.MotionProviderRequestId
            : generation.PreprocessingProviderRequestId;
    }

    private static double? ResolveGenerationDurationSeconds(TemplateGenerationJob? generation)
    {
        if (generation?.StartedAtUtc is not DateTime startedAt || generation.CompletedAtUtc is not DateTime completedAt)
        {
            return null;
        }

        return Math.Max(0, (completedAt - startedAt).TotalSeconds);
    }

    private static int? NormalizeRating(int? rating)
    {
        if (rating is null)
        {
            return null;
        }

        return Math.Clamp(rating.Value, -1, 1);
    }

    private static string NormalizeType(string value)
    {
        _ = TryNormalizeType(value, allowUnknownAsGeneral: true, out var normalized);
        return normalized;
    }

    private static bool TryValidateAdminFilters(AdminFeedbackQuery query, out Error error)
    {
        if (!string.IsNullOrWhiteSpace(query.Status)
            && !TryNormalizeStatus(query.Status, out _))
        {
            error = TemplatesErrors.InvalidFeedbackStatus;
            return false;
        }

        if (!string.IsNullOrWhiteSpace(query.Priority)
            && !TryNormalizePriority(query.Priority, out _))
        {
            error = TemplatesErrors.InvalidFeedbackPriority;
            return false;
        }

        if (!string.IsNullOrWhiteSpace(query.Type)
            && !TryNormalizeType(query.Type, allowUnknownAsGeneral: false, out _))
        {
            error = TemplatesErrors.InvalidFeedbackType;
            return false;
        }

        error = Error.None;
        return true;
    }

    private static bool TryNormalizeType(string value, bool allowUnknownAsGeneral, out string normalized)
    {
        normalized = NormalizeText(value, 32);
        if (normalized is "GenerationResult" or "GenerationFailure" or "BugReport" or "FeatureRequest" or "PaymentIssue" or "General")
        {
            return true;
        }

        if (allowUnknownAsGeneral)
        {
            normalized = "General";
            return true;
        }

        return false;
    }

    private static bool TryNormalizeStatus(string? value, out string normalized)
    {
        normalized = NormalizeText(value ?? "New", 24);
        return normalized is "New" or "InReview" or "Resolved" or "Dismissed";
    }

    private static bool TryNormalizePriority(string? value, out string normalized)
    {
        normalized = NormalizeText(value ?? "Low", 24);
        return normalized is "Low" or "Medium" or "High" or "Critical";
    }

    private static string ResolvePriority(string type, string category, int? rating)
    {
        if (type == "PaymentIssue" || category.Contains("payment", StringComparison.OrdinalIgnoreCase) || category.Contains("оплат", StringComparison.OrdinalIgnoreCase))
        {
            return "Critical";
        }

        if (category.Contains("inappropriate", StringComparison.OrdinalIgnoreCase) || category.Contains("неподход", StringComparison.OrdinalIgnoreCase))
        {
            return "High";
        }

        if (rating < 0 || category.Contains("quality", StringComparison.OrdinalIgnoreCase) || category.Contains("кач", StringComparison.OrdinalIgnoreCase))
        {
            return "Medium";
        }

        return "Low";
    }

    private static string NormalizeText(string value, int maxLength)
    {
        var trimmed = value.Trim();
        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return null;
        }

        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
    }
}
