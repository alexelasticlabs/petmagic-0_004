using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private const int AdminGenerationsDefaultTake = 25;
    private const int AdminGenerationsMaxTake = 100;

    public async Task<Result<AdminTemplateGenerationDashboardMetricsResponse>> GetAdminGenerationDashboardMetricsAsync(
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var todayStart = now.Date;
        var weekStart = todayStart.AddDays(-6);
        var monthStart = todayStart.AddDays(-29);

        var periodCounts = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job => job.CreatedAtUtc >= monthStart)
            .GroupBy(_ => 1)
            .Select(group => new
            {
                GenerationsToday = group.Count(job => job.CreatedAtUtc >= todayStart),
                GenerationsThisWeek = group.Count(job => job.CreatedAtUtc >= weekStart),
                GenerationsThisMonth = group.Count(),
                FailedGenerationsToday = group.Count(job => job.Status == TemplateGenerationStatus.Failed && job.CreatedAtUtc >= todayStart),
                FailedGenerationsThisWeek = group.Count(job => job.Status == TemplateGenerationStatus.Failed && job.CreatedAtUtc >= weekStart),
                FailedGenerationsThisMonth = group.Count(job => job.Status == TemplateGenerationStatus.Failed)
            })
            .FirstOrDefaultAsync(cancellationToken);
        var statusCounts = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .GroupBy(job => job.Status)
            .Select(group => new
            {
                Status = group.Key,
                Count = group.Count()
            })
            .ToListAsync(cancellationToken);
        var statusCountByStatus = statusCounts.ToDictionary(row => row.Status, row => row.Count);

        return Result.Success(new AdminTemplateGenerationDashboardMetricsResponse(
            TotalJobs: statusCounts.Sum(row => row.Count),
            GenerationsToday: periodCounts?.GenerationsToday ?? 0,
            GenerationsThisWeek: periodCounts?.GenerationsThisWeek ?? 0,
            GenerationsThisMonth: periodCounts?.GenerationsThisMonth ?? 0,
            FailedGenerationsToday: periodCounts?.FailedGenerationsToday ?? 0,
            FailedGenerationsThisWeek: periodCounts?.FailedGenerationsThisWeek ?? 0,
            FailedGenerationsThisMonth: periodCounts?.FailedGenerationsThisMonth ?? 0,
            PendingJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Queued),
            RunningJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Processing),
            CompletedJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Completed),
            FailedJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Failed),
            CancelledJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Cancelled),
            RetryingJobs: statusCountByStatus.GetValueOrDefault(TemplateGenerationStatus.Retrying),
            GeneratedAtUtc: now));
    }

    public async Task<Result<AdminTemplateGenerationListPageResponse>> ListAdminGenerationsAsync(
        AdminTemplateGenerationsQuery query,
        CancellationToken cancellationToken)
    {
        var skip = Math.Max(0, query.Skip ?? 0);
        var take = Math.Clamp(query.Take ?? AdminGenerationsDefaultTake, 1, AdminGenerationsMaxTake);
        var status = ParseAdminGenerationStatus(query.Status);
        var provider = NormalizeQueryValue(query.Provider);
        var user = NormalizeQueryValue(query.User);
        var search = NormalizeQueryValue(query.Search);

        var generations = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .AsQueryable();

        if (status.HasValue)
        {
            generations = generations.Where(job => job.Status == status.Value);
        }

        if (!string.IsNullOrEmpty(provider))
        {
            generations = generations.Where(job =>
                (job.UsedPreprocessingModel != null && job.UsedPreprocessingModel.ToLower().Contains(provider)) ||
                (job.UsedKlingModel != null && job.UsedKlingModel.ToLower().Contains(provider)));
        }

        if (!string.IsNullOrEmpty(user))
        {
            if (Guid.TryParse(user, out var userId))
            {
                generations = generations.Where(job => job.UserId == userId);
            }
            else
            {
                generations = generations.Where(_ => false);
            }
        }

        if (!string.IsNullOrEmpty(search))
        {
            generations = generations.Where(job => job.Id.ToString().ToLower().Contains(search));
        }

        var totalCount = await generations.CountAsync(cancellationToken);
        var rows = await generations
            .OrderByDescending(job => job.CreatedAtUtc)
            .ThenByDescending(job => job.Id)
            .Skip(skip)
            .Take(take)
            .Select(job => new AdminGenerationPageRow(
                job.Id,
                job.UserId,
                job.TemplateId,
                job.Template.Title,
                job.Template.TemplateType.ToString(),
                job.Status,
                job.UsedKlingModel ?? job.UsedPreprocessingModel,
                job.TokenCost,
                job.AttemptCount,
                job.MotionProviderCostUsd,
                job.LastErrorCode,
                job.LastErrorMessage,
                job.CreatedAtUtc,
                job.UpdatedAtUtc,
                job.StartedAtUtc,
                job.CompletedAtUtc,
                job.RefundedAtUtc,
                job.IsWatermarkRequired,
                job.IsWatermarkRemoved,
                job.WatermarkedResultUrl,
                job.ParentGenerationId,
                job.ParentGenerationResultId,
                string.IsNullOrWhiteSpace(job.InputSourceType) ? "user_upload" : job.InputSourceType,
                job.InputMediaAssetId,
                job.ResultMediaAssetId,
                job.SimilarToGenerationId,
                job.GenerationMode,
                job.VariationStrength,
                job.GenerationSeed,
                job.PromptBeforeVariation,
                job.PromptAfterVariation,
                job.PetId,
                job.PetPhotoId))
            .ToListAsync(cancellationToken);

        var rowIds = rows.Select(row => row.GenerationId).ToArray();
        var latestUnlocksByGenerationId = await LoadLatestAdminWatermarkUnlocksAsync(rowIds, cancellationToken);
        var parentInfoByGenerationId = await LoadAdminGenerationParentInfoAsync(rows, cancellationToken);
        var childCountsByGenerationId = await LoadAdminGenerationChildCountsAsync(rowIds, cancellationToken);
        var inputPreviewsByGenerationId = await LoadAdminGenerationInputPreviewsAsync(rows, cancellationToken);
        var resultPreviewsByGenerationId = await LoadAdminGenerationResultPreviewsAsync(rows, cancellationToken);

        var items = rows
            .Select(row =>
            {
                latestUnlocksByGenerationId.TryGetValue(row.GenerationId, out var unlock);
                parentInfoByGenerationId.TryGetValue(row.ParentGenerationId ?? Guid.Empty, out var parentInfo);
                childCountsByGenerationId.TryGetValue(row.GenerationId, out var childCount);
                inputPreviewsByGenerationId.TryGetValue(row.GenerationId, out var inputPreviewUrl);
                resultPreviewsByGenerationId.TryGetValue(row.GenerationId, out var resultPreviewUrl);

                return new AdminTemplateGenerationListItemResponse(
                    row.GenerationId,
                    row.UserId,
                    row.TemplateId,
                    row.TemplateTitle,
                    row.TemplateType,
                    MapAdminGenerationStatus(row.Status),
                    ResolveAdminGenerationProvider(row.Model),
                    row.Model,
                    row.TokenCost,
                    row.AttemptCount,
                    row.ProviderCostUsd,
                    row.FailureCode,
                    SanitizeAdminFailureMessage(row.FailureMessage),
                    row.CreatedAtUtc,
                    row.UpdatedAtUtc,
                    row.StartedAtUtc,
                    row.CompletedAtUtc,
                    row.RefundedAtUtc,
                    row.IsWatermarkRequired,
                    row.IsWatermarkRemoved,
                    row.WatermarkedMediaPath,
                    unlock?.UnlockMethod,
                    unlock?.UnlockedByUserId,
                    unlock?.CreditsSpent,
                    unlock?.CreatedAtUtc,
                    row.ParentGenerationId,
                    row.ParentGenerationResultId,
                    row.InputSourceType,
                    row.InputMediaAssetId,
                    row.ResultMediaAssetId,
                    inputPreviewUrl,
                    resultPreviewUrl,
                    false,
                    parentInfo?.TemplateTitle,
                    parentInfo?.TemplateType,
                    childCount,
                    row.SimilarToGenerationId,
                    row.GenerationMode.ToString().ToLower(),
                    row.VariationStrength,
                    row.GenerationSeed,
                    row.PromptBeforeVariation,
                    row.PromptAfterVariation,
                    row.PetId,
                    row.PetPhotoId);
            })
            .ToArray();

        return Result.Success(new AdminTemplateGenerationListPageResponse(
            items,
            totalCount,
            skip,
            take,
            skip + items.Length < totalCount,
            DateTime.UtcNow));
    }

    private async Task<IReadOnlyDictionary<Guid, AdminGenerationWatermarkUnlockRow>> LoadLatestAdminWatermarkUnlocksAsync(
        IReadOnlyCollection<Guid> generationIds,
        CancellationToken cancellationToken)
    {
        if (generationIds.Count == 0)
        {
            return new Dictionary<Guid, AdminGenerationWatermarkUnlockRow>();
        }

        var unlocks = await dbContext.TemplateGenerationWatermarkUnlocks
            .AsNoTracking()
            .Where(unlock => generationIds.Contains(unlock.GenerationJobId))
            .OrderByDescending(unlock => unlock.CreatedAtUtc)
            .ThenByDescending(unlock => unlock.Id)
            .Select(unlock => new AdminGenerationWatermarkUnlockRow(
                unlock.GenerationJobId,
                unlock.UnlockMethod.ToString().ToLower(),
                unlock.UnlockedByUserId ?? unlock.UserId,
                unlock.CreditsSpent,
                unlock.CreatedAtUtc))
            .ToListAsync(cancellationToken);

        return unlocks
            .GroupBy(unlock => unlock.GenerationId)
            .ToDictionary(group => group.Key, group => group.First());
    }

    private async Task<IReadOnlyDictionary<Guid, AdminGenerationParentInfoRow>> LoadAdminGenerationParentInfoAsync(
        IReadOnlyCollection<AdminGenerationPageRow> rows,
        CancellationToken cancellationToken)
    {
        var parentIds = rows
            .Select(row => row.ParentGenerationId)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToArray();

        if (parentIds.Length == 0)
        {
            return new Dictionary<Guid, AdminGenerationParentInfoRow>();
        }

        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(parent => parentIds.Contains(parent.Id))
            .Select(parent => new AdminGenerationParentInfoRow(
                parent.Id,
                parent.Template.Title,
                parent.Template.TemplateType.ToString()))
            .ToDictionaryAsync(parent => parent.GenerationId, cancellationToken);
    }

    private async Task<IReadOnlyDictionary<Guid, int>> LoadAdminGenerationChildCountsAsync(
        IReadOnlyCollection<Guid> generationIds,
        CancellationToken cancellationToken)
    {
        if (generationIds.Count == 0)
        {
            return new Dictionary<Guid, int>();
        }

        return await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(child => child.ParentGenerationId.HasValue
                && generationIds.Contains(child.ParentGenerationId.Value))
            .GroupBy(child => child.ParentGenerationId!.Value)
            .Select(group => new
            {
                GenerationId = group.Key,
                Count = group.Count()
            })
            .ToDictionaryAsync(row => row.GenerationId, row => row.Count, cancellationToken);
    }

    private async Task<IReadOnlyDictionary<Guid, string?>> LoadAdminGenerationInputPreviewsAsync(
        IReadOnlyCollection<AdminGenerationPageRow> rows,
        CancellationToken cancellationToken)
    {
        if (rows.Count == 0)
        {
            return new Dictionary<Guid, string?>();
        }

        var previewsByGenerationId = new Dictionary<Guid, string?>();
        var petPhotoIds = rows
            .Where(row => string.Equals(row.InputSourceType, "pet_photo", StringComparison.Ordinal)
                && row.PetPhotoId.HasValue)
            .Select(row => row.PetPhotoId!.Value)
            .Distinct()
            .ToArray();

        if (petPhotoIds.Length > 0)
        {
            var petPhotoPreviews = await dbContext.PetPhotos
                .AsNoTracking()
                .Where(photo => petPhotoIds.Contains(photo.Id)
                    && !photo.IsDeleted
                    && !photo.MediaAsset.IsDeleted)
                .Select(photo => new
                {
                    photo.Id,
                    PreviewUrl = photo.ThumbnailUrl ?? photo.MediaAsset.PreviewUrl ?? photo.MediaAsset.Url
                })
                .ToDictionaryAsync(row => row.Id, row => row.PreviewUrl, cancellationToken);

            foreach (var row in rows)
            {
                if (row.PetPhotoId.HasValue && petPhotoPreviews.TryGetValue(row.PetPhotoId.Value, out var previewUrl))
                {
                    previewsByGenerationId[row.GenerationId] = previewUrl;
                }
            }
        }

        var mediaIds = rows
            .Where(row => !string.Equals(row.InputSourceType, "pet_photo", StringComparison.Ordinal)
                && row.InputMediaAssetId.HasValue)
            .Select(row => row.InputMediaAssetId!.Value)
            .Distinct()
            .ToArray();

        if (mediaIds.Length == 0)
        {
            return previewsByGenerationId;
        }

        var mediaPreviews = await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .Where(media => mediaIds.Contains(media.Id)
                && !media.IsDeleted
                && media.MediaType == "image")
            .Select(media => new
            {
                media.Id,
                PreviewUrl = media.PreviewUrl ?? media.Url
            })
            .ToDictionaryAsync(row => row.Id, row => row.PreviewUrl, cancellationToken);

        foreach (var row in rows)
        {
            if (row.InputMediaAssetId.HasValue && mediaPreviews.TryGetValue(row.InputMediaAssetId.Value, out var previewUrl))
            {
                previewsByGenerationId[row.GenerationId] = previewUrl;
            }
        }

        return previewsByGenerationId;
    }

    private async Task<IReadOnlyDictionary<Guid, string?>> LoadAdminGenerationResultPreviewsAsync(
        IReadOnlyCollection<AdminGenerationPageRow> rows,
        CancellationToken cancellationToken)
    {
        if (rows.Count == 0)
        {
            return new Dictionary<Guid, string?>();
        }

        var generationIds = rows.Select(row => row.GenerationId).ToArray();
        var resultMediaIds = rows
            .Select(row => row.ResultMediaAssetId)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToArray();
        var mediaRows = await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .Where(media => !media.IsDeleted
                && (resultMediaIds.Contains(media.Id)
                    || (media.GenerationId.HasValue
                        && generationIds.Contains(media.GenerationId.Value)
                        && media.SourceType == "generation_result"
                        && media.MediaType == "image")))
            .Select(media => new AdminGenerationResultMediaRow(
                media.Id,
                media.GenerationId,
                media.PreviewUrl,
                media.Url,
                media.WatermarkedPreviewUrl,
                media.WatermarkedStoragePath))
            .ToListAsync(cancellationToken);

        var mediaById = mediaRows.ToDictionary(media => media.Id);
        var fallbackMediaByGenerationId = mediaRows
            .Where(media => media.GenerationId.HasValue)
            .GroupBy(media => media.GenerationId!.Value)
            .ToDictionary(group => group.Key, group => group.First());

        return rows.ToDictionary(
            row => row.GenerationId,
            row =>
            {
                AdminGenerationResultMediaRow? media = null;
                if (row.ResultMediaAssetId.HasValue)
                {
                    mediaById.TryGetValue(row.ResultMediaAssetId.Value, out media);
                }

                media ??= fallbackMediaByGenerationId.GetValueOrDefault(row.GenerationId);
                return media is null
                    ? null
                    : ResolveAdminGenerationResultPreviewUrl(row, media);
            });
    }

    private static string? ResolveAdminGenerationResultPreviewUrl(
        AdminGenerationPageRow row,
        AdminGenerationResultMediaRow media)
    {
        return row.IsWatermarkRequired && !row.IsWatermarkRemoved
            ? media.WatermarkedPreviewUrl ?? media.WatermarkedStoragePath
            : media.PreviewUrl ?? media.Url;
    }

    private static TemplateGenerationStatus? ParseAdminGenerationStatus(string? value)
    {
        var normalized = NormalizeQueryValue(value);
        return normalized switch
        {
            "" or "all" => null,
            "pending" or "queued" => TemplateGenerationStatus.Queued,
            "running" or "processing" => TemplateGenerationStatus.Processing,
            "completed" or "succeeded" or "success" => TemplateGenerationStatus.Completed,
            "failed" => TemplateGenerationStatus.Failed,
            "cancelled" or "canceled" => TemplateGenerationStatus.Cancelled,
            "retrying" => TemplateGenerationStatus.Retrying,
            _ => null
        };
    }

    private static string MapAdminGenerationStatus(TemplateGenerationStatus status)
    {
        return status switch
        {
            TemplateGenerationStatus.Queued => "Pending",
            TemplateGenerationStatus.Processing => "Running",
            TemplateGenerationStatus.Completed => "Completed",
            TemplateGenerationStatus.Failed => "Failed",
            TemplateGenerationStatus.Cancelled => "Cancelled",
            TemplateGenerationStatus.Retrying => "Retrying",
            _ => status.ToString()
        };
    }

    private static string? ResolveAdminGenerationProvider(string? model)
    {
        var trimmed = model?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return null;
        }

        var separatorIndex = trimmed.IndexOf('/');
        return separatorIndex > 0 ? trimmed[..separatorIndex] : trimmed;
    }

    private static string SanitizeAdminFailureMessage(string? value)
    {
        var trimmed = value?.Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            return string.Empty;
        }

        return trimmed.Length <= 240 ? trimmed : $"{trimmed[..240]}...";
    }

    private static string NormalizeQueryValue(string? value)
    {
        return value?.Trim().ToLowerInvariant() ?? string.Empty;
    }

    private sealed record AdminGenerationPageRow(
        Guid GenerationId,
        Guid UserId,
        Guid TemplateId,
        string TemplateTitle,
        string TemplateType,
        TemplateGenerationStatus Status,
        string? Model,
        int TokenCost,
        int AttemptCount,
        decimal? ProviderCostUsd,
        string? FailureCode,
        string? FailureMessage,
        DateTime CreatedAtUtc,
        DateTime UpdatedAtUtc,
        DateTime? StartedAtUtc,
        DateTime? CompletedAtUtc,
        DateTime? RefundedAtUtc,
        bool IsWatermarkRequired,
        bool IsWatermarkRemoved,
        string? WatermarkedMediaPath,
        Guid? ParentGenerationId,
        Guid? ParentGenerationResultId,
        string InputSourceType,
        Guid? InputMediaAssetId,
        Guid? ResultMediaAssetId,
        Guid? SimilarToGenerationId,
        TemplateGenerationMode GenerationMode,
        string? VariationStrength,
        int? GenerationSeed,
        string? PromptBeforeVariation,
        string? PromptAfterVariation,
        Guid? PetId,
        Guid? PetPhotoId);

    private sealed record AdminGenerationWatermarkUnlockRow(
        Guid GenerationId,
        string UnlockMethod,
        Guid UnlockedByUserId,
        int CreditsSpent,
        DateTime CreatedAtUtc);

    private sealed record AdminGenerationParentInfoRow(
        Guid GenerationId,
        string TemplateTitle,
        string TemplateType);

    private sealed record AdminGenerationResultMediaRow(
        Guid Id,
        Guid? GenerationId,
        string? PreviewUrl,
        string Url,
        string? WatermarkedPreviewUrl,
        string? WatermarkedStoragePath);
}
