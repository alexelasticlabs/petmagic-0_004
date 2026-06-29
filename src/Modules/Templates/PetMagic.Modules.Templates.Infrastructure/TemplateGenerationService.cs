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

internal sealed partial class TemplateGenerationService(
    TemplatesDbContext dbContext,
    ITemplateGenerationBilling billing,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    TemplateWatermarkSettingsStore? watermarkSettings = null) : ITemplateGenerationService
{
    internal static readonly Guid AdminTestUserId = Guid.Empty;

    internal static Error? ValidateTemplate(TemplateItem template, bool requireActiveStatus)
    {
        if (requireActiveStatus && template.Status != TemplateStatus.Active)
        {
            return TemplatesErrors.InvalidStatus;
        }

        if (template.TemplateType == TemplateType.Image)
        {
            return string.IsNullOrWhiteSpace(template.ImageModel)
                ? TemplatesErrors.MissingImageModel
                : null;
        }

        if (template.TemplateType != TemplateType.Video)
        {
            return TemplatesErrors.TypeMismatch;
        }

        if (GetAsset(template, TemplateAssetKind.ReferenceMotion) is null)
        {
            return TemplatesErrors.MissingReferenceMotion;
        }

        if (template.CharacterOrientation is null)
        {
            return TemplatesErrors.MissingCharacterOrientation;
        }

        if (string.IsNullOrWhiteSpace(template.PreprocessingModel))
        {
            return TemplatesErrors.InvalidPreprocessingModel;
        }

        if (string.IsNullOrWhiteSpace(template.KlingModel))
        {
            return TemplatesErrors.InvalidKlingModel;
        }

        return null;
    }

    internal static TemplateAsset? GetAsset(TemplateItem template, TemplateAssetKind kind)
    {
        return template.Assets.FirstOrDefault(x => x.AssetKind == kind);
    }

    internal static string ResolvePrompt(string? prompt, string fallback)
    {
        return string.IsNullOrWhiteSpace(prompt) ? fallback : prompt.Trim();
    }

    internal static TemplateGenerationResponse MapResponse(
        TemplateGenerationJob job,
        int? queuePosition = null,
        int? estimatedWaitSeconds = null)
    {
        return new TemplateGenerationResponse(
            GenerationId: job.Id,
            UserId: job.UserId,
            TemplateId: job.TemplateId,
            Status: ResolveApiStatus(job.Status),
            TokenCost: job.TokenCost,
            SourceImageAsset: MapSourceImageAsset(job),
            NormalizedImageUrl: job.NormalizedImageUrl,
            ReferenceMotionUrl: job.ReferenceMotionUrl,
            OutputUrl: ResolveDefaultOutputUrl(job),
            AttemptCount: job.AttemptCount,
            UsedPreprocessingModel: job.UsedPreprocessingModel,
            UsedKlingModel: job.UsedKlingModel,
            PreprocessingProviderRequestId: job.PreprocessingProviderRequestId,
            PreprocessingInferenceTimeSeconds: job.PreprocessingInferenceTimeSeconds,
            MotionProviderRequestId: job.MotionProviderRequestId,
            MotionInferenceTimeSeconds: job.MotionInferenceTimeSeconds,
            OutputVideoDurationSeconds: job.OutputVideoDurationSeconds,
            MotionProviderCostUsd: job.MotionProviderCostUsd,
            FailureCode: job.LastErrorCode,
            FailureMessage: job.LastErrorMessage,
            CreatedAtUtc: job.CreatedAtUtc,
            UpdatedAtUtc: job.UpdatedAtUtc,
            StartedAtUtc: job.StartedAtUtc,
            PreprocessingCompletedAtUtc: job.PreprocessingCompletedAtUtc,
            MotionGenerationCompletedAtUtc: job.MotionGenerationCompletedAtUtc,
            MediaImportCompletedAtUtc: job.MediaImportCompletedAtUtc,
            CompletedAtUtc: job.CompletedAtUtc,
            UserMediaExpired: job.UserMediaDeletedAtUtc != null,
            TemplateTitle: job.Template?.Title,
            TemplateType: job.Template?.TemplateType.ToString(),
            Stage: ResolveStage(job),
            ProgressPercent: ResolveProgressPercent(job),
            EstimatedDurationLabel: ResolveEstimatedDurationLabel(job.Template?.TemplateType),
            ChargedAtUtc: job.ChargedAtUtc,
            RefundedAtUtc: job.RefundedAtUtc,
            IsUnread: job.Status == TemplateGenerationStatus.Completed && job.ResultViewedAtUtc == null,
            QueuePosition: queuePosition,
            EstimatedWaitSeconds: estimatedWaitSeconds,
            HasWatermark: HasWatermark(job, hasCleanAccess: false),
            CanRemoveWatermark: CanRemoveWatermark(job, hasCleanAccess: false),
            IsWatermarkRemoved: job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits: 1,
            UserPlan: "free",
            WatermarkMessage: ResolveWatermarkMessage(job, hasCleanAccess: false),
            SupportsGenerateSimilar: job.Template?.SupportsGenerateSimilar == true,
            ParentGenerationId: job.ParentGenerationId,
            ParentGenerationResultId: job.ParentGenerationResultId,
            SimilarToGenerationId: job.SimilarToGenerationId,
            GenerationMode: job.GenerationMode.ToString().ToLowerInvariant(),
            VariationStrength: job.VariationStrength,
            GenerationSeed: job.GenerationSeed,
            PromptBeforeVariation: job.PromptBeforeVariation,
            PromptAfterVariation: job.PromptAfterVariation,
            InputSourceType: string.IsNullOrWhiteSpace(job.InputSourceType) ? "user_upload" : job.InputSourceType,
            InputMediaAssetId: job.InputMediaAssetId,
            ResultMediaAssetId: job.ResultMediaAssetId,
            InputPreviewUrl: null,
            ResultPreviewUrl: null,
            CanCompareBeforeAfter: false,
            PetId: job.PetId,
            PetPhotoId: job.PetPhotoId);
    }

    private Task<PetPhoto?> ResolvePetPhotoForGenerationAsync(
        Guid userId,
        Pet pet,
        Guid? petPhotoId,
        CancellationToken cancellationToken)
    {
        var query = dbContext.PetPhotos
            .Include(x => x.MediaAsset)
            .Where(x => x.UserId == userId
                && x.PetId == pet.Id
                && !x.IsDeleted
                && x.Status == "active"
                && !x.MediaAsset.IsDeleted);

        if (petPhotoId is not null)
        {
            return query.FirstOrDefaultAsync(x => x.Id == petPhotoId.Value, cancellationToken);
        }

        return query
            .OrderByDescending(x => x.IsFavorite)
            .ThenByDescending(x => x.MediaAssetId == pet.AvatarMediaAssetId)
            .ThenByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<TemplateGenerationResponse> MapResponseWithQueueMetricsAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
        if (job.Status != TemplateGenerationStatus.Queued)
        {
            return await SignUserMediaUrlsAsync(
                await ApplyCompareAccessAsync(
                    ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                    job,
                    hasCleanAccess,
                    cancellationToken),
                cancellationToken);
        }

        var queuePosition = await CalculateQueuePositionAsync(job, cancellationToken);

        return await SignUserMediaUrlsAsync(
            await ApplyCompareAccessAsync(
                ApplyWatermarkAccess(MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)), job, isPremium, hasUnlock),
                job,
                hasCleanAccess,
                cancellationToken),
            cancellationToken);
    }

    private async Task<IReadOnlyList<TemplateGenerationResponse>> MapResponsesWithQueueMetricsAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        if (jobs.Count == 0)
        {
            return [];
        }

        var compareAccessContext = await BuildCompareAccessContextAsync(jobs, cancellationToken);
        var queuedJobs = jobs
            .Where(x => x.Status == TemplateGenerationStatus.Queued)
            .ToArray();
        if (queuedJobs.Length == 0)
        {
            var mapped = new List<TemplateGenerationResponse>(jobs.Count);
            foreach (var job in jobs)
            {
                var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
                var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
                mapped.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
            }

            return mapped;
        }

        var latestQueuedAtUtc = queuedJobs.Max(x => x.QueuedAtUtc);
        var queuedOrderKeys = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc <= latestQueuedAtUtc)
            .Select(x => new
            {
                x.Id,
                x.QueuedAtUtc
            })
            .ToArrayAsync(cancellationToken);

        var positionByQueuedJobId = queuedOrderKeys
            .OrderBy(x => x.QueuedAtUtc)
            .ThenBy(x => x.Id)
            .Select((job, index) => new
            {
                job.Id,
                Position = index + 1
            })
            .ToDictionary(x => x.Id, x => x.Position);

        var fallbackPositionByQueuedAtUtc = new Dictionary<DateTime, int>();
        foreach (var group in queuedOrderKeys.GroupBy(x => x.QueuedAtUtc).OrderBy(x => x.Key))
        {
            fallbackPositionByQueuedAtUtc[group.Key] = group
                .Select(x => positionByQueuedJobId.GetValueOrDefault(x.Id, 1))
                .Min();
        }

        var items = new List<TemplateGenerationResponse>(jobs.Count);
        foreach (var job in jobs)
        {
            var hasUnlock = job.WatermarkUnlocks.Any(x => x.UserId == job.UserId);
            var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
            if (job.Status != TemplateGenerationStatus.Queued)
            {
                items.Add(await SignUserMediaUrlsAsync(
                    ApplyCompareAccess(
                        ApplyWatermarkAccess(MapResponse(job), job, isPremium, hasUnlock),
                        job,
                        hasCleanAccess,
                        compareAccessContext),
                    cancellationToken));
                continue;
            }

            var queuePosition = positionByQueuedJobId.GetValueOrDefault(
                job.Id,
                fallbackPositionByQueuedAtUtc.GetValueOrDefault(job.QueuedAtUtc, 1));
            items.Add(await SignUserMediaUrlsAsync(
                ApplyCompareAccess(
                    ApplyWatermarkAccess(
                        MapResponse(job, queuePosition, EstimateWaitSeconds(job, queuePosition)),
                        job,
                        isPremium,
                        hasUnlock),
                    job,
                    hasCleanAccess,
                    compareAccessContext),
                cancellationToken));
        }

        return items;
    }

    private async Task<int> CalculateQueuePositionAsync(
        TemplateGenerationJob job,
        CancellationToken cancellationToken)
    {
        var olderQueuedCount = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .CountAsync(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc < job.QueuedAtUtc,
                cancellationToken);

        var tiedQueuedIds = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && x.QueuedAtUtc == job.QueuedAtUtc)
            .Select(x => x.Id)
            .ToArrayAsync(cancellationToken);

        Array.Sort(tiedQueuedIds);
        var tiedIndex = Array.IndexOf(tiedQueuedIds, job.Id);
        return olderQueuedCount + Math.Max(0, tiedIndex) + 1;
    }

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

        return job.SourceImageContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
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

        return job.SourceImageContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
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

    internal static TemplateGenerationResponse ApplyWatermarkAccess(
        TemplateGenerationResponse response,
        TemplateGenerationJob job,
        bool isPremium,
        bool hasUnlock,
        int removeWatermarkCostCredits)
    {
        var hasCleanAccess = isPremium || hasUnlock || !job.IsWatermarkRequired || job.IsWatermarkRemoved;
        return response with
        {
            OutputUrl = ResolveAccessibleOutputUrl(job, hasCleanAccess),
            HasWatermark = HasWatermark(job, hasCleanAccess),
            CanRemoveWatermark = CanRemoveWatermark(job, hasCleanAccess),
            IsWatermarkRemoved = hasUnlock || job.IsWatermarkRemoved,
            RemoveWatermarkCostCredits = Math.Max(1, removeWatermarkCostCredits),
            UserPlan = isPremium ? "premium" : "free",
            WatermarkMessage = ResolveWatermarkMessage(job, hasCleanAccess)
        };
    }

    private static string? ResolveAccessibleOutputUrl(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (job.Status != TemplateGenerationStatus.Completed)
        {
            return job.ResultUrl;
        }

        if (hasCleanAccess)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static string? ResolveDefaultOutputUrl(TemplateGenerationJob job)
    {
        if (job.Status != TemplateGenerationStatus.Completed || !job.IsWatermarkRequired)
        {
            return job.ResultUrl;
        }

        return string.IsNullOrWhiteSpace(job.WatermarkedResultUrl) ? null : job.WatermarkedResultUrl;
    }

    private static bool HasWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.WatermarkedResultUrl);
    }

    private static bool CanRemoveWatermark(TemplateGenerationJob job, bool hasCleanAccess)
    {
        return job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && !hasCleanAccess
            && !string.IsNullOrWhiteSpace(job.ResultUrl);
    }

    private static string? ResolveWatermarkMessage(TemplateGenerationJob job, bool hasCleanAccess)
    {
        if (hasCleanAccess && job.IsWatermarkRequired)
        {
            return "Watermark removed";
        }

        if (job.Status == TemplateGenerationStatus.Completed
            && job.IsWatermarkRequired
            && string.IsNullOrWhiteSpace(job.WatermarkedResultUrl))
        {
            return "Preparing result...";
        }

        return job.IsWatermarkRequired && !hasCleanAccess
            ? "Watermark added on the free plan"
            : null;
    }

    private TemplateGenerationWatermarkUnlock AddWatermarkUnlock(
        TemplateGenerationJob job,
        TemplateWatermarkUnlockMethod unlockMethod,
        int creditsSpent,
        Guid? unlockedByUserId)
    {
        var unlock = new TemplateGenerationWatermarkUnlock
        {
            Id = Guid.NewGuid(),
            UserId = job.UserId,
            GenerationJobId = job.Id,
            UnlockedByUserId = unlockedByUserId,
            UnlockMethod = unlockMethod,
            CreditsSpent = creditsSpent,
            CreatedAtUtc = DateTime.UtcNow
        };
        job.IsWatermarkRemoved = true;
        job.UpdatedAtUtc = unlock.CreatedAtUtc;
        dbContext.TemplateGenerationWatermarkUnlocks.Add(unlock);
        return unlock;
    }

    private async Task<RemoveGenerationWatermarkResponse?> TryResolveExistingWatermarkUnlockAsync(
        Guid userId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        dbContext.ChangeTracker.Clear();

        var existing = await dbContext.TemplateGenerationWatermarkUnlocks
            .AsNoTracking()
            .Where(x => x.UserId == userId && x.GenerationJobId == generationId)
            .Select(x => new { x.CreditsSpent })
            .FirstOrDefaultAsync(cancellationToken);
        if (existing is null)
        {
            return null;
        }

        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);
        if (job is null || string.IsNullOrWhiteSpace(job.ResultUrl))
        {
            return null;
        }

        var mediaUrl = await TryCreateReadUrlAsync(
            job.ResultUrl,
            TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
            cancellationToken);
        return new RemoveGenerationWatermarkResponse(true, existing.CreditsSpent, null, mediaUrl);
    }

    private async Task RecordMediaAccessAnalyticsAsync(
        Guid userId,
        Guid generationId,
        string eventType,
        string? mediaType,
        string? userPlan,
        CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == generationId && x.UserId == userId, cancellationToken);
        if (job is null)
        {
            return;
        }

        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = userId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(job.Id, job.TemplateId, mediaType, userPlan),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private void AddAnalyticsEvent(
        TemplateGenerationJob job,
        string eventType,
        string? userPlan = null,
        string? unlockMethod = null,
        int? creditsSpent = null)
    {
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = job.TemplateId,
            UserId = job.UserId,
            GenerationId = job.Id,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = BuildAnalyticsMetadata(
                job.Id,
                job.TemplateId,
                job.Template?.TemplateType.ToString(),
                userPlan,
                unlockMethod,
                creditsSpent,
                job.ParentGenerationId,
                job.Template?.TemplateType.ToString(),
                ResolveAnalyticsInputMediaType(job),
                job.TokenCost),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    private Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid petPhotoId,
        Guid templateId,
        Guid generationId,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        dbContext.TemplateAnalyticsEvents.Add(new TemplateAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            TemplateId = templateId,
            UserId = pet.UserId,
            GenerationId = generationId,
            EventType = eventType,
            Source = "mobile",
            DeviceClass = "unknown",
            CountryCode = "unknown",
            MetadataJson = JsonSerializer.Serialize(new
            {
                generationId,
                templateId,
                mediaType = "image",
                petId = pet.Id,
                petPhotoId
            }),
            ModerationStatus = "approved",
            CreatedAtUtc = DateTime.UtcNow
        });
        return Task.CompletedTask;
    }

    private static string BuildAnalyticsMetadata(
        Guid generationId,
        Guid templateId,
        string? mediaType,
        string? userPlan,
        string? unlockMethod = null,
        int? creditsSpent = null,
        Guid? parentGenerationId = null,
        string? newTemplateType = null,
        string? inputMediaType = null,
        int? creditsCost = null)
    {
        return JsonSerializer.Serialize(new
        {
            generationId,
            templateId,
            parentGenerationId,
            newTemplateId = templateId,
            newTemplateType = NormalizeAnalyticsMediaType(newTemplateType),
            mediaType = string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant(),
            inputMediaType = NormalizeAnalyticsMediaType(inputMediaType),
            userPlan,
            unlockMethod,
            creditsSpent,
            creditsCost
        });
    }

    private static string? ResolveAnalyticsInputMediaType(TemplateGenerationJob job)
    {
        if (job.InputSourceType is null)
        {
            return null;
        }

        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return job.Template?.RequiredInputMediaType?.ToString();
        }

        return job.SourceImageContentType?.StartsWith("image/", StringComparison.OrdinalIgnoreCase) == true
            ? "image"
            : null;
    }

    private static string NormalizeAnalyticsMediaType(string? mediaType)
    {
        return string.IsNullOrWhiteSpace(mediaType) ? "unknown" : mediaType.Trim().ToLowerInvariant();
    }

    private async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        return await SignUserMediaUrlsAsync(mediaStorage, options, response, cancellationToken);
    }

    internal static async Task<TemplateGenerationResponse> SignUserMediaUrlsAsync(
        IMediaStorage mediaStorage,
        TemplatesOptions options,
        TemplateGenerationResponse response,
        CancellationToken cancellationToken)
    {
        var ttl = TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds));
        var sourceImageAsset = response.SourceImageAsset;
        if (sourceImageAsset is not null)
        {
            var signedSourceUrl = await TryCreateReadUrlAsync(mediaStorage, sourceImageAsset.Url, ttl, cancellationToken);
            sourceImageAsset = signedSourceUrl is null
                ? null
                : sourceImageAsset with { Url = signedSourceUrl };
        }

        return response with
        {
            SourceImageAsset = sourceImageAsset,
            NormalizedImageUrl = await TryCreateReadUrlAsync(mediaStorage, response.NormalizedImageUrl, ttl, cancellationToken),
            OutputUrl = await TryCreateReadUrlAsync(mediaStorage, response.OutputUrl, ttl, cancellationToken),
            InputPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.InputPreviewUrl, ttl, cancellationToken),
            ResultPreviewUrl = await TryCreateReadUrlAsync(mediaStorage, response.ResultPreviewUrl, ttl, cancellationToken)
        };
    }

    private async Task<string?> TryCreateReadUrlAsync(string? assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        return await TryCreateReadUrlAsync(mediaStorage, assetUrl, ttl, cancellationToken);
    }

    private static async Task<string?> TryCreateReadUrlAsync(
        IMediaStorage mediaStorage,
        string? assetUrl,
        TimeSpan ttl,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return null;
        }

        var signed = await mediaStorage.CreateReadUrlAsync(assetUrl, ttl, cancellationToken);
        return signed.IsSuccess ? signed.Value : null;
    }

    private string ResolveManagedStoragePathOrUrl(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        if (candidate.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return candidate;
        }

        var localBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(localBaseUrl)
            && candidate.StartsWith(localBaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            var relativePath = candidate[localBaseUrl.Length..].TrimStart('/');
            if (relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
            {
                return relativePath;
            }
        }

        if (!options.R2.IsConfigured)
        {
            return assetUrl;
        }

        var r2BaseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(r2BaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return assetUrl;
        }

        var storageKey = candidate[r2BaseUrl.Length..].TrimStart('/');
        var objectKeyPrefix = NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix);
        return storageKey.StartsWith($"{objectKeyPrefix}/", StringComparison.OrdinalIgnoreCase)
            ? storageKey
            : assetUrl;
    }

    private static string NormalizeObjectKeyPrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }

    private int EstimateWaitSeconds(TemplateGenerationJob job, int queuePosition)
    {
        var averageGenerationSeconds = job.Template?.TemplateType == TemplateType.Video
            ? options.EstimatedVideoGenerationSeconds
            : options.EstimatedImageGenerationSeconds;
        var globalConcurrency = Math.Max(1, options.GlobalMaxConcurrentGenerations);
        return (int)Math.Ceiling(queuePosition * averageGenerationSeconds / (double)globalConcurrency);
    }

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
            "running" => query.Where(x => x.Status == TemplateGenerationStatus.Processing),
            "completed" => query.Where(x => x.Status == TemplateGenerationStatus.Completed),
            "failed" => query.Where(x => x.Status == TemplateGenerationStatus.Failed),
            "cancelled" => query.Where(x => x.Status == TemplateGenerationStatus.Cancelled),
            "retrying" => query.Where(x => x.Status == TemplateGenerationStatus.Retrying),
            "preprocessing" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
                && x.StartedAtUtc != null
                && x.PreprocessingCompletedAtUtc == null),
            "generating" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
                && x.PreprocessingCompletedAtUtc != null
                && x.MotionGenerationCompletedAtUtc == null
                && x.Template.TemplateType == TemplateType.Video),
            "finalizing" => query.Where(x => x.Status == TemplateGenerationStatus.Processing
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

    private async Task AddPetAnalyticsEventAsync(
        Pet pet,
        string eventType,
        Guid? petPhotoId = null,
        Guid? templateId = null,
        Guid? generationId = null,
        string userPlan = "unknown",
        string sourceScreen = "api",
        CancellationToken cancellationToken = default)
    {
        var photosCount = await dbContext.PetPhotos.CountAsync(
            x => x.UserId == pet.UserId && x.PetId == pet.Id && !x.IsDeleted,
            cancellationToken);

        dbContext.PetAnalyticsEvents.Add(new PetAnalyticsEvent
        {
            Id = Guid.NewGuid(),
            UserId = pet.UserId,
            PetId = pet.Id,
            PetPhotoId = petPhotoId,
            TemplateId = templateId,
            GenerationId = generationId,
            EventType = eventType,
            PetType = pet.Type,
            PhotosCount = photosCount,
            UserPlan = userPlan,
            SourceScreen = sourceScreen,
            CreatedAtUtc = DateTime.UtcNow
        });
    }

    internal static string ResolveApiStatus(TemplateGenerationStatus status)
    {
        return status.ToString();
    }

    internal static string ResolveStage(TemplateGenerationJob job)
    {
        if (job.Status == TemplateGenerationStatus.Failed)
        {
            return "failed";
        }

        if (job.Status == TemplateGenerationStatus.Cancelled)
        {
            return "cancelled";
        }

        if (job.Status == TemplateGenerationStatus.Retrying)
        {
            return "retrying";
        }

        if (job.Status == TemplateGenerationStatus.Completed)
        {
            return "completed";
        }

        if (job.Status == TemplateGenerationStatus.Queued)
        {
            return "queued";
        }

        if (job.Status != TemplateGenerationStatus.Processing)
        {
            return "processing";
        }

        if (job.MediaImportCompletedAtUtc is not null
            || job.MotionGenerationCompletedAtUtc is not null
            || (job.Template?.TemplateType == TemplateType.Image && job.PreprocessingCompletedAtUtc is not null))
        {
            return "finalizing";
        }

        if (job.Template?.TemplateType == TemplateType.Video && job.PreprocessingCompletedAtUtc is not null)
        {
            return "generating";
        }

        if (job.StartedAtUtc is not null)
        {
            return "preprocessing";
        }

        return "processing";
    }

    internal static int ResolveProgressPercent(TemplateGenerationJob job)
    {
        return ResolveStage(job) switch
        {
            "completed" => 100,
            "failed" => 100,
            "finalizing" => 90,
            "generating" => 65,
            "preprocessing" => 30,
            "uploading" => 15,
            _ => 10
        };
    }

    private static string ResolveEstimatedDurationLabel(TemplateType? templateType)
    {
        return templateType == TemplateType.Video
            ? "Usually 1-3 minutes"
            : "Usually under 1 minute";
    }

    private static TemplateAssetResponse? MapSourceImageAsset(TemplateGenerationJob job)
    {
        if (string.Equals(job.InputSourceType, "generation_result", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        if (string.IsNullOrWhiteSpace(job.SourceImageUrl))
        {
            return null;
        }

        return new TemplateAssetResponse(
            job.SourceImageUrl,
            job.SourceImageFileName,
            job.SourceImageContentType,
            job.SourceImageFileSizeBytes,
            null);
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
