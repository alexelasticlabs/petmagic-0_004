using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

using FluentValidation;

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

public static class TemplateGenerationEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = "Invalid access token subject.";
    private const string PremiumRequiredCode = "templates.premium_required";
    private const string PremiumRequiredMessage = "Premium subscription is required for this template.";
    private const int FreeActiveGenerationLimit = 1;
    private const int PremiumActiveGenerationLimit = 3;
    private const int PrivilegedActiveGenerationLimit = 10;
    private const int MaxIdempotencyKeyLength = 256;

    public static IEndpointRouteBuilder MapTemplateGenerationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Template Generations")
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
            .RequireRateLimiting("generation-create")
            .DisableAntiforgery();

        group.MapGet("/generation-results/{resultId:guid}/compatible-templates", GetCompatibleTemplatesAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/from-result", StartGenerationFromResultAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-create");

        group.MapPost("/generations/{generationId:guid}/generate-similar", GenerateSimilarAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-create");

        group.MapGet("/generations", ListGenerationsAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapGet("/generations/unread-count", GetUnreadCountAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapGet("/generations/{generationId:guid}", GetGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapPost("/generations/{generationId:guid}/remove-watermark", RemoveWatermarkAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapGet("/generations/{generationId:guid}/download", DownloadGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/share", ShareGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/mark-read", MarkReadAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapDelete("/generations/{generationId:guid}", DeleteGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/feedback", RecordFeedbackAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        return endpoints;
    }

    private static async Task<Results<Ok<CompatibleGenerationTemplatesResponse>, ProblemHttpResult>> GetCompatibleTemplatesAsync(
        HttpContext context,
        Guid resultId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await generationService.GetCompatibleTemplatesAsync(userId!.Value, resultId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartGenerationFromResultAsync(
        HttpContext context,
        [FromBody] StartGenerationFromResultRequest request,
        [FromServices] ITemplateGenerationService generationService,
        [FromServices] ITemplatesService templatesService,
        [FromServices] IValidator<StartTemplateGenerationFromResultCommand> validator,
        CancellationToken cancellationToken)
    {
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
                statusCode: string.Equals(templateLookup.Error.Code, "templates.not_found", StringComparison.Ordinal)
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest);
        }

        if (templateLookup.Value.IsPremium
            && !await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken))
        {
            return TypedResults.Problem(
                title: PremiumRequiredCode,
                detail: PremiumRequiredMessage,
                statusCode: StatusCodes.Status403Forbidden);
        }

        var command = new StartTemplateGenerationFromResultCommand(
            userId!.Value,
            request.ParentGenerationResultId,
            request.TemplateId,
            NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault()),
            await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await generationService.StartFromResultAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
    }

    private static async Task<Results<Accepted<GenerateSimilarResponse>, ProblemHttpResult, ValidationProblem>> GenerateSimilarAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] GenerateSimilarRequest? request,
        [FromServices] ITemplateGenerationService generationService,
        [FromServices] IValidator<StartSimilarTemplateGenerationCommand> validator,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new StartSimilarTemplateGenerationCommand(
            userId!.Value,
            generationId,
            string.IsNullOrWhiteSpace(request?.VariationStrength) ? "medium" : request!.VariationStrength!,
            NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault()),
            await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await generationService.StartSimilarAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        var response = new GenerateSimilarResponse(result.Value.GenerationId, result.Value.Status);
        return TypedResults.Accepted($"/api/templates/generations/{response.GenerationId}", response);
    }

    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartGenerationAsync(
        HttpContext context,
        Guid templateId,
        [FromForm] IFormFile? sourceImage,
        [FromServices] IMediaStorage mediaStorage,
        [FromServices] IImagePreviewGenerator imagePreviewGenerator,
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

        if (templateLookup.Value.IsPremium
            && !await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken))
        {
            return TypedResults.Problem(
                title: PremiumRequiredCode,
                detail: PremiumRequiredMessage,
                statusCode: StatusCodes.Status403Forbidden);
        }

        var uploadValidation = await ValidateSourceImageAsync(
            sourceImage,
            uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview),
            cancellationToken);
        var idempotencyKey = NormalizeIdempotencyKey(context.Request.Headers["Idempotency-Key"].FirstOrDefault());
        if (idempotencyKey?.Length > MaxIdempotencyKeyLength)
        {
            uploadValidation["Idempotency-Key"] = [$"Idempotency-Key must be at most {MaxIdempotencyKeyLength} characters."];
        }

        if (uploadValidation.Count > 0)
        {
            return TypedResults.ValidationProblem(uploadValidation);
        }

        var sourceImageHash = await ComputeSha256HexAsync(sourceImage!, cancellationToken);
        var requestHash = ComputeRequestHash(userId!.Value, templateId, sourceImageHash);
        var activeGenerationLimit = await ResolveActiveGenerationLimitAsync(context, userId.Value, cancellationToken);

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
        var preview = await imagePreviewGenerator.CreatePreviewAsync(
            stored,
            $"{Path.GetFileNameWithoutExtension(stored.FileName)}-preview.webp",
            preferredStorageKey: null,
            cancellationToken);
        try
        {
            var command = new StartTemplateGenerationCommand(
                UserId: userId!.Value,
                TemplateId: templateId,
                SourceImageAsset: new TemplateAssetCommand(stored.Url, stored.FileName, stored.ContentType, stored.FileSizeBytes, null),
                SourceImagePreviewAsset: preview is null
                    ? null
                    : new TemplateAssetCommand(preview.Url, preview.FileName, preview.ContentType, preview.FileSizeBytes, null),
                IdempotencyKey: idempotencyKey,
                RequestHash: requestHash,
                ActiveGenerationLimit: activeGenerationLimit);

            var validation = await validator.ValidateAsync(command, cancellationToken);
            if (!validation.IsValid)
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
                return TypedResults.ValidationProblem(validation.ToDictionary());
            }

            var result = await generationService.StartAsync(command, cancellationToken);
            if (result.IsFailure)
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
                return TypedResults.Problem(
                    title: result.Error.Code,
                    detail: result.Error.Message,
                    statusCode: ResolveFailureStatusCode(result.Error));
            }

            if (!string.Equals(result.Value.SourceImageAsset?.FileName, stored.FileName, StringComparison.Ordinal)
                || !string.Equals(result.Value.SourceImageAsset?.ContentType, stored.ContentType, StringComparison.OrdinalIgnoreCase))
            {
                await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
            }

            return TypedResults.Accepted($"/api/templates/generations/{result.Value.GenerationId}", result.Value);
        }
        catch
        {
            await DeleteUploadedGenerationMediaAsync(mediaStorage, stored, preview);
            throw;
        }
    }

    private static async Task DeleteUploadedGenerationMediaAsync(
        IMediaStorage mediaStorage,
        StoredMediaResponse stored,
        StoredMediaResponse? preview)
    {
        IEnumerable<string> urls = preview is null
            ? [stored.Url]
            : new[] { stored.Url, preview.Url }.Distinct(StringComparer.OrdinalIgnoreCase);

        foreach (var url in urls)
        {
            await mediaStorage.DeleteAsync(url, CancellationToken.None);
        }
    }

    private static async Task<Results<Ok<TemplateGenerationResponse>, ProblemHttpResult>> GetGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<RemoveGenerationWatermarkResponse>, ProblemHttpResult>> RemoveWatermarkAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] RemoveWatermarkRequest? request,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.RemoveWatermarkAsync(
            new RemoveGenerationWatermarkCommand(
                userId.Value,
                generationId,
                request?.PaymentMethod ?? "credit",
                isPremium),
            cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<GenerationDownloadResponse>, ProblemHttpResult>> DownloadGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetDownloadAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<GenerationDownloadResponse>, ProblemHttpResult>> ShareGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetShareAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(
                title: result.Error.Code,
                detail: result.Error.Message,
                statusCode: ResolveFailureStatusCode(result.Error));
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> ListGenerationsAsync(
        HttpContext context,
        [FromQuery] string? status,
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var filterProblem = ValidateGenerationFilters(status);
        if (filterProblem is not null)
        {
            return filterProblem;
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.ListAsync(
            userId!.Value,
            new TemplateGenerationHistoryQuery(status, skip, take),
            isPremium,
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status400BadRequest);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TemplateGenerationUnreadCountResponse>, ProblemHttpResult>> GetUnreadCountAsync(
        HttpContext context,
        [FromServices] ITemplateGenerationService generationService,
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
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.MarkReadAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.NoContent();
    }

    private static ProblemHttpResult? ValidateGenerationFilters(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
        {
            return null;
        }

        var normalized = status.Trim();
        if (string.Equals(normalized, "all", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return IsOneOf(
                normalized,
                "active",
                "pending",
                "running",
                "completed",
                "failed",
                "cancelled",
                "retrying",
                "preprocessing",
                "generating",
                "finalizing")
            ? null
            : TypedResults.Problem(
                title: "templates.invalid_status",
                detail: "Query parameter status must be one of: active, pending, running, completed, failed, cancelled, retrying, preprocessing, generating, finalizing.",
                statusCode: StatusCodes.Status400BadRequest);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
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
                statusCode: IsNotFoundError(result.Error)
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
        [FromServices] ITemplateGenerationService generationService,
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
                statusCode: IsNotFoundError(result.Error)
                    ? StatusCodes.Status404NotFound
                    : StatusCodes.Status400BadRequest);
        }

        return TypedResults.NoContent();
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
            errors[nameof(sourceImage)] = ["Source image content type is not allowed. Please upload JPEG, PNG, or WebP."];
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

    private static bool IsOneOf(string value, params string[] allowedValues)
    {
        return allowedValues.Any(allowed => string.Equals(allowed, value, StringComparison.OrdinalIgnoreCase));
    }

    private static int ResolveFailureStatusCode(Error error)
    {
        return error.Code switch
        {
            "templates.not_found" => StatusCodes.Status404NotFound,
            "GENERATION_JOB_NOT_FOUND" => StatusCodes.Status404NotFound,
            "templates.invalid_status" => StatusCodes.Status409Conflict,
            "templates.type_mismatch" => StatusCodes.Status400BadRequest,
            "templates.generation_result_input_unavailable" => StatusCodes.Status409Conflict,
            "templates.generation_result_input_unsupported" => StatusCodes.Status400BadRequest,
            "templates.image_model_required" => StatusCodes.Status409Conflict,
            "templates.invalid_image_model" => StatusCodes.Status400BadRequest,
            "templates.reference_motion_required" => StatusCodes.Status409Conflict,
            "templates.character_orientation_required" => StatusCodes.Status409Conflict,
            "templates.premium_required" => StatusCodes.Status403Forbidden,
            "economy.insufficient_balance" => StatusCodes.Status402PaymentRequired,
            "templates.watermark_not_ready" => StatusCodes.Status202Accepted,
            "ACTIVE_GENERATION_LIMIT_REACHED" => StatusCodes.Status429TooManyRequests,
            "GENERATION_QUEUE_OVERLOADED" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status400BadRequest
        };
    }

    private static bool IsNotFoundError(Error error)
    {
        return string.Equals(error.Code, "templates.not_found", StringComparison.Ordinal)
            || string.Equals(error.Code, "GENERATION_JOB_NOT_FOUND", StringComparison.Ordinal);
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

    private static bool IsPrivilegedTemplateUser(ClaimsPrincipal principal)
    {
        return principal.IsInRole("Admin") || principal.IsInRole("Moderator");
    }

    private static async Task<int> ResolveActiveGenerationLimitAsync(
        HttpContext context,
        Guid userId,
        CancellationToken cancellationToken)
    {
        if (IsPrivilegedTemplateUser(context.User))
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
        if (IsPrivilegedTemplateUser(context.User))
        {
            return true;
        }

        var hasPremiumClaim = TryGetPremiumClaim(context.User, out var claimPremiumValue);
        if (hasPremiumClaim && claimPremiumValue)
        {
            return true;
        }

        var identityService = context.RequestServices.GetService<IIdentityService>();
        if (identityService is null)
        {
            return hasPremiumClaim && claimPremiumValue;
        }

        var profile = await identityService.GetCurrentUserAsync(userId, cancellationToken);
        return profile.IsSuccess && profile.Value.IsPremium;
    }

    private static string? NormalizeIdempotencyKey(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static async Task<string> ComputeSha256HexAsync(IFormFile file, CancellationToken cancellationToken)
    {
        await using var stream = file.OpenReadStream();
        using var sha256 = SHA256.Create();
        var hashBytes = await sha256.ComputeHashAsync(stream, cancellationToken);
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
    }

    private static string ComputeRequestHash(Guid userId, Guid templateId, string sourceImageHash)
    {
        var material = $"{userId:N}:{templateId:N}:{sourceImageHash}";
        var hashBytes = SHA256.HashData(Encoding.UTF8.GetBytes(material));
        return Convert.ToHexString(hashBytes).ToLowerInvariant();
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

    private sealed record RemoveWatermarkRequest(string? PaymentMethod);

    private sealed record StartGenerationFromResultRequest(Guid ParentGenerationResultId, Guid TemplateId);
}
