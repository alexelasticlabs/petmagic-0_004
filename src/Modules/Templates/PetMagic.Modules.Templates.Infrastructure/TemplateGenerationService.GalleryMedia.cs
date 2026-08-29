using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private async Task<IReadOnlyList<GalleryItemResponse>> MapGalleryItemsWithQueueMetricsAsync(
        IReadOnlyList<TemplateGenerationJob> jobs,
        CancellationToken cancellationToken,
        bool isPremium = false)
    {
        var signedResponses = await MapResponsesWithQueueMetricsAsync(jobs, cancellationToken, isPremium);
        var items = new List<GalleryItemResponse>(jobs.Count);
        for (var index = 0; index < jobs.Count; index++)
        {
            items.Add(await MapGalleryItemAsync(jobs[index], signedResponses[index], cancellationToken));
        }

        return items;
    }

    private async Task<GalleryItemResponse> MapGalleryItemAsync(
        TemplateGenerationJob job,
        TemplateGenerationResponse signedResponse,
        CancellationToken cancellationToken)
    {
        var media = await MapGalleryMediaAsync(job, signedResponse, cancellationToken);
        return new GalleryItemResponse(
            GenerationId: signedResponse.GenerationId,
            TemplateId: signedResponse.TemplateId,
            Status: signedResponse.Status,
            CreatedAtUtc: signedResponse.CreatedAtUtc,
            UpdatedAtUtc: signedResponse.UpdatedAtUtc,
            CompletedAtUtc: signedResponse.CompletedAtUtc,
            TokenCost: signedResponse.TokenCost,
            RefundedAtUtc: signedResponse.RefundedAtUtc,
            RefundState: signedResponse.RefundState,
            TemplateTitle: signedResponse.TemplateTitle,
            TemplateType: signedResponse.TemplateType,
            Media: media,
            IsUnread: signedResponse.IsUnread,
            ProgressPercent: signedResponse.ProgressPercent,
            Stage: signedResponse.Stage,
            QueuePosition: signedResponse.QueuePosition,
            EstimatedCompletionAtUtc: signedResponse.EstimatedCompletionAtUtc,
            Failure: string.IsNullOrWhiteSpace(signedResponse.FailureCode)
                && string.IsNullOrWhiteSpace(signedResponse.FailureMessage)
                    ? null
                    : new GalleryFailureResponse(signedResponse.FailureCode, signedResponse.FailureMessage));
    }

    private async Task<GalleryMediaResponse> MapGalleryMediaAsync(
        TemplateGenerationJob job,
        TemplateGenerationResponse signedResponse,
        CancellationToken cancellationToken)
    {
        var mediaType = ResolveGalleryMediaType(job, signedResponse);
        var resultMedia = ResolveGalleryResultMediaRecord(job);
        var hasSignedResult = !string.IsNullOrWhiteSpace(signedResponse.OutputUrl);
        var hasRawResult = !string.IsNullOrWhiteSpace(ResolveDefaultOutputUrl(job));
        var resultExpiresAtUtc = hasSignedResult
            ? DateTime.UtcNow.AddSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds))
            : (DateTime?)null;

        var signedPreviewUrl = signedResponse.ResultPreviewUrl;
        if (job.Status is TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled)
        {
            var inputPreviewUrl = job.InputMediaAssetId is Guid inputMediaAssetId
                ? job.MediaRecords
                    .FirstOrDefault(x => x.Id == inputMediaAssetId
                        && !x.IsDeleted
                        && x.MediaType == "image")
                    ?.PreviewUrl
                : null;
            inputPreviewUrl ??= await ResolveInputComparePreviewUrlAsync(
                job,
                cancellationToken);
            signedPreviewUrl = await TryCreateReadUrlAsync(
                inputPreviewUrl,
                TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
                cancellationToken);
        }
        if (string.IsNullOrWhiteSpace(signedPreviewUrl))
        {
            signedPreviewUrl = await TryCreateReadUrlAsync(
                ResolveGalleryPreviewUrl(job, signedResponse, resultMedia),
                TimeSpan.FromSeconds(Math.Max(1, options.UserMediaReadUrlTtlSeconds)),
                cancellationToken);
        }

        var state = ResolveGalleryMediaState(job, signedResponse, resultMedia, hasRawResult, hasSignedResult, signedPreviewUrl);
        var reasonCode = ResolveGalleryMediaReasonCode(state, job, signedResponse, resultMedia);
        return new GalleryMediaResponse(
            State: state,
            MediaType: mediaType,
            PreviewUrl: signedPreviewUrl,
            ResultUrl: signedResponse.OutputUrl,
            ResultExpiresAtUtc: resultExpiresAtUtc,
            DurationSeconds: signedResponse.OutputVideoDurationSeconds,
            HasWatermark: signedResponse.HasWatermark,
            CanRemoveWatermark: signedResponse.CanRemoveWatermark,
            IsWatermarkRemoved: signedResponse.IsWatermarkRemoved,
            CanDownload: state == GalleryMediaState.resultReady,
            CanShare: state == GalleryMediaState.resultReady,
            ReasonCode: reasonCode,
            UserMessageKey: ResolveGalleryMediaMessageKey(state),
            RetryAfterSeconds: state is GalleryMediaState.pending or GalleryMediaState.processing or GalleryMediaState.watermarkPreparing
                ? signedResponse.RetryAfterSeconds
                : null);
    }

    private static GalleryMediaState ResolveGalleryMediaState(
        TemplateGenerationJob job,
        TemplateGenerationResponse signedResponse,
        TemplateMediaRecord? resultMedia,
        bool hasRawResult,
        bool hasSignedResult,
        string? signedPreviewUrl)
    {
        if (job.HiddenByUserAtUtc is not null)
        {
            return GalleryMediaState.hidden;
        }

        if (job.Status is TemplateGenerationStatus.Failed or TemplateGenerationStatus.Cancelled)
        {
            return GalleryMediaState.failed;
        }

        if (job.Status is TemplateGenerationStatus.Queued or TemplateGenerationStatus.SubmittingToProvider or TemplateGenerationStatus.ProviderQueued)
        {
            return GalleryMediaState.pending;
        }

        if (job.Status != TemplateGenerationStatus.Completed)
        {
            return GalleryMediaState.processing;
        }

        if (job.UserMediaDeletedAtUtc is not null
            || resultMedia?.ExpiresAtUtc <= DateTime.UtcNow)
        {
            return GalleryMediaState.expired;
        }

        if (resultMedia?.IsDeleted == true || resultMedia?.LifecycleState == TemplateMediaLifecycleState.Deleted)
        {
            return GalleryMediaState.storageUnavailable;
        }

        if (job.ResultMediaAssetId is not null && resultMedia is null)
        {
            return GalleryMediaState.storageUnavailable;
        }

        if ((signedResponse.HasWatermark || signedResponse.CanRemoveWatermark)
            && !hasSignedResult
            && !string.IsNullOrWhiteSpace(job.ResultUrl)
            && string.IsNullOrWhiteSpace(job.WatermarkedResultUrl))
        {
            return GalleryMediaState.watermarkPreparing;
        }

        if (hasSignedResult)
        {
            return GalleryMediaState.resultReady;
        }

        if (!string.IsNullOrWhiteSpace(signedPreviewUrl))
        {
            return GalleryMediaState.previewReadyOnly;
        }

        return hasRawResult ? GalleryMediaState.storageUnavailable : GalleryMediaState.storageUnavailable;
    }

    private static string ResolveGalleryMediaType(TemplateGenerationJob job, TemplateGenerationResponse signedResponse)
    {
        if (!string.IsNullOrWhiteSpace(signedResponse.MediaType))
        {
            return signedResponse.MediaType.Trim().ToLowerInvariant() == TemplateGenerationQueue.MediaTypeVideo
                ? "video"
                : "image";
        }

        return TemplateGenerationQueue.ResolveMediaType(job) == TemplateGenerationQueue.MediaTypeVideo
            ? "video"
            : "image";
    }

    private static TemplateMediaRecord? ResolveGalleryResultMediaRecord(TemplateGenerationJob job)
    {
        return job.MediaRecords
            .Where(x => x.GenerationId == job.Id
                && x.SourceType == "generation_result")
            .OrderByDescending(x => x.Id == job.ResultMediaAssetId)
            .ThenByDescending(x => x.UploadedAtUtc)
            .FirstOrDefault();
    }

    private static string? ResolveGalleryPreviewUrl(
        TemplateGenerationJob job,
        TemplateGenerationResponse signedResponse,
        TemplateMediaRecord? resultMedia)
    {
        if (resultMedia is null)
        {
            return null;
        }

        if (signedResponse.HasWatermark && !string.IsNullOrWhiteSpace(resultMedia.WatermarkedPreviewUrl))
        {
            return resultMedia.WatermarkedPreviewUrl;
        }

        return resultMedia.PreviewUrl;
    }

    private static string? ResolveGalleryMediaReasonCode(
        GalleryMediaState state,
        TemplateGenerationJob job,
        TemplateGenerationResponse signedResponse,
        TemplateMediaRecord? resultMedia)
    {
        return state switch
        {
            GalleryMediaState.failed => signedResponse.FailureCode ?? "generation_failed",
            GalleryMediaState.expired => "media_expired",
            GalleryMediaState.storageUnavailable => resultMedia?.FailureCode ?? "storage_unavailable",
            GalleryMediaState.watermarkPreparing => job.WatermarkFailureCode ?? "watermark_preparing",
            GalleryMediaState.previewReadyOnly => "preview_ready_only",
            GalleryMediaState.pending => "generation_pending",
            GalleryMediaState.processing => "generation_processing",
            GalleryMediaState.hidden => "generation_hidden",
            _ => null
        };
    }

    private static string? ResolveGalleryMediaMessageKey(GalleryMediaState state)
    {
        return state switch
        {
            GalleryMediaState.pending => "gallery.media.pending",
            GalleryMediaState.processing => "gallery.media.processing",
            GalleryMediaState.previewReadyOnly => "gallery.media.previewReadyOnly",
            GalleryMediaState.watermarkPreparing => "gallery.media.watermarkPreparing",
            GalleryMediaState.expired => "gallery.media.expired",
            GalleryMediaState.storageUnavailable => "gallery.media.storageUnavailable",
            GalleryMediaState.failed => "gallery.media.failed",
            GalleryMediaState.hidden => "gallery.media.hidden",
            _ => null
        };
    }
}
