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

public static class AdminTemplateEndpoints
{
    public static IEndpointRouteBuilder MapAdminTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/templates")
            .WithTags("Admin.Templates")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("templates");

        group.MapGet("/", ListAsync);
        group.MapGet("/{templateId:guid}", GetAsync);
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
        var command = new UpdateImageTemplateCommand(templateId, request.Title, request.ShortDescription, request.Category, request.Tags, request.IsPremium, request.TokenCost, request.PromoBadgeMode, request.PreviewAsset, request.Status);
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
            request.Status);

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

    internal static async Task<Results<Ok<TemplateAssetResponse>, ValidationProblem, ProblemHttpResult>> UploadMediaAsync(
        [FromForm] IFormFile? file,
        [FromForm] string assetKind,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] ITemplateMediaLifecycleService mediaLifecycleService,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] IMediaMetadataReader metadataReader,
        CancellationToken cancellationToken)
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
        var contentType = file!.ContentType ?? "application/octet-stream";
        if (!IsAllowedContentType(kind, contentType))
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
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await mediaStorage.StoreAsync(
            new MediaUploadCommand(Path.GetFileName(file.FileName), contentType, memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            return TypedResults.Problem(title: storeResult.Error.Code, detail: storeResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        double? duration = null;
        if (contentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            var durationResult = await metadataReader.GetVideoDurationSecondsAsync(storeResult.Value, cancellationToken);
            if (durationResult.IsFailure)
            {
                await mediaStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
                return TypedResults.Problem(title: durationResult.Error.Code, detail: durationResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);
            }

            duration = durationResult.Value;
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

    private static TemplateMediaRole MapMediaRole(TemplateAssetKind assetKind)
    {
        return assetKind switch
        {
            TemplateAssetKind.ReferenceMotion => TemplateMediaRole.ReferenceMotionAsset,
            _ => TemplateMediaRole.PreviewAsset
        };
    }

    private static bool IsAllowedContentType(TemplateAssetKind assetKind, string contentType)
    {
        if (assetKind == TemplateAssetKind.ReferenceMotion)
        {
            return contentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase);
        }

        return contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            || contentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase);
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
        string? Status = null);

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
        string? Status = null);

    public sealed record ChangeTemplateStatusRequest(string Status);
}
