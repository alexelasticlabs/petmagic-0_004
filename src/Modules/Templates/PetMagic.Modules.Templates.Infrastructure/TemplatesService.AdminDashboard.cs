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

        var jobs = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(job =>
                job.CreatedAtUtc >= monthStart ||
                job.Status == TemplateGenerationStatus.Queued ||
                job.Status == TemplateGenerationStatus.Processing ||
                job.Status == TemplateGenerationStatus.Retrying)
            .Select(job => new
            {
                job.CreatedAtUtc,
                job.Status
            })
            .ToListAsync(cancellationToken);
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
            GenerationsToday: jobs.Count(job => job.CreatedAtUtc >= todayStart),
            GenerationsThisWeek: jobs.Count(job => job.CreatedAtUtc >= weekStart),
            GenerationsThisMonth: jobs.Count(job => job.CreatedAtUtc >= monthStart),
            FailedGenerationsToday: jobs.Count(job => job.Status == TemplateGenerationStatus.Failed && job.CreatedAtUtc >= todayStart),
            FailedGenerationsThisWeek: jobs.Count(job => job.Status == TemplateGenerationStatus.Failed && job.CreatedAtUtc >= weekStart),
            FailedGenerationsThisMonth: jobs.Count(job => job.Status == TemplateGenerationStatus.Failed && job.CreatedAtUtc >= monthStart),
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
            .Include(job => job.Template)
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
        var items = await generations
            .OrderByDescending(job => job.CreatedAtUtc)
            .ThenByDescending(job => job.Id)
            .Skip(skip)
            .Take(take)
            .Select(job => new AdminTemplateGenerationListItemResponse(
                job.Id,
                job.UserId,
                job.TemplateId,
                job.Template.Title,
                job.Template.TemplateType.ToString(),
                MapAdminGenerationStatus(job.Status),
                ResolveAdminGenerationProvider(job.UsedKlingModel ?? job.UsedPreprocessingModel),
                job.UsedKlingModel ?? job.UsedPreprocessingModel,
                job.TokenCost,
                job.AttemptCount,
                job.MotionProviderCostUsd,
                job.LastErrorCode,
                SanitizeAdminFailureMessage(job.LastErrorMessage),
                job.CreatedAtUtc,
                job.UpdatedAtUtc,
                job.StartedAtUtc,
                job.CompletedAtUtc,
                job.RefundedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success(new AdminTemplateGenerationListPageResponse(
            items,
            totalCount,
            skip,
            take,
            skip + items.Count < totalCount,
            DateTime.UtcNow));
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
}
