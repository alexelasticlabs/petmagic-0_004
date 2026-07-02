using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        return await GetAsync(userId, generationId, isPremium: false, cancellationToken);
    }

    public async Task<Result<TemplateGenerationResponse>> GetAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        return job is null
            ? Result.Failure<TemplateGenerationResponse>(TemplatesErrors.GenerationJobNotFound)
            : Result.Success(await MapResponseWithQueueMetricsAsync(job, cancellationToken, isPremium));
    }

    public async Task<Result<IReadOnlyList<TemplateGenerationResponse>>> ListAsync(Guid userId, TemplateGenerationHistoryQuery query, bool isPremium, CancellationToken cancellationToken)
    {
        var skip = Math.Clamp(query.Skip ?? 0, 0, 10_000);
        var take = Math.Clamp(query.Take ?? 30, 1, 100);

        var generationsQuery = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Include(x => x.MediaRecords)
            .Where(x => x.UserId == userId && x.HiddenByUserAtUtc == null);

        generationsQuery = ApplyStatusFilter(generationsQuery, query.Status);

        var jobs = await generationsQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(skip)
            .Take(take)
            .ToArrayAsync(cancellationToken);

        return Result.Success<IReadOnlyList<TemplateGenerationResponse>>(
            await MapResponsesWithQueueMetricsAsync(jobs, cancellationToken, isPremium));
    }

    public async Task<Result<GalleryPageResponse>> ListPageAsync(Guid userId, TemplateGenerationHistoryQuery query, bool isPremium, CancellationToken cancellationToken)
    {
        var take = Math.Clamp(query.Take ?? 50, 1, 100);
        var appliedFilter = NormalizeGalleryFilter(query.Status);

        var generationsQuery = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Include(x => x.Template)
            .Include(x => x.WatermarkUnlocks)
            .Include(x => x.MediaRecords)
            .Where(x => x.UserId == userId && x.HiddenByUserAtUtc == null);

        generationsQuery = ApplyStatusFilter(generationsQuery, appliedFilter);

        if (!string.IsNullOrWhiteSpace(query.Cursor))
        {
            var cursor = TryDecodeGalleryCursor(query.Cursor);
            if (cursor is null)
            {
                return Result.Failure<GalleryPageResponse>(TemplatesErrors.InvalidGalleryCursor);
            }

            generationsQuery = generationsQuery.Where(x =>
                x.CreatedAtUtc < cursor.CreatedAtUtc
                || (x.CreatedAtUtc == cursor.CreatedAtUtc && x.Id.CompareTo(cursor.Id) < 0));
        }

        var jobs = await generationsQuery
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(take + 1)
            .ToArrayAsync(cancellationToken);

        var hasMore = jobs.Length > take;
        var pageJobs = hasMore
            ? jobs.Take(take).ToArray()
            : jobs;
        var items = await MapGalleryItemsWithQueueMetricsAsync(pageJobs, cancellationToken, isPremium);
        var unreadCount = await CountUnreadGenerationsAsync(userId, cancellationToken);

        return Result.Success(new GalleryPageResponse(
            items,
            hasMore && pageJobs.Length > 0 ? EncodeGalleryCursor(pageJobs[^1]) : null,
            hasMore,
            DateTime.UtcNow,
            unreadCount,
            appliedFilter));
    }

    public async Task<Result<TemplateGenerationUnreadCountResponse>> GetUnreadCountAsync(Guid userId, CancellationToken cancellationToken)
    {
        var count = await CountUnreadGenerationsAsync(userId, cancellationToken);

        return Result.Success(new TemplateGenerationUnreadCountResponse(count));
    }

    private Task<int> CountUnreadGenerationsAsync(Guid userId, CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.UserId == userId
                && x.HiddenByUserAtUtc == null
                && x.Status == TemplateGenerationStatus.Completed
                && x.ResultViewedAtUtc == null,
                cancellationToken);
    }

    private static string NormalizeGalleryFilter(string? rawStatus)
    {
        var normalized = rawStatus?.Trim().ToLowerInvariant();
        return string.IsNullOrWhiteSpace(normalized) ? "all" : normalized;
    }

    private static string EncodeGalleryCursor(TemplateGenerationJob job)
    {
        var payload = JsonSerializer.Serialize(new GalleryCursor(job.CreatedAtUtc, job.Id));
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(payload))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static GalleryCursor? TryDecodeGalleryCursor(string rawCursor)
    {
        try
        {
            var padded = rawCursor.Trim().Replace('-', '+').Replace('_', '/');
            var padding = padded.Length % 4;
            if (padding > 0)
            {
                padded = padded.PadRight(padded.Length + 4 - padding, '=');
            }

            return JsonSerializer.Deserialize<GalleryCursor>(Encoding.UTF8.GetString(Convert.FromBase64String(padded)));
        }
        catch (Exception)
        {
            return null;
        }
    }

    private sealed record GalleryCursor(DateTime CreatedAtUtc, Guid Id);

    public async Task<Result> MarkReadAsync(Guid userId, Guid generationId, bool isPremium, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(
                x => x.Id == generationId
                    && x.UserId == userId
                    && x.HiddenByUserAtUtc == null,
                cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var now = DateTime.UtcNow;
        if (job.ResultViewedAtUtc is null)
        {
            job.ResultViewedAtUtc = now;
            AddAnalyticsEvent(
                job,
                TemplateAnalyticsEventTypes.ResultViewed,
                isPremium ? "premium" : "free");
        }

        job.UpdatedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> DeleteAsync(Guid userId, Guid generationId, CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);

        if (job is null || job.HiddenByUserAtUtc != null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var now = DateTime.UtcNow;
        job.HiddenByUserAtUtc = now;
        job.UpdatedAtUtc = now;
        job.ResultViewedAtUtc ??= now;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RecordFeedbackAsync(RecordTemplateGenerationFeedbackCommand command, CancellationToken cancellationToken)
    {
        if (command.Rating is < 1 or > 3)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .FirstOrDefaultAsync(x => x.Id == command.GenerationId && x.UserId == command.UserId, cancellationToken);

        if (job is null)
        {
            return Result.Failure(TemplatesErrors.GenerationJobNotFound);
        }

        var reasons = NormalizeFeedbackReasons(command.SelectedReasons);
        if (reasons.Length > 8)
        {
            return Result.Failure(TemplatesErrors.InvalidFeedback);
        }

        dbContext.TemplateGenerationFeedback.Add(new TemplateGenerationFeedback
        {
            Id = Guid.NewGuid(),
            GenerationId = job.Id,
            UserId = job.UserId,
            Type = "GenerationResult",
            Category = reasons.FirstOrDefault() ?? (command.Rating == 3 ? "good" : command.Rating == 2 ? "okay" : "bad"),
            TemplateId = job.TemplateId,
            Rating = command.Rating switch
            {
                3 => 1,
                2 => 0,
                _ => -1
            },
            Message = NormalizeOptionalText(command.Comment, 2000),
            PetId = job.PetId,
            SourceScreen = "generation_status",
            ErrorCode = job.LastErrorCode,
            ProviderName = ResolveProviderRequestId(job) is null ? null : "fal",
            Status = "New",
            Priority = command.Rating == 1 ? "Medium" : "Low",
            SelectedReasons = JsonSerializer.Serialize(reasons),
            Comment = NormalizeOptionalText(command.Comment, 2000),
            InputPhotoQualityScore = command.InputPhotoQualityScore,
            ModelUsed = ResolveFeedbackModel(job),
            GenerationDurationSeconds = ResolveGenerationDurationSeconds(job),
            ProviderRequestId = ResolveProviderRequestId(job),
            CreatedAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }
}
