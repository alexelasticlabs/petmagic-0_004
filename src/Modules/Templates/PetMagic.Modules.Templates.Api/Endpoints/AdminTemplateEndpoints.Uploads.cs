using System.Globalization;
using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

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

            errors[nameof(sourceImage)] = ["Source image is required."];

            return errors;

        }


        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage, cancellationToken);

        if (detectedContentType is null

            || !IsAllowedSourceImageContentType(detectedContentType)

            || !TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, sourceImage.ContentType))

        {

            errors[nameof(sourceImage)] = ["Source image content type is not allowed."];

        }


        if (sourceImage.Length > maxSizeBytes)

        {

            errors[nameof(sourceImage)] = [$"Source image exceeds the maximum allowed size of {maxSizeBytes} bytes."];

        }


        return errors;

    }


    private static bool IsAllowedSourceImageContentType(string contentType)

    {

        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)

            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase);

    }


    private static int ResolveGenerationFailureStatusCode(PetMagic.BuildingBlocks.Results.Error error)

    {

        return error.Code switch

        {

            "templates.not_found" => StatusCodes.Status404NotFound,

            "templates.invalid_status" => StatusCodes.Status409Conflict,

            "templates.type_mismatch" => StatusCodes.Status400BadRequest,

            "templates.image_model_required" => StatusCodes.Status409Conflict,

            "templates.invalid_image_model" => StatusCodes.Status400BadRequest,

            "templates.reference_motion_required" => StatusCodes.Status409Conflict,

            "templates.character_orientation_required" => StatusCodes.Status409Conflict,

            _ => StatusCodes.Status400BadRequest

        };

    }


    internal static async Task<Results<Ok<TemplateAssetResponse>, ValidationProblem, ProblemHttpResult>> UploadMediaAsync(

        [FromForm] IFormFile? file,

        [FromForm] string assetKind,

        [FromServices] IMediaStorage mediaStorage,

        [FromServices] ITemplateMediaLifecycleService mediaLifecycleService,

        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,

        [FromServices] IMediaMetadataReader metadataReader,

        CancellationToken cancellationToken,

        [FromForm] string? durationSeconds = null)

    {

        var errors = new Dictionary<string, string[]>();


        if (file is null || file.Length == 0)

        {

            errors[nameof(file)] = ["File is required."];

        }


        if (!Enum.TryParse<TemplateAssetKind>(assetKind, true, out var parsedAssetKind))

        {

            errors[nameof(assetKind)] = ["Asset kind is invalid."];

        }


        if (errors.Count > 0)

        {

            return TypedResults.ValidationProblem(errors);

        }


        var kind = parsedAssetKind;

        var declaredContentType = file!.ContentType ?? "application/octet-stream";

        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(file, cancellationToken);

        if (detectedContentType is null

            || !TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, declaredContentType)

            || !IsAllowedUpload(file.FileName, kind, detectedContentType))

        {

            return TypedResults.ValidationProblem(new Dictionary<string, string[]>

            {

                [nameof(file)] = ["File content type is not allowed for the selected asset kind."]

            });

        }


        var maxSize = uploadPolicy.GetMaxFileSizeBytes(kind);


        if (file.Length > maxSize)

        {

            return TypedResults.ValidationProblem(new Dictionary<string, string[]>

            {

                [nameof(file)] = [$"File exceeds the maximum allowed size of {maxSize} bytes."]

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

            return TypedResults.Problem(title: storeResult.Error.Code, detail: storeResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);

        }


        var storedContentType = string.IsNullOrWhiteSpace(storeResult.Value.ContentType)

            ? detectedContentType

            : storeResult.Value.ContentType;

        var providedDuration = ParseOptionalDuration(durationSeconds);


        double? duration = null;

        if (storedContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)

            || string.Equals(storedContentType, "application/mp4", StringComparison.OrdinalIgnoreCase))

        {

            var durationResult = await metadataReader.GetVideoDurationSecondsAsync(storeResult.Value, cancellationToken);

            if (durationResult.IsFailure)

            {

                if (providedDuration.HasValue && providedDuration.Value > 0)

                {

                    duration = providedDuration.Value;

                }

                else

                {

                    await mediaStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

                    return TypedResults.Problem(title: durationResult.Error.Code, detail: durationResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);

                }

            }

            else

            {

                duration = durationResult.Value;

            }


            if ((!duration.HasValue || duration.Value <= 0) && providedDuration.HasValue && providedDuration.Value > 0)

            {

                duration = providedDuration.Value;

            }


            if (kind == TemplateAssetKind.Preview)

            {

                if (!duration.HasValue || duration.Value <= 0)

                {

                    await mediaStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

                    return TypedResults.ValidationProblem(new Dictionary<string, string[]>

                    {

                        [nameof(file)] = ["Preview video duration metadata is required."]

                    });

                }


                if (duration.Value < PreviewMinDurationSeconds || duration.Value > PreviewMaxDurationSeconds)

                {

                    await mediaStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

                    return TypedResults.ValidationProblem(new Dictionary<string, string[]>

                    {

                        [nameof(file)] = [$"Preview video duration must be between {PreviewMinDurationSeconds:0.0} and {PreviewMaxDurationSeconds:0.0} seconds."]

                    });

                }

            }

        }


        await mediaLifecycleService.RegisterTemporaryUploadAsync(

            new TemplateAssetCommand(

                storeResult.Value.Url,

                storeResult.Value.FileName,

                storeResult.Value.ContentType,

                storeResult.Value.FileSizeBytes,

                duration),

            MapMediaRole(kind),

            cancellationToken);

        await mediaLifecycleService.SaveChangesAsync(cancellationToken);


        return TypedResults.Ok(new TemplateAssetResponse(

            storeResult.Value.Url,

            storeResult.Value.FileName,

            storeResult.Value.ContentType,

            storeResult.Value.FileSizeBytes,

            duration));

    }


    private static double? ParseOptionalDuration(string? rawValue)

    {

        if (string.IsNullOrWhiteSpace(rawValue))

        {

            return null;

        }


        if (!double.TryParse(rawValue, NumberStyles.Float, CultureInfo.InvariantCulture, out var parsed))

        {

            return null;

        }


        return parsed;

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
