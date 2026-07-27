using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class FeedbackService
{
    public async Task<Result<SubmitFeedbackResponse>> SubmitAsync(
        SubmitFeedbackCommand command,
        CancellationToken cancellationToken)
    {
        if (HasExceededMaxLength(command.Type, 32))
        {
            return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.InvalidFeedbackType);
        }

        if (!TryNormalizeType(command.Type, allowUnknownAsGeneral: false, out var type))
        {
            return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.InvalidFeedbackType);
        }

        if (command.Rating is < -1 or > 1
            || HasExceededMaxLength(command.Category, 80)
            || HasExceededMaxLength(command.Message, 2000)
            || HasExceededMaxLength(command.SourceScreen, 80)
            || HasExceededMaxLength(command.AppVersion, 64)
            || HasExceededMaxLength(command.Platform, 32)
            || HasExceededMaxLength(command.DeviceModel, 128)
            || HasExceededMaxLength(command.Locale, 16))
        {
            return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.InvalidFeedback);
        }

        var category = NormalizeText(command.Category, 80);
        if (string.IsNullOrWhiteSpace(category))
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

        if (generation is null && command.TemplateId is Guid requestedTemplateId)
        {
            var templateExists = await dbContext.TemplateItems
                .AsNoTracking()
                .AnyAsync(x => x.Id == requestedTemplateId, cancellationToken);
            if (!templateExists)
            {
                return Result.Failure<SubmitFeedbackResponse>(TemplatesErrors.FeedbackNotFound);
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
        var rating = command.Rating;
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
}
