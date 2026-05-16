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

public static class TemplateGenerationEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = "Invalid access token subject.";

    public static IEndpointRouteBuilder MapTemplateGenerationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Template Generations")
            .RequireRateLimiting("templates");

        group.MapPost("/{templateId:guid}/generations", StartVideoGenerationAsync)
            .RequireAuthorization()
            .DisableAntiforgery();

        group.MapGet("/generations/{generationId:guid}", GetGenerationAsync)
            .RequireAuthorization();

        return endpoints;
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartVideoGenerationAsync(
        HttpContext context,
        Guid templateId,
        [FromForm] IFormFile? sourceImage,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] IValidator<StartTemplateGenerationCommand> validator,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var uploadValidation = ValidateSourceImage(sourceImage, uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview));
        if (uploadValidation.Count > 0)
        {
            return TypedResults.ValidationProblem(uploadValidation);
        }

        await using var stream = sourceImage!.OpenReadStream();
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await mediaStorage.StoreAsync(
            new MediaUploadCommand(Path.GetFileName(sourceImage.FileName), sourceImage.ContentType, memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            return TypedResults.Problem(title: storeResult.Error.Code, detail: storeResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        var stored = storeResult.Value;
        var command = new StartTemplateGenerationCommand(
            userId!.Value,
            templateId,
            new TemplateAssetCommand(stored.Url, stored.FileName, stored.ContentType, stored.FileSizeBytes, null));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await generationService.StartVideoAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            await mediaStorage.DeleteAsync(stored.Url, CancellationToken.None);
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
    }

    private static async Task<Results<Ok<TemplateGenerationResponse>, ProblemHttpResult>> GetGenerationAsync(
        HttpContext context,
        Guid generationId,
        ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await generationService.GetAsync(userId!.Value, generationId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static Dictionary<string, string[]> ValidateSourceImage(IFormFile? sourceImage, long maxSizeBytes)
    {
        var errors = new Dictionary<string, string[]>();
        if (sourceImage is null || sourceImage.Length == 0)
        {
            errors[nameof(sourceImage)] = ["Source image is required."];
            return errors;
        }

        if (!sourceImage.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            errors[nameof(sourceImage)] = ["Source image content type is not allowed."];
        }

        if (sourceImage.Length > maxSizeBytes)
        {
            errors[nameof(sourceImage)] = [$"Source image exceeds the maximum allowed size of {maxSizeBytes} bytes."];
        }

        return errors;
    }

    private static int ResolveFailureStatusCode(Error error)
    {
        return error.Code switch
        {
            "templates.not_found" => StatusCodes.Status404NotFound,
            "templates.invalid_status" => StatusCodes.Status409Conflict,
            "templates.type_mismatch" => StatusCodes.Status400BadRequest,
            "templates.reference_motion_required" => StatusCodes.Status409Conflict,
            "templates.character_orientation_required" => StatusCodes.Status409Conflict,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static (Guid? UserId, Error? Error) TryGetSubject(HttpContext context)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!Guid.TryParse(subject, out var userId))
        {
            return (null, new Error(InvalidSubjectCode, InvalidSubjectMessage));
        }

        return (userId, null);
    }
}
