using System.Globalization;
using Microsoft.EntityFrameworkCore;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplatesService(
    TemplatesDbContext dbContext,
    TemplatesOptions options,
    IMediaMetadataReader metadataReader,
    IMediaStorage mediaStorage,
    ITemplateMediaLifecycleService mediaLifecycleService) : ITemplatesService
{
    private sealed record GenerationStatisticsProjection(
        TemplateGenerationStatus Status,
        int TokenCost,
        decimal? MotionProviderCostUsd,
        DateTime CreatedAtUtc,
        DateTime? StartedAtUtc,
        DateTime? CompletedAtUtc);

    private sealed record GenerationAnalyticsProjection(
        Guid GenerationId,
        Guid TemplateId,
        Guid UserId,
        TemplateGenerationStatus Status,
        int TokenCost,
        int AttemptCount,
        string? UsedPreprocessingModel,
        string? UsedKlingModel,
        decimal? MotionProviderCostUsd,
        string? FailureCode,
        string? FailureMessage,
        string? OutputUrl,
        DateTime CreatedAtUtc,
        DateTime? StartedAtUtc,
        DateTime? CompletedAtUtc);

    public async Task<Result<IReadOnlyList<AdminTemplateListItemResponse>>> ListAdminAsync(TemplateType? type, TemplateStatus? status, CancellationToken cancellationToken)
    {
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => !status.HasValue || x.Status == status.Value)
            .OrderByDescending(x => x.UpdatedAtUtc)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateListItemResponse>>(items.Select(MapAdminListItem).ToArray());
    }

    public async Task<Result<AdminTemplateResponse>> GetAdminAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        return template is null
            ? Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound)
            : Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateStatisticsResponse>> GetAdminStatisticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<AdminTemplateStatisticsResponse>(TemplatesErrors.NotFound);
        }

        var jobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .Select(x => new GenerationStatisticsProjection(
                x.Status,
                x.TokenCost,
                x.MotionProviderCostUsd,
                x.CreatedAtUtc,
                x.StartedAtUtc,
                x.CompletedAtUtc))
            .ToArrayAsync(cancellationToken);

        return Result.Success(MapAdminStatisticsResponse(templateId, jobs));
    }

    public async Task<Result<IReadOnlyList<AdminTemplateTrendPointResponse>>> GetAdminTrendAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var jobs = await GetAnalyticsProjectionsAsync(templateId, cancellationToken);
        if (jobs is null)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateTrendPointResponse>>(TemplatesErrors.NotFound);
        }

        var trend = jobs
            .GroupBy(x => x.CreatedAtUtc.Date)
            .OrderBy(x => x.Key)
            .Select(group =>
            {
                var entries = group.ToArray();
                var totalRuns = entries.Length;
                var queuedRuns = entries.Count(x => x.Status == TemplateGenerationStatus.Queued);
                var processingRuns = entries.Count(x => x.Status == TemplateGenerationStatus.Processing);
                var completedRuns = entries.Count(x => x.Status == TemplateGenerationStatus.Completed);
                var failedRuns = entries.Count(x => x.Status == TemplateGenerationStatus.Failed);
                var totalTokenCost = entries.Sum(x => x.TokenCost);
                var totalProviderCostUsd = entries.Sum(x => x.MotionProviderCostUsd ?? 0m);
                var successRatePercent = totalRuns == 0
                    ? 0
                    : Math.Round((double)completedRuns * 100 / totalRuns, 1, MidpointRounding.AwayFromZero);
                var durations = entries
                    .Where(x => x.Status == TemplateGenerationStatus.Completed && x.StartedAtUtc.HasValue && x.CompletedAtUtc.HasValue)
                    .Select(x => (x.CompletedAtUtc!.Value - x.StartedAtUtc!.Value).TotalSeconds)
                    .Where(x => x >= 0)
                    .ToArray();
                double? averageGenerationSeconds = durations.Length == 0
                    ? null
                    : Math.Round(durations.Average(), 1, MidpointRounding.AwayFromZero);

                return new AdminTemplateTrendPointResponse(
                    group.Key,
                    totalRuns,
                    queuedRuns,
                    processingRuns,
                    completedRuns,
                    failedRuns,
                    successRatePercent,
                    totalTokenCost,
                    Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
                    averageGenerationSeconds);
            })
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateTrendPointResponse>>(trend);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateRecentGenerationResponse>>> GetAdminRecentGenerationsAsync(Guid templateId, int take, CancellationToken cancellationToken)
    {
        var jobs = await GetAnalyticsProjectionsAsync(templateId, cancellationToken);
        if (jobs is null)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateRecentGenerationResponse>>(TemplatesErrors.NotFound);
        }

        var recent = jobs
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .Select(x => new AdminTemplateRecentGenerationResponse(
                x.GenerationId,
                x.UserId,
                x.Status.ToString(),
                x.TokenCost,
                x.AttemptCount,
                x.UsedPreprocessingModel,
                x.UsedKlingModel,
                x.MotionProviderCostUsd,
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
                x.CreatedAtUtc,
                x.StartedAtUtc,
                x.CompletedAtUtc))
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateRecentGenerationResponse>>(recent);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>> GetAdminFailureBreakdownAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var jobs = await GetAnalyticsProjectionsAsync(templateId, cancellationToken);
        if (jobs is null)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>(TemplatesErrors.NotFound);
        }

        var failures = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Failed)
            .GroupBy(x => string.IsNullOrWhiteSpace(x.FailureCode) ? "templates.unknown_failure" : x.FailureCode!)
            .OrderByDescending(x => x.Count())
            .ThenBy(x => x.Key)
            .Select(group => new AdminTemplateFailureBreakdownItemResponse(
                group.Key,
                group.Count(),
                group.Max(x => x.CompletedAtUtc ?? x.StartedAtUtc ?? x.CreatedAtUtc)))
            .ToArray();

        return Result.Success<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>(failures);
    }

    public async Task<Result<AdminTemplateEventAnalyticsResponse>> GetAdminEventAnalyticsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<AdminTemplateEventAnalyticsResponse>(TemplatesErrors.NotFound);
        }

        var events = await dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .ToArrayAsync(cancellationToken);

        var viewEvents = events.Where(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View)).ToArray();
        var videoViewEvents = events.Where(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.VideoView)).ToArray();
        var complaintEvents = events.Where(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.Complaint)).ToArray();

        var response = new AdminTemplateEventAnalyticsResponse(
            viewEvents.Length,
            videoViewEvents.Length,
            complaintEvents.Length,
            BuildDimension(viewEvents, x => x.Source, "direct"),
            BuildDimension(viewEvents, x => x.DeviceClass, "unknown"),
            BuildDimension(viewEvents, x => x.CountryCode, "unknown"));

        return Result.Success(response);
    }

    public async Task<Result<IReadOnlyList<AdminTemplateFeedbackItemResponse>>> GetAdminFeedbackAsync(Guid templateId, AdminTemplateFeedbackQuery query, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure<IReadOnlyList<AdminTemplateFeedbackItemResponse>>(TemplatesErrors.NotFound);
        }

        var take = Math.Clamp(query.Take ?? 50, 1, 200);
        var eventType = NormalizeAnalyticsFilter(query.Type);
        var search = NormalizeOptionalText(query.Search, 200)?.ToLowerInvariant();

        var feedbackQuery = dbContext.TemplateAnalyticsEvents
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .Where(x => x.EventType == TemplateAnalyticsEventTypes.Complaint || x.EventType == TemplateAnalyticsEventTypes.Feedback);

        if (eventType is TemplateAnalyticsEventTypes.Complaint or TemplateAnalyticsEventTypes.Feedback)
        {
            feedbackQuery = feedbackQuery.Where(x => x.EventType == eventType);
        }

        if (!string.IsNullOrWhiteSpace(search))
        {
            feedbackQuery = feedbackQuery.Where(x => x.FeedbackMessage != null && x.FeedbackMessage.ToLower().Contains(search));
        }

        var items = await feedbackQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(take)
            .Select(x => new AdminTemplateFeedbackItemResponse(
                x.Id,
                x.EventType,
                x.FeedbackMessage,
                x.Source,
                x.DeviceClass,
                x.CountryCode,
                x.UserId,
                x.GenerationId,
                x.CreatedAtUtc))
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminTemplateFeedbackItemResponse>>(items);
    }

    public async Task<Result<AdminTemplatesAnalyticsOverviewResponse>> GetAdminTemplatesAnalyticsAsync(AdminTemplatesAnalyticsQuery query, CancellationToken cancellationToken)
    {
        var generatedAtUtc = DateTime.UtcNow;
        var periodDays = query.PeriodDays.HasValue ? Math.Clamp(query.PeriodDays.Value, 1, 3650) : (int?)null;
        var periodStartUtc = periodDays.HasValue ? generatedAtUtc.Date.AddDays(-(periodDays.Value - 1)) : (DateTime?)null;
        var templateType = ParseTemplateTypeFilter(query.TemplateType);
        var templateStatus = ParseTemplateStatusFilter(query.Status);
        var access = NormalizeAnalyticsFilter(query.Access);
        var category = string.IsNullOrWhiteSpace(query.Category) ? null : query.Category.Trim();
        var take = Math.Clamp(query.Take ?? 50, 1, 200);

        var allTemplates = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .ToArrayAsync(cancellationToken);

        var templates = allTemplates
            .Where(x => !templateType.HasValue || x.TemplateType == templateType.Value)
            .Where(x => !templateStatus.HasValue || x.Status == templateStatus.Value)
            .Where(x => category is null || string.Equals(x.Category, category, StringComparison.OrdinalIgnoreCase))
            .Where(x => access is null || access == "all" || (access == "premium" ? x.IsPremium : !x.IsPremium))
            .ToArray();
        var templateIds = templates.Select(x => x.Id).ToHashSet();

        var jobs = templateIds.Count == 0
            ? Array.Empty<GenerationAnalyticsProjection>()
            : await dbContext.TemplateGenerationJobs
                .AsNoTracking()
                .Where(x => templateIds.Contains(x.TemplateId))
                .Where(x => !periodStartUtc.HasValue || x.CreatedAtUtc >= periodStartUtc.Value)
                .Select(x => new GenerationAnalyticsProjection(
                    x.Id,
                    x.TemplateId,
                    x.UserId,
                    x.Status,
                    x.TokenCost,
                    x.AttemptCount,
                    x.UsedPreprocessingModel,
                    x.UsedKlingModel,
                    x.MotionProviderCostUsd,
                    x.FailureCode,
                    x.FailureMessage,
                    x.OutputUrl,
                    x.CreatedAtUtc,
                    x.StartedAtUtc,
                    x.CompletedAtUtc))
                .ToArrayAsync(cancellationToken);

        var events = templateIds.Count == 0
            ? Array.Empty<TemplateAnalyticsEvent>()
            : await dbContext.TemplateAnalyticsEvents
                .AsNoTracking()
                .Where(x => templateIds.Contains(x.TemplateId))
                .Where(x => !periodStartUtc.HasValue || x.CreatedAtUtc >= periodStartUtc.Value)
                .ToArrayAsync(cancellationToken);

        var jobsByTemplate = jobs.GroupBy(x => x.TemplateId).ToDictionary(x => x.Key, x => x.ToArray());
        var eventsByTemplate = events.GroupBy(x => x.TemplateId).ToDictionary(x => x.Key, x => x.ToArray());
        var templatesById = templates.ToDictionary(x => x.Id);
        var rows = templates
            .Select(template => BuildTemplatesAnalyticsRow(
                template,
                jobsByTemplate.GetValueOrDefault(template.Id) ?? [],
                eventsByTemplate.GetValueOrDefault(template.Id) ?? []))
            .ToArray();
        var sortedRows = SortTemplatesAnalyticsRows(rows, query.Sort).ToArray();

        var totalStarts = rows.Sum(x => x.GenerationStarts);
        var completed = rows.Sum(x => x.CompletedGenerations);
        var totalTokenCost = rows.Sum(x => x.TotalTokenCost);
        var totalProviderCostUsd = rows.Sum(x => x.TotalProviderCostUsd);
        var totalViews = rows.Sum(x => x.Views);
        var totalComplaints = events.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.Complaint));
        var viewEvents = events
            .Where(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View))
            .ToArray();
        var feedbackItems = events
            .Where(IsFeedbackEvent)
            .OrderByDescending(x => x.CreatedAtUtc)
            .Take(20)
            .Select(x =>
            {
                var template = templatesById[x.TemplateId];

                return new AdminTemplatesAnalyticsFeedbackItemResponse(
                    x.Id,
                    x.TemplateId,
                    template.Title,
                    template.TemplateType.ToString(),
                    x.EventType,
                    x.FeedbackMessage,
                    x.Source,
                    x.DeviceClass,
                    x.CountryCode,
                    x.UserId,
                    x.GenerationId,
                    x.CreatedAtUtc);
            })
            .ToArray();

        var response = new AdminTemplatesAnalyticsOverviewResponse(
            new AdminTemplatesAnalyticsSummaryResponse(
                rows.Length,
                templates.Count(x => x.TemplateType == TemplateType.Video),
                templates.Count(x => x.TemplateType == TemplateType.Image),
                templates.Count(x => x.Status == TemplateStatus.Active),
                templates.Count(x => x.IsPremium),
                totalViews,
                totalStarts,
                completed,
                rows.Sum(x => x.FailedGenerations),
                CalculatePercent(completed, totalStarts),
                totalTokenCost,
                totalStarts == 0 ? 0 : Math.Round((double)totalTokenCost / totalStarts, 1, MidpointRounding.AwayFromZero),
                Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
                totalComplaints),
            BuildTemplatesAnalyticsTrend(jobs, events),
            sortedRows.Take(5).ToArray(),
            BuildTemplatesAnalyticsBreakdown(rows, row => row.Category),
            BuildTemplatesAnalyticsBreakdown(rows, row => row.TemplateType),
            BuildDimension(viewEvents, x => x.Source, "direct"),
            BuildDimension(viewEvents, x => x.DeviceClass, "unknown"),
            BuildDimension(viewEvents, x => x.CountryCode, "unknown"),
            feedbackItems,
            new AdminTemplatesAnalyticsFunnelResponse(
                totalViews,
                totalStarts,
                completed,
                rows.Sum(x => x.FailedGenerations),
                totalComplaints),
            sortedRows.Take(take).ToArray(),
            allTemplates
                .Select(x => x.Category)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .OrderBy(x => x)
                .ToArray(),
            generatedAtUtc);

        return Result.Success(response);
    }

    public async Task<Result> RecordAnalyticsEventAsync(RecordTemplateAnalyticsEventCommand command, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == command.TemplateId, cancellationToken);

        if (!templateExists)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = command.TemplateId,
            UserId = command.UserId,
            GenerationId = command.GenerationId,
            EventType = NormalizeAnalyticsValue(command.EventType, TemplateAnalyticsEventTypes.View, 64),
            Source = NormalizeAnalyticsValue(command.Source, "direct", 64),
            DeviceClass = NormalizeAnalyticsValue(command.DeviceClass, "unknown", 32),
            CountryCode = NormalizeAnalyticsValue(command.CountryCode, "unknown", 8).ToUpperInvariant(),
            FeedbackMessage = NormalizeOptionalText(command.FeedbackMessage, 2000),
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    public async Task<Result<AdminTemplateResponse>> CreateImageAsync(CreateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Image,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            Category = command.Category.Trim(),
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateImageAsync(UpdateImageTemplateCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Image)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.Category = command.Category.Trim();
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
        template.Status = statusResult.Value;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> CreateVideoAsync(CreateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, TemplateStatus.Draft);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);
        var now = DateTime.UtcNow;
        var template = new TemplateItem
        {
            Id = Guid.NewGuid(),
            TemplateType = TemplateType.Video,
            Title = command.Title.Trim(),
            ShortDescription = command.ShortDescription.Trim(),
            Category = command.Category.Trim(),
            Tags = SerializeTags(command.Tags),
            IsPremium = command.IsPremium,
            TokenCost = command.TokenCost,
            Status = statusResult.Value,
            PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode),
            MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim(),
            ReferenceVideoDurationSeconds = duration,
            CharacterOrientation = orientation,
            PreprocessingModel = command.PreprocessingModel.Trim(),
            PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt),
            KlingModel = command.KlingModel.Trim(),
            KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt),
            KeepOriginalSound = command.KeepOriginalSound,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset);
        SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        dbContext.TemplateItems.Add(template);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> UpdateVideoAsync(UpdateVideoTemplateCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.TypeMismatch);
        }

        var modelCheck = ValidateVideoModels(command.PreprocessingModel, command.KlingModel);
        if (modelCheck.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(modelCheck.Error);
        }

        var statusResult = ResolveRequestedStatus(command.Status, template.Status);
        if (statusResult.IsFailure)
        {
            return Result.Failure<AdminTemplateResponse>(statusResult.Error);
        }

        var (duration, orientation) = await ResolveReferenceMetadataAsync(command.ReferenceMotionAsset, cancellationToken);

        template.Title = command.Title.Trim();
        template.ShortDescription = command.ShortDescription.Trim();
        template.Category = command.Category.Trim();
        template.Tags = SerializeTags(command.Tags);
        template.IsPremium = command.IsPremium;
        template.TokenCost = command.TokenCost;
        template.PromoBadgeMode = ParsePromoBadgeMode(command.PromoBadgeMode);
        template.MusicDescription = string.IsNullOrWhiteSpace(command.MusicDescription) ? null : command.MusicDescription.Trim();
        template.ReferenceVideoDurationSeconds = duration;
        template.CharacterOrientation = orientation;
        template.PreprocessingModel = command.PreprocessingModel.Trim();
        template.PreprocessingPrompt = ResolvePrompt(command.PreprocessingPrompt, options.DefaultPreprocessingPrompt);
        template.KlingModel = command.KlingModel.Trim();
        template.KlingPrompt = ResolvePrompt(command.KlingPrompt, options.DefaultKlingPrompt);
        template.KeepOriginalSound = command.KeepOriginalSound;
        template.Status = statusResult.Value;
        template.UpdatedAtUtc = DateTime.UtcNow;

        var obsoleteAssetUrls = CollectObsoleteAssetUrls([
            SetAsset(template, TemplateAssetKind.Preview, command.PreviewAsset),
            SetAsset(template, TemplateAssetKind.ReferenceMotion, command.ReferenceMotionAsset)
        ]);

        if (template.Status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.PreviewAsset, TemplateMediaRole.PreviewAsset, cancellationToken);
        await mediaLifecycleService.ClaimTemplateAssetAsync(template.Id, command.ReferenceMotionAsset, TemplateMediaRole.ReferenceMotionAsset, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await CleanupObsoleteMediaAsync(obsoleteAssetUrls, cancellationToken);
        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result<AdminTemplateResponse>> ChangeStatusAsync(ChangeTemplateStatusCommand command, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.NotFound);
        }

        if (!Enum.TryParse<TemplateStatus>(command.Status, true, out var status))
        {
            return Result.Failure<AdminTemplateResponse>(TemplatesErrors.InvalidStatus);
        }

        if (status == TemplateStatus.Active)
        {
            var activationCheck = ValidateActivation(template);
            if (activationCheck.IsFailure)
            {
                return Result.Failure<AdminTemplateResponse>(activationCheck.Error);
            }
        }

        template.Status = status;
        template.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success(MapAdminResponse(template));
    }

    public async Task<Result> DeleteAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        var assetUrls = CollectObsoleteAssetUrls(template.Assets.Select(asset => asset.Url));
        var cleanupResult = await DeleteTemplateAssetsAsync(assetUrls, cancellationToken);
        if (cleanupResult.IsFailure)
        {
            return cleanupResult;
        }

        dbContext.TemplateItems.Remove(template);
        await dbContext.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    public async Task<Result<IReadOnlyList<PublicTemplateListItemResponse>>> ListPublicAsync(TemplateType? type, string? category, string[]? tags, bool? premiumOnly, CancellationToken cancellationToken)
    {
        var normalizedTags = NormalizeTags(tags ?? []);
        var items = await dbContext.TemplateItems
            .AsNoTracking()
            .Include(x => x.Assets)
            .Where(x => x.Status == TemplateStatus.Active)
            .Where(x => !type.HasValue || x.TemplateType == type.Value)
            .Where(x => string.IsNullOrWhiteSpace(category) || string.Equals(x.Category, category.Trim(), StringComparison.OrdinalIgnoreCase))
            .Where(x => !premiumOnly.HasValue || !premiumOnly.Value || x.IsPremium)
            .OrderBy(x => x.IsPremium)
            .ThenBy(x => x.Title)
            .ToArrayAsync(cancellationToken);

        var filtered = items
            .Where(x => normalizedTags.Length == 0 || normalizedTags.All(tag => DeserializeTags(x.Tags).Contains(tag, StringComparer.OrdinalIgnoreCase)))
            .Select(MapPublicListItem)
            .ToArray();

        return Result.Success<IReadOnlyList<PublicTemplateListItemResponse>>(filtered);
    }

    public async Task<Result<PublicTemplateResponse>> GetPublicAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var template = await FindTemplateAsync(templateId, cancellationToken);
        if (template is null || template.Status != TemplateStatus.Active)
        {
            return Result.Failure<PublicTemplateResponse>(TemplatesErrors.NotFound);
        }

        return Result.Success(MapPublicResponse(template));
    }

    private Result ValidateVideoModels(string preprocessingModel, string klingModel)
    {
        if (!options.AllowedPreprocessingModels.Contains(preprocessingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidPreprocessingModel);
        }

        if (!options.AllowedKlingModels.Contains(klingModel.Trim(), StringComparer.OrdinalIgnoreCase))
        {
            return Result.Failure(TemplatesErrors.InvalidKlingModel);
        }

        return Result.Success();
    }

    private Result ValidateActivation(TemplateItem template)
    {
        if (GetAsset(template, TemplateAssetKind.Preview) is null)
        {
            return Result.Failure(TemplatesErrors.MissingPreview);
        }

        if (template.TemplateType == TemplateType.Video)
        {
            if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceMotion);
            }

            if (!template.ReferenceVideoDurationSeconds.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingReferenceDuration);
            }

            if (!template.CharacterOrientation.HasValue)
            {
                return Result.Failure(TemplatesErrors.MissingCharacterOrientation);
            }
        }

        return Result.Success();
    }

    private static Result<TemplateStatus> ResolveRequestedStatus(string? rawStatus, TemplateStatus fallback)
    {
        if (string.IsNullOrWhiteSpace(rawStatus))
        {
            return Result.Success(fallback);
        }

        return Enum.TryParse<TemplateStatus>(rawStatus, true, out var status)
            ? Result.Success(status)
            : Result.Failure<TemplateStatus>(TemplatesErrors.InvalidStatus);
    }

    private async Task<(double? duration, CharacterOrientation? orientation)> ResolveReferenceMetadataAsync(TemplateAssetCommand? asset, CancellationToken cancellationToken)
    {
        if (asset is null)
        {
            return (null, null);
        }

        var durationResult = await metadataReader.GetVideoDurationSecondsAsync(asset, cancellationToken);
        if (durationResult.IsFailure || !durationResult.Value.HasValue)
        {
            return (null, null);
        }

        var duration = Math.Round(durationResult.Value.Value, 2, MidpointRounding.AwayFromZero);
        var orientation = duration <= 10 ? CharacterOrientation.Image : CharacterOrientation.Video;
        return (duration, orientation);
    }

    private Task<TemplateItem?> FindTemplateAsync(Guid templateId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateItems
            .Include(x => x.Assets)
            .FirstOrDefaultAsync(x => x.Id == templateId, cancellationToken);
    }

    private static string[] NormalizeTags(IEnumerable<string> tags)
    {
        return tags
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string SerializeTags(IEnumerable<string> tags)
    {
        return string.Join(',', NormalizeTags(tags));
    }

    private static string[] DeserializeTags(string tags)
    {
        return NormalizeTags(tags.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries));
    }

    private static string ResolvePrompt(string prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    private async Task CleanupObsoleteMediaAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                await mediaLifecycleService.MarkCleanupFailureAsync(assetUrl, deleteResult.Error.Code, deleteResult.Error.Message, cancellationToken);
                continue;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);
    }

    private static AdminTemplateStatisticsResponse MapAdminStatisticsResponse(Guid templateId, IReadOnlyCollection<GenerationStatisticsProjection> jobs)
    {
        var totalRuns = jobs.Count;
        var queuedRuns = jobs.Count(x => x.Status == TemplateGenerationStatus.Queued);
        var processingRuns = jobs.Count(x => x.Status == TemplateGenerationStatus.Processing);
        var completedRuns = jobs.Count(x => x.Status == TemplateGenerationStatus.Completed);
        var failedRuns = jobs.Count(x => x.Status == TemplateGenerationStatus.Failed);
        var totalTokenCost = jobs.Sum(x => x.TokenCost);
        var averageTokenCost = totalRuns == 0
            ? 0
            : Math.Round(jobs.Average(x => x.TokenCost), 1, MidpointRounding.AwayFromZero);
        var totalProviderCostUsd = jobs.Sum(x => x.MotionProviderCostUsd ?? 0m);
        var providerCostSamples = jobs
            .Where(x => x.MotionProviderCostUsd.HasValue)
            .Select(x => x.MotionProviderCostUsd!.Value)
            .ToArray();
        var averageProviderCostUsd = providerCostSamples.Length == 0
            ? 0m
            : Math.Round(providerCostSamples.Average(), 4, MidpointRounding.AwayFromZero);
        var successRatePercent = totalRuns == 0
            ? 0
            : Math.Round((double)completedRuns * 100 / totalRuns, 1, MidpointRounding.AwayFromZero);
        DateTime? lastRunAtUtc = totalRuns == 0 ? null : jobs.Max(x => x.CreatedAtUtc);
        var completedAtValues = jobs
            .Where(x => x.CompletedAtUtc.HasValue && x.Status == TemplateGenerationStatus.Completed)
            .Select(x => x.CompletedAtUtc!.Value)
            .ToArray();
        DateTime? lastCompletedAtUtc = completedAtValues.Length == 0 ? null : completedAtValues.Max();
        var completedDurations = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Completed && x.StartedAtUtc.HasValue && x.CompletedAtUtc.HasValue)
            .Select(x => (x.CompletedAtUtc!.Value - x.StartedAtUtc!.Value).TotalSeconds)
            .Where(x => x >= 0)
            .ToArray();
        double? averageGenerationSeconds = completedDurations.Length == 0
            ? null
            : Math.Round(completedDurations.Average(), 1, MidpointRounding.AwayFromZero);

        return new AdminTemplateStatisticsResponse(
            templateId,
            totalRuns,
            queuedRuns,
            processingRuns,
            completedRuns,
            failedRuns,
            successRatePercent,
            totalTokenCost,
            averageTokenCost,
            Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
            averageProviderCostUsd,
            lastRunAtUtc,
            lastCompletedAtUtc,
            averageGenerationSeconds);
    }

    private static AdminTemplatesAnalyticsTemplateRowResponse BuildTemplatesAnalyticsRow(
        TemplateItem template,
        IReadOnlyCollection<GenerationAnalyticsProjection> jobs,
        IReadOnlyCollection<TemplateAnalyticsEvent> events)
    {
        var starts = jobs.Count;
        var completed = jobs.Count(x => x.Status == TemplateGenerationStatus.Completed);
        var failed = jobs.Count(x => x.Status == TemplateGenerationStatus.Failed);
        var totalTokenCost = jobs.Sum(x => x.TokenCost);
        var totalProviderCostUsd = jobs.Sum(x => x.MotionProviderCostUsd ?? 0m);

        return new AdminTemplatesAnalyticsTemplateRowResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.Category,
            template.Status.ToString(),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            events.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View)),
            starts,
            completed,
            failed,
            CalculatePercent(completed, starts),
            totalTokenCost,
            Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero),
            template.UpdatedAtUtc);
    }

    private static IReadOnlyList<AdminTemplatesAnalyticsTrendPointResponse> BuildTemplatesAnalyticsTrend(
        IReadOnlyCollection<GenerationAnalyticsProjection> jobs,
        IReadOnlyCollection<TemplateAnalyticsEvent> events)
    {
        var jobsByDay = jobs
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());
        var eventsByDay = events
            .GroupBy(x => x.CreatedAtUtc.Date)
            .ToDictionary(x => x.Key, x => x.ToArray());

        return jobsByDay.Keys
            .Concat(eventsByDay.Keys)
            .Distinct()
            .OrderBy(x => x)
            .Select(day =>
            {
                var dayJobs = jobsByDay.GetValueOrDefault(day) ?? [];
                var dayEvents = eventsByDay.GetValueOrDefault(day) ?? [];
                var totalTokenCost = dayJobs.Sum(x => x.TokenCost);
                var totalProviderCostUsd = dayJobs.Sum(x => x.MotionProviderCostUsd ?? 0m);

                return new AdminTemplatesAnalyticsTrendPointResponse(
                    DateTime.SpecifyKind(day, DateTimeKind.Utc),
                    dayEvents.Count(x => IsAnalyticsEventType(x, TemplateAnalyticsEventTypes.View)),
                    dayJobs.Length,
                    dayJobs.Count(x => x.Status == TemplateGenerationStatus.Completed),
                    dayJobs.Count(x => x.Status == TemplateGenerationStatus.Failed),
                    totalTokenCost,
                    Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero));
            })
            .ToArray();
    }

    private static IReadOnlyList<AdminTemplatesAnalyticsBreakdownResponse> BuildTemplatesAnalyticsBreakdown(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        Func<AdminTemplatesAnalyticsTemplateRowResponse, string> selector)
    {
        return rows
            .GroupBy(row => NormalizeAnalyticsValue(selector(row), "unknown", 128))
            .OrderByDescending(group => group.Sum(x => x.Views))
            .ThenByDescending(group => group.Sum(x => x.GenerationStarts))
            .ThenBy(group => group.Key)
            .Select(group =>
            {
                var starts = group.Sum(x => x.GenerationStarts);
                var completed = group.Sum(x => x.CompletedGenerations);
                var totalTokenCost = group.Sum(x => x.TotalTokenCost);
                var totalProviderCostUsd = group.Sum(x => x.TotalProviderCostUsd);

                return new AdminTemplatesAnalyticsBreakdownResponse(
                    group.Key,
                    FormatDimensionLabel(group.Key),
                    group.Count(),
                    group.Sum(x => x.Views),
                    starts,
                    completed,
                    CalculatePercent(completed, starts),
                    totalTokenCost,
                        Math.Round(totalProviderCostUsd, 4, MidpointRounding.AwayFromZero));
            })
            .ToArray();
    }

    private static IEnumerable<AdminTemplatesAnalyticsTemplateRowResponse> SortTemplatesAnalyticsRows(
        IReadOnlyCollection<AdminTemplatesAnalyticsTemplateRowResponse> rows,
        string? sort)
    {
        var normalizedSort = NormalizeAnalyticsFilter(sort) ?? "views";
        IOrderedEnumerable<AdminTemplatesAnalyticsTemplateRowResponse> ordered = normalizedSort switch
        {
            "starts" => rows.OrderByDescending(x => x.GenerationStarts),
            "conversion" => rows.OrderByDescending(x => x.ConversionPercent),
            "cost" => rows.OrderByDescending(x => x.TotalProviderCostUsd),
            "tokens" => rows.OrderByDescending(x => x.TotalTokenCost),
            "updated" => rows.OrderByDescending(x => x.UpdatedAtUtc),
            _ => rows.OrderByDescending(x => x.Views),
        };

        return ordered.ThenBy(x => x.Title);
    }

    private static TemplateType? ParseTemplateTypeFilter(string? raw)
    {
        return Enum.TryParse<TemplateType>(raw, true, out var templateType) ? templateType : null;
    }

    private static TemplateStatus? ParseTemplateStatusFilter(string? raw)
    {
        return Enum.TryParse<TemplateStatus>(raw, true, out var templateStatus) ? templateStatus : null;
    }

    private static string? NormalizeAnalyticsFilter(string? raw)
    {
        return string.IsNullOrWhiteSpace(raw) ? null : raw.Trim().ToLowerInvariant();
    }

    private static double CalculatePercent(int numerator, int denominator)
    {
        return denominator == 0
            ? 0
            : Math.Round((double)numerator * 100 / denominator, 1, MidpointRounding.AwayFromZero);
    }

    private static bool IsAnalyticsEventType(TemplateAnalyticsEvent analyticsEvent, string eventType)
    {
        return string.Equals(analyticsEvent.EventType, eventType, StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsFeedbackEvent(TemplateAnalyticsEvent analyticsEvent)
    {
        return IsAnalyticsEventType(analyticsEvent, TemplateAnalyticsEventTypes.Complaint)
            || IsAnalyticsEventType(analyticsEvent, TemplateAnalyticsEventTypes.Feedback);
    }

    private async Task<GenerationAnalyticsProjection[]?> GetAnalyticsProjectionsAsync(Guid templateId, CancellationToken cancellationToken)
    {
        var templateExists = await dbContext.TemplateItems
            .AsNoTracking()
            .AnyAsync(x => x.Id == templateId, cancellationToken);

        if (!templateExists)
        {
            return null;
        }

        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.TemplateId == templateId)
            .Select(x => new GenerationAnalyticsProjection(
                x.Id,
                x.TemplateId,
                x.UserId,
                x.Status,
                x.TokenCost,
                x.AttemptCount,
                x.UsedPreprocessingModel,
                x.UsedKlingModel,
                x.MotionProviderCostUsd,
                x.FailureCode,
                x.FailureMessage,
                x.OutputUrl,
                x.CreatedAtUtc,
                x.StartedAtUtc,
                x.CompletedAtUtc))
            .ToArrayAsync(cancellationToken);
    }

    private static IReadOnlyList<AdminTemplateAnalyticsDimensionResponse> BuildDimension(
        IReadOnlyCollection<TemplateAnalyticsEvent> events,
        Func<TemplateAnalyticsEvent, string> selector,
        string fallback)
    {
        if (events.Count == 0)
        {
            return [];
        }

        return events
            .Select(selector)
            .Select(value => NormalizeAnalyticsValue(value, fallback, 64))
            .GroupBy(value => value)
            .OrderByDescending(group => group.Count())
            .ThenBy(group => group.Key)
            .Select(group => new AdminTemplateAnalyticsDimensionResponse(
                group.Key,
                FormatDimensionLabel(group.Key),
                group.Count(),
                Math.Round((double)group.Count() * 100 / events.Count, 1, MidpointRounding.AwayFromZero)))
            .ToArray();
    }

    private static string NormalizeAnalyticsValue(string? value, string fallback, int maxLength)
    {
        var normalized = string.IsNullOrWhiteSpace(value)
            ? fallback
            : value.Trim().ToLowerInvariant();

        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string? NormalizeOptionalText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static string FormatDimensionLabel(string key) => key switch
    {
        "home" => "Home",
        "categories" => "Categories",
        "search" => "Search",
        "profile" => "Profile",
        "direct" => "Direct",
        "ios" => "iOS",
        "android" => "Android",
        "web" => "Web",
        "bot" => "Bot",
        "unknown" => "Unknown",
        _ when key.Length <= 3 => key.ToUpperInvariant(),
        _ => CultureInfo.InvariantCulture.TextInfo.ToTitleCase(key.Replace('-', ' ').Replace('_', ' '))
    };

    private async Task<Result> DeleteTemplateAssetsAsync(string[] assetUrls, CancellationToken cancellationToken)
    {
        foreach (var assetUrl in assetUrls)
        {
            var deleteResult = await mediaStorage.DeleteAsync(assetUrl, cancellationToken);
            if (deleteResult.IsFailure)
            {
                return deleteResult;
            }

            await mediaLifecycleService.MarkDeletedAsync(assetUrl, cancellationToken);
        }

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);

        return Result.Success();
    }

    private static string[] CollectObsoleteAssetUrls(IEnumerable<string?> assetUrls)
    {
        return assetUrls
            .Where(assetUrl => !string.IsNullOrWhiteSpace(assetUrl))
            .Cast<string>()
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string? SetAsset(TemplateItem template, TemplateAssetKind assetKind, TemplateAssetCommand? asset)
    {
        var existing = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        if (asset is null)
        {
            if (existing is not null)
            {
                var removedUrl = existing.Url;
                template.Assets.Remove(existing);
                return removedUrl;
            }

            return null;
        }

        if (existing is null)
        {
            existing = new TemplateAsset
            {
                Id = Guid.NewGuid(),
                TemplateId = template.Id,
                AssetKind = assetKind
            };
            template.Assets.Add(existing);
        }

        var obsoleteUrl = !string.IsNullOrWhiteSpace(existing.Url)
            && !string.Equals(existing.Url, asset.Url, StringComparison.OrdinalIgnoreCase)
                ? existing.Url
                : null;

        existing.Url = asset.Url;
        existing.FileName = asset.FileName;
        existing.ContentType = asset.ContentType;
        existing.FileSizeBytes = asset.FileSizeBytes;
        existing.DurationSeconds = asset.DurationSeconds;

        return obsoleteUrl;
    }

    private static TemplateAssetResponse? GetAsset(TemplateItem template, TemplateAssetKind assetKind)
    {
        var asset = template.Assets.FirstOrDefault(x => x.AssetKind == assetKind);
        return asset is null
            ? null
            : new TemplateAssetResponse(asset.Url, asset.FileName, asset.ContentType, asset.FileSizeBytes, asset.DurationSeconds);
    }

    private static AdminTemplateListItemResponse MapAdminListItem(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
                template.MusicDescription,
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }

    private static AdminTemplateResponse MapAdminResponse(TemplateItem template)
    {
        var effectivePromoBadge = ResolveEffectivePromoBadge(template, DateTime.UtcNow);

        return new AdminTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Status.ToString(),
            template.PromoBadgeMode.ToString(),
            effectivePromoBadge,
            template.IsPremium,
            template.TokenCost,
            DeserializeTags(template.Tags),
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            GetAsset(template, TemplateAssetKind.ReferenceMotion),
            template.ReferenceVideoDurationSeconds,
            template.CharacterOrientation?.ToString(),
            template.PreprocessingModel,
            template.PreprocessingPrompt,
            template.KlingModel,
            template.KlingPrompt,
            template.KeepOriginalSound,
            FalModelPricing.TryCalculateEstimatedGenerationCostUsd(
                template.PreprocessingModel,
                template.KlingModel,
                template.ReferenceVideoDurationSeconds),
            template.CreatedAtUtc,
            template.UpdatedAtUtc);
    }

    private static PublicTemplateListItemResponse MapPublicListItem(TemplateItem template)
    {
        return new PublicTemplateListItemResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.ReferenceVideoDurationSeconds);
    }

    private static PublicTemplateResponse MapPublicResponse(TemplateItem template)
    {
        return new PublicTemplateResponse(
            template.Id,
            template.TemplateType.ToString(),
            template.Title,
            template.ShortDescription,
            template.Category,
            ResolveEffectivePromoBadge(template, DateTime.UtcNow),
            DeserializeTags(template.Tags),
            template.IsPremium,
            template.TokenCost,
            GetAsset(template, TemplateAssetKind.Preview),
            template.MusicDescription,
            template.ReferenceVideoDurationSeconds);
    }

    private static TemplatePromoBadgeMode ParsePromoBadgeMode(string raw)
    {
        return Enum.TryParse<TemplatePromoBadgeMode>(raw, true, out var mode)
            ? mode
            : TemplatePromoBadgeMode.Auto;
    }

    private static string? ResolveEffectivePromoBadge(TemplateItem template, DateTime utcNow)
    {
        if (template.PromoBadgeMode != TemplatePromoBadgeMode.Auto)
        {
            return template.PromoBadgeMode.ToString();
        }

        if (template.CreatedAtUtc >= utcNow.AddDays(-30))
        {
            return TemplatePromoBadgeMode.New.ToString();
        }

        if (template.Status == TemplateStatus.Active && template.UpdatedAtUtc >= utcNow.AddDays(-14))
        {
            return TemplatePromoBadgeMode.Trending.ToString();
        }

        if (template.Status == TemplateStatus.Active && (template.IsPremium || template.TokenCost >= 60))
        {
            return TemplatePromoBadgeMode.Popular.ToString();
        }

        var searchText = string.Join(' ', [
            template.Title,
            template.ShortDescription,
            template.Category,
            template.Tags,
            template.MusicDescription ?? string.Empty,
            template.KlingPrompt ?? string.Empty
        ]).ToLowerInvariant();

        return TemplatePromoBadgeRules.FunnyKeywords.Any(keyword => searchText.Contains(keyword, StringComparison.Ordinal))
            ? TemplatePromoBadgeMode.Funny.ToString()
            : null;
    }
}
