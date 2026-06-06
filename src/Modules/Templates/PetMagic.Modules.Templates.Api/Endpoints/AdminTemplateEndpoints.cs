using FluentValidation;
using System.Globalization;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class AdminTemplateEndpoints
{
    private const double PreviewMinDurationSeconds = 0.5;
    private const double PreviewMaxDurationSeconds = 18.0;

    public static IEndpointRouteBuilder MapAdminTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/templates")
            .WithTags("Admin.Templates")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        group.MapGet("/", ListAsync);
        group.MapGet("/analytics", GetAnalyticsOverviewAsync);
        group.MapGet("/{templateId:guid}", GetAsync);
        group.MapGet("/{templateId:guid}/statistics", GetStatisticsAsync);
        group.MapGet("/{templateId:guid}/statistics/trends", GetTrendAsync);
        group.MapGet("/{templateId:guid}/statistics/recent", GetRecentAsync);
        group.MapGet("/{templateId:guid}/tests", GetTestHistoryAsync);
        group.MapGet("/{templateId:guid}/statistics/failures", GetFailureBreakdownAsync);
        group.MapGet("/{templateId:guid}/statistics/events", GetEventAnalyticsAsync);
        group.MapGet("/{templateId:guid}/statistics/feedback", GetFeedbackAsync);
        group.MapPost("/{templateId:guid}/test", StartAdminTestAsync)
            .DisableAntiforgery();
        group.MapGet("/tests/{generationId:guid}", GetAdminTestAsync);
        group.MapPost("/image", CreateImageAsync);
        group.MapPut("/image/{templateId:guid}", UpdateImageAsync);
        group.MapPost("/video", CreateVideoAsync);
        group.MapPut("/video/{templateId:guid}", UpdateVideoAsync);
        group.MapPut("/{templateId:guid}/status", ChangeStatusAsync);
        group.MapDelete("/{templateId:guid}", DeleteAsync);
        group.MapPost("/media/upload", UploadMediaAsync)
            .DisableAntiforgery();

        return endpoints;
    }

    private static async Task<Ok<IReadOnlyList<AdminTemplateListItemResponse>>> ListAsync(
        [FromQuery] string? type,
        [FromQuery] string? status,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var templateType = ParseType(type);
        var templateStatus = ParseStatus(status);
        var result = await service.ListAdminAsync(templateType, templateStatus, cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<AdminTemplatesAnalyticsOverviewResponse>> GetAnalyticsOverviewAsync(
        [FromQuery] int? periodDays,
        [FromQuery] string? templateType,
        [FromQuery] string? category,
        [FromQuery] string? status,
        [FromQuery] string? access,
        [FromQuery] string? sort,
        [FromQuery] int? take,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTemplatesAnalyticsAsync(
            new AdminTemplatesAnalyticsQuery(periodDays, templateType, category, status, access, sort, take),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ProblemHttpResult>> GetAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateStatisticsResponse>, ProblemHttpResult>> GetStatisticsAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminStatisticsAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateTrendPointResponse>>, ProblemHttpResult>> GetTrendAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTrendAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateRecentGenerationResponse>>, ProblemHttpResult>> GetRecentAsync(
        Guid templateId,
        [FromQuery] int? take,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var size = take.HasValue ? Math.Clamp(take.Value, 1, 250) : int.MaxValue;
        var result = await service.GetAdminRecentGenerationsAsync(templateId, size, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> GetTestHistoryAsync(
        Guid templateId,
        [FromQuery] int? take,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var size = take.HasValue ? Math.Clamp(take.Value, 1, 50) : 12;
        var result = await service.GetAdminTestHistoryAsync(templateId, size, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>, ProblemHttpResult>> GetFailureBreakdownAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminFailureBreakdownAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateEventAnalyticsResponse>, ProblemHttpResult>> GetEventAnalyticsAsync(
        Guid templateId,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminEventAnalyticsAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateFeedbackItemResponse>>, ProblemHttpResult>> GetFeedbackAsync(
        Guid templateId,
        [FromQuery] string? type,
        [FromQuery] string? search,
        [FromQuery] int? take,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminFeedbackAsync(
            templateId,
            new AdminTemplateFeedbackQuery(type, search, take),
            cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartAdminTestAsync(
        Guid templateId,
        [FromForm] IFormFile? sourceImage,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var uploadValidation = await ValidateSourceImageAsync(
            sourceImage,
            uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview),
            cancellationToken);
        if (uploadValidation.Count > 0)
        {
            return TypedResults.ValidationProblem(uploadValidation);
        }

        var detectedContentType = (await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage!, cancellationToken))!;
        await using var stream = sourceImage!.OpenReadStream();
        var storeResult = await mediaStorage.StoreAsync(
            new MediaUploadCommand(
                Path.GetFileName(sourceImage.FileName),
                detectedContentType,
                stream,
                sourceImage.Length),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            return TypedResults.Problem(title: storeResult.Error.Code, detail: storeResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        var stored = storeResult.Value;
        var result = await generationService.StartAdminTestAsync(
            templateId,
            new TemplateAssetCommand(stored.Url, stored.FileName, stored.ContentType, stored.FileSizeBytes, null),
            cancellationToken);

        if (result.IsFailure)
        {
            await mediaStorage.DeleteAsync(stored.Url, CancellationToken.None);
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveGenerationFailureStatusCode(result.Error));
        }

        return TypedResults.Accepted($"/api/admin/templates/tests/{result.Value.GenerationId}", result.Value);
    }

    private static async Task<Results<Ok<TemplateGenerationResponse>, ProblemHttpResult>> GetAdminTestAsync(
        Guid generationId,
        ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var result = await generationService.GetAdminAsync(generationId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> CreateImageAsync(
        [FromBody] CreateImageTemplateCommand command,
        [FromServices] IValidator<CreateImageTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateImageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> UpdateImageAsync(
        [FromRoute] Guid templateId,
        [FromBody] UpdateImageTemplateRequest request,
        [FromServices] IValidator<UpdateImageTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateImageTemplateCommand(templateId, request.Title, request.ShortDescription, request.Category, request.Tags, request.IsPremium, request.TokenCost, request.PromoBadgeMode, request.PreviewAsset, request.ImageModel, request.ImagePrompt, request.Status, request.PetPhotoRequirements);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateImageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> CreateVideoAsync(
        [FromBody] CreateVideoTemplateCommand command,
        [FromServices] IValidator<CreateVideoTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CreateVideoAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> UpdateVideoAsync(
        [FromRoute] Guid templateId,
        [FromBody] UpdateVideoTemplateRequest request,
        [FromServices] IValidator<UpdateVideoTemplateCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new UpdateVideoTemplateCommand(
            templateId,
            request.Title,
            request.ShortDescription,
            request.Category,
            request.Tags,
            request.IsPremium,
            request.TokenCost,
            request.PromoBadgeMode,
            request.MusicDescription,
            request.PreviewAsset,
            request.ReferenceMotionAsset,
            request.PreprocessingModel,
            request.PreprocessingPrompt,
            request.KlingModel,
            request.KlingPrompt,
            request.KeepOriginalSound,
            request.Status,
            request.PetPhotoRequirements);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateVideoAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminTemplateResponse>, ValidationProblem, ProblemHttpResult>> ChangeStatusAsync(
        [FromRoute] Guid templateId,
        [FromBody] ChangeTemplateStatusRequest request,
        [FromServices] IValidator<ChangeTemplateStatusCommand> validator,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var command = new ChangeTemplateStatusCommand(templateId, request.Status);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ChangeStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteAsync(
        [FromRoute] Guid templateId,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.DeleteAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            var statusCode = string.Equals(result.Error.Code, "templates.not_found", StringComparison.Ordinal)
                ? StatusCodes.Status404NotFound
                : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);
        }

        return TypedResults.NoContent();
    }

    private static TemplateType? ParseType(string? raw)
    {
        return Enum.TryParse<TemplateType>(raw, true, out var value) ? value : null;
    }

    private static TemplateStatus? ParseStatus(string? raw)
    {
        return Enum.TryParse<TemplateStatus>(raw, true, out var value) ? value : null;
    }

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

    public sealed record UpdateImageTemplateRequest(
        string Title,
        string ShortDescription,
        string Category,
        IReadOnlyList<string> Tags,
        bool IsPremium,
        int TokenCost,
        string PromoBadgeMode,
        TemplateAssetCommand? PreviewAsset,
        string ImageModel,
        string ImagePrompt,
        string? Status = null,
        IReadOnlyList<string>? PetPhotoRequirements = null);

    public sealed record UpdateVideoTemplateRequest(
        string Title,
        string ShortDescription,
        string Category,
        IReadOnlyList<string> Tags,
        bool IsPremium,
        int TokenCost,
        string PromoBadgeMode,
        string MusicDescription,
        TemplateAssetCommand? PreviewAsset,
        TemplateAssetCommand? ReferenceMotionAsset,
        string PreprocessingModel,
        string PreprocessingPrompt,
        string KlingModel,
        string KlingPrompt,
        bool KeepOriginalSound,
        string? Status = null,
        IReadOnlyList<string>? PetPhotoRequirements = null);

    public sealed record ChangeTemplateStatusRequest(string Status);
}
