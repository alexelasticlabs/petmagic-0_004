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

    private async Task<TemplateGenerationResponse> ApplyCompareAccessAsync(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        CancellationToken cancellationToken)
    {
        if (job.Status != TemplateGenerationStatus.Completed
            || job.Template?.TemplateType != TemplateType.Image)
        {
            return response with
            {
                ResultMediaAssetId = job.ResultMediaAssetId,
                InputPreviewUrl = null,
                ResultPreviewUrl = null,
                CanCompareBeforeAfter = false
            };
        }

        var inputPreviewUrl = await ResolveInputComparePreviewUrlAsync(job, cancellationToken);
        var resultMediaRecord = await ResolveResultMediaRecordAsync(job, cancellationToken);
        return ApplyCompareAccess(response, job, hasCleanAccess, inputPreviewUrl, resultMediaRecord);
    }

    private static TemplateGenerationResponse ApplyCompareAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        CompareAccessContext compareAccessContext)
    {
        if (job.Status != TemplateGenerationStatus.Completed
            || job.Template?.TemplateType != TemplateType.Image)
        {
            return response with
            {
                ResultMediaAssetId = job.ResultMediaAssetId,
                InputPreviewUrl = null,
                ResultPreviewUrl = null,
                CanCompareBeforeAfter = false
            };
        }

        compareAccessContext.InputPreviewUrlsByGenerationId.TryGetValue(job.Id, out var inputPreviewUrl);
        compareAccessContext.ResultMediaRecordsByGenerationId.TryGetValue(job.Id, out var resultMediaRecord);
        return ApplyCompareAccess(response, job, hasCleanAccess, inputPreviewUrl, resultMediaRecord);
    }

    private static TemplateGenerationResponse ApplyCompareAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool hasCleanAccess,
        string? inputPreviewUrl,
        TemplateMediaRecord? resultMediaRecord)
    {
        var resultPreviewUrl = ResolveResultComparePreviewUrl(job, resultMediaRecord, hasCleanAccess);
        var canCompare = !string.IsNullOrWhiteSpace(inputPreviewUrl)
            && !string.IsNullOrWhiteSpace(resultPreviewUrl);

        return response with
        {
            ResultMediaAssetId = resultMediaRecord?.Id ?? job.ResultMediaAssetId,
            InputPreviewUrl = canCompare ? inputPreviewUrl : null,
            ResultPreviewUrl = canCompare ? resultPreviewUrl : null,
            CanCompareBeforeAfter = canCompare
        };
    }

    private async Task<CompareAccessContext> BuildCompareAccessContextAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken)
    {
        var compareJobs = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Completed
                && x.Template?.TemplateType == TemplateType.Image)
            .ToArray();

        if (compareJobs.Length == 0)
        {
            return CompareAccessContext.Empty;
        }

        var inputMediaAssetIds = compareJobs
            .Select(x => x.InputMediaAssetId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var petPhotoIds = compareJobs
            .Select(x => x.PetPhotoId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var resultMediaAssetIds = compareJobs
            .Select(x => x.ResultMediaAssetId)
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var generationIds = compareJobs
            .Select(x => x.Id)
            .Distinct()
            .ToArray();
        var userIds = compareJobs
            .Select(x => x.UserId)
            .Distinct()
            .ToArray();

        var inputMediaRecordsById = inputMediaAssetIds.Length == 0
            ? new Dictionary<Guid, TemplateMediaRecord>()
            : await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .Where(x => inputMediaAssetIds.Contains(x.Id)
                    && x.UserId.HasValue
                    && userIds.Contains(x.UserId.Value)
                    && !x.IsDeleted
                    && x.MediaType == "image")
                .ToDictionaryAsync(x => x.Id, cancellationToken);

        var petPhotosById = petPhotoIds.Length == 0
            ? new Dictionary<Guid, PetPhoto>()
            : await dbContext.PetPhotos
                .AsNoTracking()
                .Include(x => x.MediaAsset)
                .Where(x => petPhotoIds.Contains(x.Id)
                    && userIds.Contains(x.UserId)
                    && !x.IsDeleted
                    && !x.MediaAsset.IsDeleted)
                .ToDictionaryAsync(x => x.Id, cancellationToken);

        var resultMediaRecords = await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .Where(x => x.UserId.HasValue
                && userIds.Contains(x.UserId.Value)
                && !x.IsDeleted
                && x.MediaType == "image"
                && (resultMediaAssetIds.Contains(x.Id)
                    || (x.GenerationId.HasValue
                        && generationIds.Contains(x.GenerationId.Value)
                        && x.SourceType == "generation_result")))
            .ToArrayAsync(cancellationToken);

        var resultMediaRecordsById = resultMediaRecords
            .Where(x => resultMediaAssetIds.Contains(x.Id))
            .ToDictionary(x => x.Id);
        var resultMediaRecordsByGenerationId = resultMediaRecords
            .Where(x => x.GenerationId.HasValue && x.SourceType == "generation_result")
            .GroupBy(x => x.GenerationId!.Value)
            .ToDictionary(
                x => x.Key,
                x => x.OrderByDescending(record => record.UploadedAtUtc).First());

        var inputPreviewUrlsByGenerationId = new Dictionary<Guid, string>();
        var finalResultMediaRecordsByGenerationId = new Dictionary<Guid, TemplateMediaRecord>();
        foreach (var job in compareJobs)
        {
            var inputPreviewUrl = ResolveInputComparePreviewUrl(job, petPhotosById, inputMediaRecordsById);
            if (!string.IsNullOrWhiteSpace(inputPreviewUrl))
            {
                inputPreviewUrlsByGenerationId[job.Id] = inputPreviewUrl;
            }

            TemplateMediaRecord? resultMediaRecord = null;
            if (job.ResultMediaAssetId is Guid resultMediaAssetId)
            {
                resultMediaRecordsById.TryGetValue(resultMediaAssetId, out resultMediaRecord);
            }

            resultMediaRecord ??= resultMediaRecordsByGenerationId.GetValueOrDefault(job.Id);
            if (resultMediaRecord is not null)
            {
                finalResultMediaRecordsByGenerationId[job.Id] = resultMediaRecord;
            }
        }

        return new CompareAccessContext(inputPreviewUrlsByGenerationId, finalResultMediaRecordsByGenerationId);
    }

    private static string? ResolveInputComparePreviewUrl(
        TemplateGenerationJob job,
        IReadOnlyDictionary<Guid, PetPhoto> petPhotosById,
        IReadOnlyDictionary<Guid, TemplateMediaRecord> inputMediaRecordsById)
    {
        if (string.Equals(job.InputSourceType, "pet_photo", StringComparison.OrdinalIgnoreCase)
            && job.PetPhotoId is Guid petPhotoId
            && petPhotosById.TryGetValue(petPhotoId, out var petPhoto))
        {
            return petPhoto.ThumbnailUrl
                ?? petPhoto.MediaAsset.PreviewUrl
                ?? petPhoto.MediaAsset.Url;
        }

        if (job.InputMediaAssetId is Guid inputMediaAssetId
            && inputMediaRecordsById.TryGetValue(inputMediaAssetId, out var inputMediaRecord))
        {
            return inputMediaRecord.PreviewUrl ?? inputMediaRecord.Url;
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? job.SourceImageUrl
            : null;
    }

    private async Task<string?> ResolveInputComparePreviewUrlAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (string.Equals(job.InputSourceType, "pet_photo", StringComparison.OrdinalIgnoreCase)
            && job.PetPhotoId is Guid petPhotoId)
        {
            var petPhoto = await dbContext.PetPhotos
                .AsNoTracking()
                .Include(x => x.MediaAsset)
                .FirstOrDefaultAsync(
                    x => x.Id == petPhotoId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && !x.MediaAsset.IsDeleted,
                    cancellationToken);

            if (petPhoto is not null)
            {
                return petPhoto.ThumbnailUrl
                    ?? petPhoto.MediaAsset.PreviewUrl
                    ?? petPhoto.MediaAsset.Url;
            }
        }

        if (job.InputMediaAssetId is Guid inputMediaAssetId)
        {
            var inputMediaRecord = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == inputMediaAssetId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && x.MediaType == "image",
                    cancellationToken);

            if (inputMediaRecord is not null)
            {
                return inputMediaRecord.PreviewUrl ?? inputMediaRecord.Url;
            }
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? job.SourceImageUrl
            : null;
    }

    private async Task<TemplateMediaRecord?> ResolveResultMediaRecordAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        if (job.ResultMediaAssetId is Guid resultMediaAssetId)
        {
            var resultMediaRecord = await dbContext.TemplateMediaRecords
                .AsNoTracking()
                .FirstOrDefaultAsync(
                    x => x.Id == resultMediaAssetId
                        && x.UserId == job.UserId
                        && !x.IsDeleted
                        && x.MediaType == "image",
                    cancellationToken);
            if (resultMediaRecord is not null)
            {
                return resultMediaRecord;
            }
        }

        return await dbContext.TemplateMediaRecords
            .AsNoTracking()
            .FirstOrDefaultAsync(
                x => x.GenerationId == job.Id
                    && x.UserId == job.UserId
                    && x.SourceType == "generation_result"
                    && x.MediaType == "image"
                    && !x.IsDeleted,
                cancellationToken);
    }

    private static string? ResolveResultComparePreviewUrl(
        TemplateGenerationJob job,
        TemplateMediaRecord? resultMediaRecord,
        bool hasCleanAccess)
    {
        if (hasCleanAccess)
        {
            return resultMediaRecord?.PreviewUrl
                ?? resultMediaRecord?.Url
                ?? job.ResultUrl;
        }

        return resultMediaRecord?.WatermarkedPreviewUrl
            ?? resultMediaRecord?.WatermarkedStoragePath
            ?? job.WatermarkedResultUrl;
    }

    internal TemplateGenerationResponse ApplyWatermarkAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool isPremium,
        bool hasUnlock)
    {
        return ApplyWatermarkAccess(
            response,
            job,
            isPremium,
            hasUnlock,
            Math.Max(1, (watermarkSettings ?? new TemplateWatermarkSettingsStore(options)).Current.CostCredits));
    }

    private sealed record CompareAccessContext(
        IReadOnlyDictionary<Guid, string> InputPreviewUrlsByGenerationId,
        IReadOnlyDictionary<Guid, TemplateMediaRecord> ResultMediaRecordsByGenerationId)
    {
        public static CompareAccessContext Empty { get; } = new(
            new Dictionary<Guid, string>(),
            new Dictionary<Guid, TemplateMediaRecord>());
    }
}
