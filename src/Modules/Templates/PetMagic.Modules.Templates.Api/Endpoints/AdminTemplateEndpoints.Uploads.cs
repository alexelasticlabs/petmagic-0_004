using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{

    private static async Task<Dictionary<string, string[]>> ValidateSourceImageAsync(

        IFormFile? sourceImage,

        long maxSizeBytes,

        CancellationToken cancellationToken)

    {

        var errors = new Dictionary<string, string[]>();

        if (sourceImage is null || sourceImage.Length == 0)

        {

            errors[nameof(sourceImage)] = ["templates.source_image_empty"];

            return errors;

        }


        if (sourceImage.Length > maxSizeBytes)

        {

            errors[nameof(sourceImage)] = ["templates.source_image_too_large"];

        }

        if (errors.Count > 0)

        {

            return errors;

        }


        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage, cancellationToken);

        if (detectedContentType is null

            || !IsAllowedSourceImageContentType(detectedContentType)

            || !TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, sourceImage.ContentType))

        {

            errors[nameof(sourceImage)] = ["templates.source_image_type_not_allowed"];

        }


        return errors;

    }


    private static bool IsAllowedSourceImageContentType(string contentType)

    {

        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase);

    }


    internal static async Task<Results<Ok<TemplateMediaUploadResponse>, ValidationProblem, ProblemHttpResult>> UploadMediaAsync(

        [FromForm] IFormFile? file,

        [FromForm] string assetKind,

        [FromServices] IMediaStorage mediaStorage,

        [FromServices] ITemplateMediaLifecycleService mediaLifecycleService,

        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,

        [FromServices] IMediaMetadataReader metadataReader,

        [FromServices] ITemplatePreviewOptimizer previewOptimizer,

        CancellationToken cancellationToken,

        [FromForm] string? durationSeconds = null)

    {

        var errors = new Dictionary<string, string[]>();


        if (file is null || file.Length == 0)

        {

            errors[nameof(file)] = ["templates.file_required"];

        }


        if (!Enum.TryParse<TemplateAssetKind>(assetKind, true, out var parsedAssetKind))

        {

            errors[nameof(assetKind)] = ["templates.asset_kind_invalid"];

        }


        if (errors.Count > 0)

        {

            return TypedResults.ValidationProblem(errors);

        }


        var kind = parsedAssetKind;

        var declaredContentType = file!.ContentType ?? "application/octet-stream";

        var maxSize = uploadPolicy.GetMaxFileSizeBytes(kind);


        if (file.Length > maxSize)

        {

            return TypedResults.ValidationProblem(new Dictionary<string, string[]>

            {

                [nameof(file)] = ["templates.file_too_large"]

            });

        }


        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(file, cancellationToken);

        if (detectedContentType is null

            || (!TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, declaredContentType)

                && !IsPreviewIsoBmffMimeEquivalent(kind, detectedContentType, declaredContentType))

            || !IsAllowedUpload(file.FileName, kind, detectedContentType))

        {

            return TypedResults.ValidationProblem(new Dictionary<string, string[]>

            {

                [nameof(file)] = ["templates.file_type_not_allowed"]

            });

        }


        await using var stream = file.OpenReadStream();

        var storeResult = await mediaStorage.StoreAsync(

            new MediaUploadCommand(

                Path.GetFileName(file.FileName),

                detectedContentType,

                stream,

                file.Length),

            cancellationToken);


        if (storeResult.IsFailure)

        {

            if (TryGetAmbiguousStorageKey(storeResult.Error, out var ambiguousStorageKey))

            {

                await CleanupStoredUploadAsync(

                    new StoredMediaResponse(

                        ambiguousStorageKey,

                        ambiguousStorageKey,

                        Path.GetFileName(file.FileName),

                        detectedContentType,

                        file.Length,

                        null),

                    null,

                    MapMediaRole(kind),

                    mediaStorage,

                    mediaLifecycleService);

            }


            cancellationToken.ThrowIfCancellationRequested();

            return ToAdminTemplateProblem(storeResult.Error);

        }


        try

        {

            await mediaLifecycleService.RegisterTemporaryUploadAsync(

                ToAssetCommand(storeResult.Value, null),

                MapMediaRole(kind),

                cancellationToken);

            await mediaLifecycleService.SaveChangesAsync(cancellationToken);

        }

        catch

        {

            await CleanupStoredUploadAsync(

                storeResult.Value,

                null,

                MapMediaRole(kind),

                mediaStorage,

                mediaLifecycleService);

            throw;

        }


        var storedContentType = string.IsNullOrWhiteSpace(storeResult.Value.ContentType)

            ? detectedContentType

            : storeResult.Value.ContentType;

        double? duration = null;

        if (storedContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)

            || string.Equals(storedContentType, "application/mp4", StringComparison.OrdinalIgnoreCase))

        {

            Result<double?> durationResult;

            try

            {

                durationResult = await metadataReader.GetVideoDurationSecondsAsync(

                    storeResult.Value,

                    retainLocalPathOnSuccess: kind == TemplateAssetKind.Preview,

                    cancellationToken: cancellationToken);

            }

            catch (OperationCanceledException)

            {

                await CleanupStoredUploadAsync(

                    storeResult.Value,

                    null,

                    MapMediaRole(kind),

                    mediaStorage,

                    mediaLifecycleService);

                throw;

            }

            if (durationResult.IsFailure)

            {

                await CleanupStoredUploadAsync(

                    storeResult.Value,

                    null,

                    MapMediaRole(kind),

                    mediaStorage,

                    mediaLifecycleService);

                return ToAdminTemplateProblem(durationResult.Error);

            }

            else

            {

                duration = durationResult.Value;

            }


            if (kind == TemplateAssetKind.Preview)

            {

                if (!duration.HasValue || duration.Value <= 0)

                {

                    metadataReader.ReleaseRetainedLocalPath(storeResult.Value);

                    await CleanupStoredUploadAsync(

                        storeResult.Value,

                        duration,

                        MapMediaRole(kind),

                        mediaStorage,

                        mediaLifecycleService);

                    return TypedResults.ValidationProblem(new Dictionary<string, string[]>

                    {

                        [nameof(file)] = ["templates.preview_duration_required"]

                    });

                }


                if (duration.Value < PreviewMinDurationSeconds || duration.Value > PreviewMaxDurationSeconds)

                {

                    metadataReader.ReleaseRetainedLocalPath(storeResult.Value);

                    await CleanupStoredUploadAsync(

                        storeResult.Value,

                        duration,

                        MapMediaRole(kind),

                        mediaStorage,

                        mediaLifecycleService);

                    return TypedResults.ValidationProblem(new Dictionary<string, string[]>

                    {

                        [nameof(file)] = ["templates.preview_duration_invalid"]

                    });

                }

            }

        }


        if (kind != TemplateAssetKind.Preview)

        {

            return TypedResults.Ok(ToUploadResponse(storeResult.Value, duration));

        }


        Result<TemplatePreviewOptimizationResult> optimizationResult;

        try

        {

            optimizationResult = await previewOptimizer.OptimizeAsync(

                storeResult.Value,

                duration,

                cancellationToken);

        }

        catch (OperationCanceledException)

        {

            await CleanupStoredUploadAsync(

                storeResult.Value,

                duration,

                TemplateMediaRole.PreviewAsset,

                mediaStorage,

                mediaLifecycleService);

            throw;

        }

        finally

        {

            metadataReader.ReleaseRetainedLocalPath(storeResult.Value);

        }


        if (optimizationResult.IsFailure)

        {

            await CleanupStoredUploadAsync(

                storeResult.Value,

                duration,

                TemplateMediaRole.PreviewAsset,

                mediaStorage,

                mediaLifecycleService);

            return ToAdminTemplateProblem(optimizationResult.Error);

        }


        var optimized = optimizationResult.Value;

        if (optimized.WasOptimized)

        {

            var optimizedAssets = new[]

            {

                optimized.PrimaryAsset,

                optimized.ThumbnailAsset,

                optimized.AnimatedPreviewAsset,

                optimized.FeedLoopLowAsset,

                optimized.FeedLoopMediumAsset,

                optimized.DetailPreviewAsset

            }

                .Where(asset => asset is not null)

                .DistinctBy(asset => asset!.Url.Trim());


            var distinctOptimizedAssets = optimizedAssets.ToArray();


            try

            {

                foreach (var asset in distinctOptimizedAssets)

                {

                    await mediaLifecycleService.RegisterTemporaryUploadAsync(

                        ToAssetCommand(asset!, duration),

                        TemplateMediaRole.PreviewAsset,

                        cancellationToken);

                }


                await mediaLifecycleService.SaveChangesAsync(cancellationToken);

            }

            catch

            {

                await RollbackOptimizedPreviewAsync(

                    distinctOptimizedAssets,

                    duration,

                    mediaStorage,

                    mediaLifecycleService);

                await CleanupStoredUploadAsync(

                    storeResult.Value,

                    duration,

                    TemplateMediaRole.PreviewAsset,

                    mediaStorage,

                    mediaLifecycleService);

                throw;

            }


            await CleanupStoredUploadAsync(

                storeResult.Value,

                duration,

                TemplateMediaRole.PreviewAsset,

                mediaStorage,

                mediaLifecycleService);

        }


        return TypedResults.Ok(ToUploadResponse(optimized, duration));

    }


    private static TemplateMediaUploadResponse ToUploadResponse(

        TemplatePreviewOptimizationResult optimized,

        double? duration)

    {

        var primary = ToAssetResponse(optimized.PrimaryAsset, duration)!;

        return new TemplateMediaUploadResponse(

            primary.Url,

            primary.FileName,

            primary.ContentType,

            primary.FileSizeBytes,

            primary.DurationSeconds,

            ToAssetResponse(optimized.ThumbnailAsset, duration),

            ToAssetResponse(optimized.AnimatedPreviewAsset, duration),

            ToAssetResponse(optimized.FeedLoopLowAsset, duration),

            ToAssetResponse(optimized.FeedLoopMediumAsset, duration),

            ToAssetResponse(optimized.DetailPreviewAsset, duration),

            optimized.WasOptimized);

    }


    private static TemplateMediaUploadResponse ToUploadResponse(StoredMediaResponse stored, double? duration)

    {

        var asset = ToAssetResponse(stored, duration)!;

        return new TemplateMediaUploadResponse(

            asset.Url,

            asset.FileName,

            asset.ContentType,

            asset.FileSizeBytes,

            asset.DurationSeconds);

    }


    private static TemplateAssetResponse? ToAssetResponse(StoredMediaResponse? stored, double? duration)

    {

        if (stored is null)

        {

            return null;

        }


        return new TemplateAssetResponse(

            stored.Url,

            stored.FileName,

            stored.ContentType,

            stored.FileSizeBytes,

            IsStoredVideo(stored) ? duration : null);

    }


    private static TemplateAssetCommand ToAssetCommand(StoredMediaResponse stored, double? duration)

    {

        return new TemplateAssetCommand(

            stored.Url,

            stored.FileName,

            stored.ContentType,

            stored.FileSizeBytes,

            IsStoredVideo(stored) ? duration : null);

    }


    private static bool IsStoredVideo(StoredMediaResponse stored)

    {

        return stored.ContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)

            || string.Equals(stored.ContentType, "application/mp4", StringComparison.OrdinalIgnoreCase);

    }


    private static async Task CleanupStoredUploadAsync(

        StoredMediaResponse original,

        double? duration,

        TemplateMediaRole role,

        IMediaStorage mediaStorage,

        ITemplateMediaLifecycleService mediaLifecycleService)

    {

        Result deleteResult;

        using var deleteSource = new CancellationTokenSource(TimeSpan.FromSeconds(MediaCleanupTimeoutSeconds));

        try

        {

            deleteResult = await mediaStorage.DeleteAsync(original.Url, deleteSource.Token);

        }

        catch

        {

            deleteResult = Result.Failure(new Error(

                "templates.media_storage_failed",

                "Original template preview cleanup failed."));

        }

        try

        {

            using var auditSource = new CancellationTokenSource(TimeSpan.FromSeconds(MediaCleanupTimeoutSeconds));

            await mediaLifecycleService.RegisterTemporaryUploadAsync(

                ToAssetCommand(original, duration),

                role,

                auditSource.Token);

            if (deleteResult.IsSuccess)

            {

                await mediaLifecycleService.MarkDeletedAsync(original.Url, auditSource.Token);

            }

            else

            {

                await mediaLifecycleService.MarkCleanupFailureAsync(

                    original.Url,

                    deleteResult.Error.Code,

                    "Original template preview cleanup failed.",

                    auditSource.Token);

            }


            await mediaLifecycleService.SaveChangesAsync(auditSource.Token);

        }

        catch

        {

            // Cleanup remains best effort so the original upload outcome stays authoritative.

        }

    }


    private static async Task RollbackOptimizedPreviewAsync(

        IEnumerable<StoredMediaResponse?> assets,

        double? duration,

        IMediaStorage mediaStorage,

        ITemplateMediaLifecycleService mediaLifecycleService)

    {

        var cleanupResults = new List<(StoredMediaResponse Asset, Result DeleteResult)>();

        using var deleteSource = new CancellationTokenSource(TimeSpan.FromSeconds(MediaCleanupTimeoutSeconds));

        foreach (var asset in assets.Where(asset => asset is not null).Reverse())

        {

            Result deleteResult;

            try

            {

                deleteResult = await mediaStorage.DeleteAsync(asset!.Url, deleteSource.Token);

            }

            catch

            {

                deleteResult = Result.Failure(new Error(

                    "templates.media_storage_failed",

                    "Optimized template preview cleanup failed."));

            }


            cleanupResults.Add((asset!, deleteResult));

        }


        try

        {

            using var auditSource = new CancellationTokenSource(TimeSpan.FromSeconds(MediaCleanupTimeoutSeconds));

            foreach (var (asset, deleteResult) in cleanupResults)

            {

                await mediaLifecycleService.RegisterTemporaryUploadAsync(

                    ToAssetCommand(asset, duration),

                    TemplateMediaRole.PreviewAsset,

                    auditSource.Token);


                if (deleteResult.IsSuccess)

                {

                    await mediaLifecycleService.MarkDeletedAsync(asset.Url, auditSource.Token);

                }

                else

                {

                    await mediaLifecycleService.MarkCleanupFailureAsync(

                        asset.Url,

                        deleteResult.Error.Code,

                        "Optimized template preview cleanup failed.",

                        auditSource.Token);

                }

            }


            await mediaLifecycleService.SaveChangesAsync(auditSource.Token);

        }

        catch

        {

            // The original lifecycle failure remains authoritative; cleanup is best effort.

        }

    }


    private static TemplateMediaRole MapMediaRole(TemplateAssetKind assetKind)

    {

        return assetKind switch

        {

            TemplateAssetKind.ReferenceMotion => TemplateMediaRole.ReferenceMotionAsset,

            _ => TemplateMediaRole.PreviewAsset

        };

    }


    private static bool IsAllowedUpload(string fileName, TemplateAssetKind assetKind, string contentType)

    {

        var normalizedContentType = NormalizeMediaContentType(contentType);


        if (assetKind == TemplateAssetKind.ReferenceMotion)

        {

            return IsAllowedReferenceMotionUpload(fileName, normalizedContentType);

        }


        return IsAllowedImageUpload(normalizedContentType)

            || IsAllowedVideoUpload(normalizedContentType);

    }


    private static bool IsPreviewIsoBmffMimeEquivalent(

        TemplateAssetKind assetKind,

        string detectedContentType,

        string declaredContentType)

    {

        if (assetKind != TemplateAssetKind.Preview)

        {

            return false;

        }


        var normalizedDeclared = TemplateUploadSniffer.NormalizeContentType(declaredContentType);

        return (string.Equals(detectedContentType, "video/mp4", StringComparison.OrdinalIgnoreCase)

                && string.Equals(normalizedDeclared, "video/quicktime", StringComparison.OrdinalIgnoreCase))

            || (string.Equals(detectedContentType, "video/quicktime", StringComparison.OrdinalIgnoreCase)

                && (string.Equals(normalizedDeclared, "video/mp4", StringComparison.OrdinalIgnoreCase)

                    || string.Equals(normalizedDeclared, "application/mp4", StringComparison.OrdinalIgnoreCase)));

    }


    private static bool TryGetAmbiguousStorageKey(Error error, out string storageKey)

    {

        storageKey = string.Empty;

        if (error.Metadata?.TryGetValue(AmbiguousStorageKeyMetadataName, out var value) != true

            || value is not string candidate)

        {

            return false;

        }


        var normalized = candidate.Trim().Replace('\\', '/').Trim('/');

        if (normalized.Length == 0

            || normalized.Length > 1024

            || normalized.Contains("://", StringComparison.Ordinal)

            || Path.IsPathRooted(normalized))

        {

            return false;

        }


        var segments = normalized.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        if (segments.Length < 2

            || segments.Any(segment => segment is "." or ".."

                || segment.Any(character => !(char.IsAsciiLetterOrDigit(character)

                    || character is '-' or '_' or '.'))))

        {

            return false;

        }


        storageKey = string.Join('/', segments);

        return true;

    }


    private static bool IsAllowedReferenceMotionUpload(string fileName, string contentType)

    {

        if (string.Equals(contentType, "video/mp4", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "application/mp4", StringComparison.OrdinalIgnoreCase))

        {

            return true;

        }


        if (!fileName.EndsWith(".mp4", StringComparison.OrdinalIgnoreCase))

        {

            return false;

        }


        return string.IsNullOrWhiteSpace(contentType)

            || string.Equals(contentType, "application/octet-stream", StringComparison.OrdinalIgnoreCase);

    }


    private static bool IsAllowedImageUpload(string contentType)

    {

        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/gif", StringComparison.OrdinalIgnoreCase);

    }


    private static bool IsAllowedVideoUpload(string contentType)

    {

        return string.Equals(contentType, "video/mp4", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "application/mp4", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "video/quicktime", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "video/webm", StringComparison.OrdinalIgnoreCase);

    }


    private static string NormalizeMediaContentType(string contentType)

    {

        if (string.IsNullOrWhiteSpace(contentType))

        {

            return string.Empty;

        }


        var separatorIndex = contentType.IndexOf(';');

        var normalized = separatorIndex >= 0

            ? contentType[..separatorIndex]

            : contentType;


        return normalized.Trim();

    }
}
