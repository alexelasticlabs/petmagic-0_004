using System.Security.Claims;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class PetEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = "Invalid access token subject.";
    private const int FreeActiveGenerationLimit = 1;
    private const int PremiumActiveGenerationLimit = 3;
    private const int PrivilegedActiveGenerationLimit = 10;
    private const int MaxIdempotencyKeyLength = 256;

    public static IEndpointRouteBuilder MapPetEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/pets")
            .WithTags("Pets")
            .RequireAuthorization();

        group.MapGet("", ListPetsAsync).RequireRateLimiting("templates");
        group.MapPost("", CreatePetAsync).RequireRateLimiting("templates");
        group.MapPut("/{petId:guid}", UpdatePetAsync).RequireRateLimiting("templates");
        group.MapDelete("/{petId:guid}", DeletePetAsync).RequireRateLimiting("templates");
        group.MapPost("/{petId:guid}/photos", UploadPhotoAsync)
            .RequireRateLimiting("templates")
            .DisableAntiforgery();
        group.MapGet("/{petId:guid}/photos", ListPhotosAsync).RequireRateLimiting("templates");
        group.MapPost("/{petId:guid}/photos/{photoId:guid}/set-avatar", SetAvatarAsync).RequireRateLimiting("templates");
        group.MapPost("/{petId:guid}/photos/{photoId:guid}/favorite", SetFavoriteAsync).RequireRateLimiting("templates");
        group.MapDelete("/{petId:guid}/photos/{photoId:guid}", DeletePhotoAsync).RequireRateLimiting("templates");
        group.MapGet("/{petId:guid}/generations", ListGenerationsAsync).RequireRateLimiting("generation-status");

        endpoints.MapPost("/api/generations/from-pet", StartFromPetAsync)
            .WithTags("Template Generations")
            .RequireAuthorization()
            .RequireRateLimiting("generation-create");

        var adminGroup = endpoints.MapGroup("/api/admin/users/{userId:guid}/pets")
            .WithTags("Admin Users")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        adminGroup.MapGet("", ListAdminPetsAsync);
        adminGroup.MapGet("/{petId:guid}/photos", ListAdminPetPhotosAsync);
        adminGroup.MapGet("/{petId:guid}/generations", ListAdminPetGenerationsAsync);
        adminGroup.MapPost("/{petId:guid}/status", ChangeAdminPetStatusAsync);
        adminGroup.MapPost("/{petId:guid}/photos/{photoId:guid}/status", ChangeAdminPhotoStatusAsync);

        return endpoints;
    }

    private static async Task<Results<Ok<IReadOnlyList<PetResponse>>, ProblemHttpResult>> ListPetsAsync(
        HttpContext context,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.ListAsync(userId!.Value, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Created<PetResponse>, ProblemHttpResult, ValidationProblem>> CreatePetAsync(
        HttpContext context,
        [FromBody] SavePetRequest request,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var validation = ValidatePet(request);
        if (validation.Count > 0)
        {
            return TypedResults.ValidationProblem(validation);
        }

        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.CreateAsync(new CreatePetCommand(userId!.Value, request.Name!, request.Type!, request.Breed), cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Created($"/api/pets/{result.Value.Id}", result.Value);
    }

    private static async Task<Results<Ok<PetResponse>, ProblemHttpResult, ValidationProblem>> UpdatePetAsync(
        HttpContext context,
        Guid petId,
        [FromBody] SavePetRequest request,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var validation = ValidatePet(request);
        if (validation.Count > 0)
        {
            return TypedResults.ValidationProblem(validation);
        }

        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.UpdateAsync(new UpdatePetCommand(userId!.Value, petId, request.Name!, request.Type!, request.Breed), cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeletePetAsync(
        HttpContext context,
        Guid petId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.DeleteAsync(userId!.Value, petId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.NoContent();
    }

    private static async Task<Results<Created<PetPhotoResponse>, ProblemHttpResult, ValidationProblem>> UploadPhotoAsync(
        HttpContext context,
        Guid petId,
        [FromForm] IFormFile? photo,
        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var validation = await ValidatePhotoAsync(photo, uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview), cancellationToken);
        if (validation.Count > 0)
        {
            return TypedResults.ValidationProblem(validation);
        }

        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var detectedContentType = (await TemplateUploadSniffer.DetectContentTypeAsync(photo!, cancellationToken))!;
        await using var stream = photo!.OpenReadStream();
        var result = await petsService.AddPhotoAsync(
            new UploadPetPhotoCommand(
                userId!.Value,
                petId,
                new MediaUploadCommand(Path.GetFileName(photo.FileName), detectedContentType, stream, photo.Length)),
            cancellationToken);

        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Created($"/api/pets/{petId}/photos/{result.Value.Id}", result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<PetPhotoResponse>>, ProblemHttpResult>> ListPhotosAsync(
        HttpContext context,
        Guid petId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.ListPhotosAsync(userId!.Value, petId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PetPhotoResponse>, ProblemHttpResult>> SetAvatarAsync(
        HttpContext context,
        Guid petId,
        Guid photoId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.SetAvatarAsync(userId!.Value, petId, photoId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PetPhotoResponse>, ProblemHttpResult>> SetFavoriteAsync(
        HttpContext context,
        Guid petId,
        Guid photoId,
        [FromBody] FavoritePhotoRequest request,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.SetFavoriteAsync(
            new SetPetPhotoFavoriteCommand(userId!.Value, petId, photoId, request.IsFavorite),
            cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeletePhotoAsync(
        HttpContext context,
        Guid petId,
        Guid photoId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await petsService.DeletePhotoAsync(userId!.Value, petId, photoId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.NoContent();
    }

    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> ListGenerationsAsync(
        HttpContext context,
        Guid petId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await petsService.ListGenerationsAsync(userId.Value, petId, isPremium, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartFromPetAsync(
        HttpContext context,
        [FromBody] StartFromPetRequest request,
        [FromServices] ITemplatesService templatesService,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var idempotencyKey = NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault());
        var validation = ValidateStartFromPet(request, idempotencyKey);
        if (validation.Count > 0)
        {
            return TypedResults.ValidationProblem(validation);
        }

        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var templateLookup = await templatesService.GetAdminAsync(request.TemplateId, cancellationToken);
        if (templateLookup.IsFailure)
        {
            return TypedResults.Problem(
                title: templateLookup.Error.Code,
                detail: templateLookup.Error.Message,
                statusCode: ResolveFailureStatusCode(templateLookup.Error));
        }

        if (templateLookup.Value.IsPremium && !await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken))
        {
            return TypedResults.Problem(
                title: "templates.premium_required",
                detail: "Premium subscription is required for this template.",
                statusCode: StatusCodes.Status403Forbidden);
        }

        var activeGenerationLimit = await ResolveActiveGenerationLimitAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.StartFromPetAsync(
            new StartTemplateGenerationFromPetCommand(
                userId.Value,
                request.PetId,
                request.PetPhotoId,
                request.TemplateId,
                idempotencyKey,
                activeGenerationLimit),
            cancellationToken);

        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<AdminPetResponse>>, ProblemHttpResult>> ListAdminPetsAsync(
        Guid userId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var result = await petsService.ListAdminUserPetsAsync(userId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<PetPhotoResponse>>, ProblemHttpResult>> ListAdminPetPhotosAsync(
        Guid userId,
        Guid petId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var result = await petsService.ListAdminPetPhotosAsync(userId, petId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> ListAdminPetGenerationsAsync(
        Guid userId,
        Guid petId,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var result = await petsService.ListAdminPetGenerationsAsync(userId, petId, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminPetResponse>, ProblemHttpResult>> ChangeAdminPetStatusAsync(
        Guid userId,
        Guid petId,
        [FromBody] AdminStatusRequest request,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var result = await petsService.ChangeAdminPetStatusAsync(userId, petId, request.Status, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PetPhotoResponse>, ProblemHttpResult>> ChangeAdminPhotoStatusAsync(
        Guid userId,
        Guid petId,
        Guid photoId,
        [FromBody] AdminStatusRequest request,
        [FromServices] IPetsService petsService,
        CancellationToken cancellationToken)
    {
        var result = await petsService.ChangeAdminPhotoStatusAsync(userId, petId, photoId, request.Status, cancellationToken);
        return result.IsFailure
            ? TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))
            : TypedResults.Ok(result.Value);
    }

    private static Dictionary<string, string[]> ValidatePet(SavePetRequest request)
    {
        var errors = new Dictionary<string, string[]>();
        if (string.IsNullOrWhiteSpace(request.Name) || request.Name.Trim().Length > 40)
        {
            errors[nameof(request.Name)] = ["Pet name is required and must be at most 40 characters."];
        }

        var type = request.Type?.Trim().ToLowerInvariant();
        if (type is not ("dog" or "cat" or "other"))
        {
            errors[nameof(request.Type)] = ["Pet type must be dog, cat, or other."];
        }

        if (request.Breed?.Trim().Length > 60)
        {
            errors[nameof(request.Breed)] = ["Breed must be at most 60 characters."];
        }

        return errors;
    }

    private static Dictionary<string, string[]> ValidateStartFromPet(StartFromPetRequest request, string? idempotencyKey)
    {
        var errors = new Dictionary<string, string[]>();
        if (request.PetId == Guid.Empty)
        {
            errors[nameof(request.PetId)] = ["Pet is required."];
        }

        if (request.TemplateId == Guid.Empty)
        {
            errors[nameof(request.TemplateId)] = ["Template is required."];
        }

        if (idempotencyKey?.Length > MaxIdempotencyKeyLength)
        {
            errors["Idempotency-Key"] = [$"Idempotency-Key must be at most {MaxIdempotencyKeyLength} characters."];
        }

        return errors;
    }

    private static string? NormalizeIdempotencyKey(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static async Task<Dictionary<string, string[]>> ValidatePhotoAsync(
        IFormFile? photo,
        long maxSizeBytes,
        CancellationToken cancellationToken)
    {
        var errors = new Dictionary<string, string[]>();
        if (photo is null || photo.Length == 0)
        {
            errors[nameof(photo)] = ["Photo is required."];
            return errors;
        }

        var detectedContentType = await TemplateUploadSniffer.DetectContentTypeAsync(photo, cancellationToken);
        if (detectedContentType is null
            || !IsAllowedPhotoContentType(detectedContentType)
            || !TemplateUploadSniffer.MatchesDeclaredContentType(detectedContentType, photo.ContentType))
        {
            errors[nameof(photo)] = ["Photo content type is not allowed. Please upload JPEG, PNG, WebP, or HEIC."];
        }

        if (photo.Length > maxSizeBytes)
        {
            errors[nameof(photo)] = [$"Photo exceeds the maximum allowed size of {maxSizeBytes} bytes."];
        }

        return errors;
    }

    private static bool IsAllowedPhotoContentType(string contentType)
    {
        return string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/png", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/heic", StringComparison.OrdinalIgnoreCase)
            || string.Equals(contentType, "image/heif", StringComparison.OrdinalIgnoreCase);
    }

    private static int ResolveFailureStatusCode(Error error)
    {
        return error.Code switch
        {
            "templates.not_found" or "pets.not_found" or "pets.photo_not_found" => StatusCodes.Status404NotFound,
            "pets.photo_required" => StatusCodes.Status409Conflict,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "GENERATION_QUEUE_OVERLOADED" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static async Task<int> ResolveActiveGenerationLimitAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (context.User.IsInRole("Admin") || context.User.IsInRole("Moderator"))
        {
            return PrivilegedActiveGenerationLimit;
        }

        return await HasPremiumTemplateAccessAsync(context, userId, cancellationToken)
            ? PremiumActiveGenerationLimit
            : FreeActiveGenerationLimit;
    }

    private static async Task<bool> HasPremiumTemplateAccessAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (context.User.IsInRole("Admin") || context.User.IsInRole("Moderator"))
        {
            return true;
        }

        var premiumRaw = context.User.FindFirstValue("premium");
        if (string.Equals(premiumRaw, "true", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var identityService = context.RequestServices.GetService<IIdentityService>();
        if (identityService is null)
        {
            return false;
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        return profile.IsSuccess && profile.Value.IsPremium;
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

    private sealed record SavePetRequest(string? Name, string? Type, string? Breed);

    private sealed record FavoritePhotoRequest(bool IsFavorite);

    private sealed record StartFromPetRequest(Guid PetId, Guid? PetPhotoId, Guid TemplateId);

    private sealed record AdminStatusRequest(string? Status);
}
