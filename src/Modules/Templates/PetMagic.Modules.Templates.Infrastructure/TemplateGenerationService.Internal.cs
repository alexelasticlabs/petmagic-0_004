using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{

    private Task<TemplateGenerationJob?> FindActiveDuplicateAsync(

        Guid userId,

        string? idempotencyKey,

        string? requestHash,

        CancellationToken cancellationToken)

    {

        if (idempotencyKey is null && requestHash is null)

        {

            return Task.FromResult<TemplateGenerationJob?>(null);

        }


        return dbContext.TemplateGenerationJobs

            .AsNoTracking()

            .Include(x => x.Template)

            .Where(x => x.UserId == userId

                && TemplateGenerationJobStatusSets.Active.Contains(x.Status)
                && (x.Status != TemplateGenerationStatus.Queued
                    || x.ChargedAtUtc != null
                    || x.UserId == AdminTestUserId)

                && ((idempotencyKey != null && x.IdempotencyKey == idempotencyKey)

                    || (requestHash != null && x.RequestHash == requestHash)))

            .OrderBy(x => x.CreatedAtUtc)

            .FirstOrDefaultAsync(cancellationToken);

    }


    private static TemplateType? ResolveCompletedResultMediaType(TemplateGenerationJob? job)

    {

        if (job?.Template is null)

        {

            return null;

        }


        return job.Template.TemplateType == TemplateType.Image ? TemplateType.Image : null;

    }


    private static bool IsCompletedResultUsable(TemplateGenerationJob job)

    {

        return job.Status == TemplateGenerationStatus.Completed

            && job.UserMediaDeletedAtUtc == null

            && !string.IsNullOrWhiteSpace(job.ResultUrl);

    }


    private async Task<TemplateMediaRecord?> GetOrCreateGenerationOutputMediaRecordAsync(

        TemplateGenerationJob job,

        TemplateType mediaType,

        CancellationToken cancellationToken)

    {

        if (string.IsNullOrWhiteSpace(job.ResultUrl))

        {

            return null;

        }


        var mediaTypeText = mediaType.ToString().ToLowerInvariant();

        var existing = await dbContext.TemplateMediaRecords

            .FirstOrDefaultAsync(

                x => x.GenerationId == job.Id

                    && x.SourceType == "generation_result"

                    && x.MediaType == mediaTypeText

                    && !x.IsDeleted,

                cancellationToken);


        if (existing is not null)

        {

            if (job.ResultMediaAssetId != existing.Id)

            {

                job.ResultMediaAssetId = existing.Id;

                await dbContext.SaveChangesAsync(cancellationToken);

            }

            return existing;

        }


        existing = await dbContext.TemplateMediaRecords

            .FirstOrDefaultAsync(x => x.Url == job.ResultUrl, cancellationToken);


        if (existing is null)

        {

            existing = new TemplateMediaRecord

            {

                Id = Guid.NewGuid(),

                Url = job.ResultUrl,

                UploadedAtUtc = job.MediaImportCompletedAtUtc ?? job.CompletedAtUtc ?? DateTime.UtcNow

            };

            dbContext.TemplateMediaRecords.Add(existing);

        }


        existing.UserId = job.UserId;

        existing.MediaType = mediaTypeText;

        existing.StoragePath = job.ResultUrl;

        existing.WatermarkedStoragePath = job.WatermarkedResultUrl;

        existing.SourceType = "generation_result";

        existing.GenerationId = job.Id;

        existing.FileName = string.IsNullOrWhiteSpace(existing.FileName)

            ? $"generated-{job.Id:N}.{(mediaType == TemplateType.Video ? "mp4" : "png")}"

            : existing.FileName;

        existing.ContentType = string.IsNullOrWhiteSpace(existing.ContentType)

            ? (mediaType == TemplateType.Video ? "video/mp4" : "image/png")

            : existing.ContentType;

        existing.Role = mediaType == TemplateType.Video

            ? TemplateMediaRole.GenerationOutputVideo

            : TemplateMediaRole.GenerationOutputImage;

        existing.LifecycleState = TemplateMediaLifecycleState.AttachedToGeneration;

        existing.GenerationJobId = job.Id;

        existing.AttachedAtUtc ??= DateTime.UtcNow;

        existing.ExpiresAtUtc = null;

        existing.DeletedAtUtc = null;

        existing.IsDeleted = false;

        job.ResultMediaAssetId = existing.Id;


        await dbContext.SaveChangesAsync(cancellationToken);

        return existing;

    }


    private static IQueryable<TemplateGenerationJob> ApplyStatusFilter(

        IQueryable<TemplateGenerationJob> query,

        string? rawStatus)

    {

        return rawStatus?.Trim().ToLowerInvariant() switch

        {

            null or "" or "all" => query,

            "active" => query.Where(x => TemplateGenerationJobStatusSets.Active.Contains(x.Status)),

            "pending" => query.Where(x => x.Status == TemplateGenerationStatus.Queued),

            "running" => query.Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)),

            "completed" => query.Where(x => x.Status == TemplateGenerationStatus.Completed),

            "failed" => query.Where(x => x.Status == TemplateGenerationStatus.Failed),

            "cancelled" => query.Where(x => x.Status == TemplateGenerationStatus.Cancelled),

            "retrying" => query.Where(x => x.Status == TemplateGenerationStatus.Retrying),

            "preprocessing" => query.Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)

                && x.StartedAtUtc != null

                && x.PreprocessingCompletedAtUtc == null),

            "generating" => query.Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)

                && x.PreprocessingCompletedAtUtc != null

                && x.MotionGenerationCompletedAtUtc == null

                && x.Template.TemplateType == TemplateType.Video),

            "finalizing" => query.Where(x => TemplateGenerationJobStatusSets.Processing.Contains(x.Status)

                && ((x.Template.TemplateType == TemplateType.Image && x.PreprocessingCompletedAtUtc != null)

                    || x.MotionGenerationCompletedAtUtc != null)),

            _ => query

        };

    }


    private static string[] NormalizeFeedbackReasons(IReadOnlyCollection<string> rawReasons)

    {

        return [.. rawReasons

            .Select(x => NormalizeOptionalText(x, 120))

            .Where(x => !string.IsNullOrWhiteSpace(x))

            .Distinct(StringComparer.OrdinalIgnoreCase)

            .Cast<string>()];

    }


    private static string? ResolveFeedbackModel(TemplateGenerationJob job)

    {

        return string.IsNullOrWhiteSpace(job.UsedKlingModel)

            ? job.UsedPreprocessingModel

            : job.UsedKlingModel;

    }


    private static double? ResolveGenerationDurationSeconds(TemplateGenerationJob job)

    {

        if (job.StartedAtUtc is null || job.CompletedAtUtc is null)

        {

            return null;

        }


        return Math.Max(0, (job.CompletedAtUtc.Value - job.StartedAtUtc.Value).TotalSeconds);

    }


    private static string? ResolveProviderRequestId(TemplateGenerationJob job)

    {

        return string.IsNullOrWhiteSpace(job.MotionProviderRequestId)

            ? job.PreprocessingProviderRequestId

            : job.MotionProviderRequestId;

    }


    private static string? NormalizeOptionalText(string? value, int maxLength)

    {

        if (string.IsNullOrWhiteSpace(value))

        {

            return null;

        }


        var trimmed = value.Trim();

        return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];

    }

    private static string NormalizeVariationStrength(string? value)
    {
        return string.Equals(value, "low", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value, "high", StringComparison.OrdinalIgnoreCase)
            ? value!.ToLowerInvariant()
            : "medium";
    }
}
