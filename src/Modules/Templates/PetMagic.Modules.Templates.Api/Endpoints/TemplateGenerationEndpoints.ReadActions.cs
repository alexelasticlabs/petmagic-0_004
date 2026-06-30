using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
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

    private sealed record RecordTemplateGenerationFeedbackRequest(int Rating, string[]? SelectedReasons, string? Comment, double? InputPhotoQualityScore);

    private sealed record RemoveWatermarkRequest(string? PaymentMethod);
}
