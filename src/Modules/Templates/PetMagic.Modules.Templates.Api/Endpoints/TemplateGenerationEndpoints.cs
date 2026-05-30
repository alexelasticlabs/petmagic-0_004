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
    private const string PremiumRequiredCode = "templates.premium_required";
    private const string PremiumRequiredMessage = "Premium subscription is required for this template.";

    public static IEndpointRouteBuilder MapTemplateGenerationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Template Generations")
            .RequireRateLimiting("templates")
            .RequireAuthorization(policy => policy
                .RequireAuthenticatedUser()
                .RequireAssertion(context =>
                    context.User.IsInRole("Admin")
                    || context.User.IsInRole("Moderator")
                    || !context.User.HasClaim(c => c.Type == "account_status")
                    || string.Equals(
                        context.User.FindFirst("account_status")?.Value,
                        "Active",
                        StringComparison.Ordinal)));

        group.MapPost("/{templateId:guid}/generations", StartGenerationAsync)
            .RequireAuthorization()
            .DisableAntiforgery();

        group.MapGet("/generations", ListGenerationsAsync)
            .RequireAuthorization();

        group.MapGet("/generations/unread-count", GetUnreadCountAsync)
            .RequireAuthorization();

        group.MapGet("/generations/{generationId:guid}", GetGenerationAsync)
            .RequireAuthorization();

        group.MapPost("/generations/{generationId:guid}/mark-read", MarkReadAsync)
            .RequireAuthorization();

        group.MapDelete("/generations/{generationId:guid}", DeleteGenerationAsync)
            .RequireAuthorization();

        group.MapPost("/generations/{generationId:guid}/feedback", RecordFeedbackAsync)
            .RequireAuthorization();

        group.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireAuthorization();

        group.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireAuthorization();

        return endpoints;
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartGenerationAsync(
        HttpContext context,
        Guid templateId,
        [FromForm] IFormFile? sourceImage,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] ITemplatesService templatesService,
        [FromServices] IValidator<StartTemplateGenerationCommand> validator,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var templateLookup = await templatesService.GetAdminAsync(templateId, cancellationToken);
        if (templateLookup.IsFailure)
        {
            return TypedResults.Problem(
                title: templateLookup.Error.Code,
                detail: templateLookup.Error.Message,
                statusCode: string.Equals(templateLookup.Error.Code, "templates.not_found", StringComparison.Ordinal)
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest);
        }

        if (templateLookup.Value.IsPremium && TryGetPremiumClaim(context.User, out var isPremium) && !isPremium)
        {
            return TypedResults.Problem(
                title: PremiumRequiredCode,
                detail: PremiumRequiredMessage,
                statusCode: StatusCodes.Status403Forbidden);
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

        var result = await generationService.StartAsync(command, cancellationToken);
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

    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> ListGenerationsAsync(
        HttpContext context,
        [FromQuery] string? status,
        [FromQuery] int? skip,
        [FromQuery] int? take,
        ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await generationService.ListAsync(
            userId!.Value,
            new TemplateGenerationHistoryQuery(status, skip, take),
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TemplateGenerationUnreadCountResponse>, ProblemHttpResult>> GetUnreadCountAsync(
        HttpContext context,
        ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await generationService.GetUnreadCountAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> MarkReadAsync(
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

        var result = await generationService.MarkReadAsync(userId!.Value, generationId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteGenerationAsync(
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

        var result = await generationService.DeleteAsync(userId!.Value, generationId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: result.Error.Code == "templates.not_found"
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext context,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await pushTokenService.RegisterAsync(
            new RegisterTemplatePushTokenCommand(
                userId!.Value,
                request.Token,
                request.Platform,
                request.DeviceId,
                request.AppVersion,
                request.Locale),
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext context,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] ITemplatePushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        await pushTokenService.UnregisterAsync(
            new UnregisterTemplatePushTokenCommand(userId!.Value, request.Token),
            cancellationToken);

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RecordFeedbackAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] RecordTemplateGenerationFeedbackRequest request,
        ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await generationService.RecordFeedbackAsync(
            new RecordTemplateGenerationFeedbackCommand(
                userId!.Value,
                generationId,
                request.Rating,
                request.SelectedReasons ?? [],
                request.Comment,
                request.InputPhotoQualityScore),
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: result.Error.Code == "templates.not_found"
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
    }

    private static Dictionary<string, string[]> ValidateSourceImage(IFormFile? sourceImage, long maxSizeBytes)
    {
        var errors = new Dictionary<string, string[]>();
        if (sourceImage is null || sourceImage.Length == 0)
        {
            errors[nameof(sourceImage)] = ["Source image is required."];
            return errors;
        }

        if (!sourceImage.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sourceImage.ContentType, "image/heic", StringComparison.OrdinalIgnoreCase)
            || string.Equals(sourceImage.ContentType, "image/heif", StringComparison.OrdinalIgnoreCase))
        {
            errors[nameof(sourceImage)] = ["Source image content type is not allowed. Please upload JPEG, PNG, or WebP."];
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
            "templates.image_model_required" => StatusCodes.Status409Conflict,
            "templates.invalid_image_model" => StatusCodes.Status400BadRequest,
            "templates.reference_motion_required" => StatusCodes.Status409Conflict,
            "templates.character_orientation_required" => StatusCodes.Status409Conflict,
            "templates.premium_required" => StatusCodes.Status403Forbidden,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static bool TryGetPremiumClaim(ClaimsPrincipal principal, out bool isPremium)
    {
        var premiumRaw = principal.FindFirstValue("premium");
        if (string.IsNullOrWhiteSpace(premiumRaw))
        {
            isPremium = false;
            return false;
        }

        isPremium = string.Equals(premiumRaw, "true", StringComparison.OrdinalIgnoreCase);
        return true;
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

    private sealed record RecordTemplateGenerationFeedbackRequest(int Rating, string[]? SelectedReasons, string? Comment, double? InputPhotoQualityScore);

    private sealed record RegisterPushTokenRequest(string Token, string Platform, string? DeviceId, string? AppVersion, string? Locale);

    private sealed record UnregisterPushTokenRequest(string Token);
}
