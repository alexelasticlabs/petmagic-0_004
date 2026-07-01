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

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class FeedbackEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = "Authentication failed.";

    public static IEndpointRouteBuilder MapFeedbackEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/feedback", SubmitFeedbackAsync)
            .WithTags("Feedback")
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        var admin = endpoints.MapGroup("/api/admin/feedback")
            .WithTags("Admin.Feedback")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        admin.MapGet("/", ListAdminFeedbackAsync);
        admin.MapGet("/{feedbackId:guid}", GetAdminFeedbackAsync);
        admin.MapPut("/{feedbackId:guid}", UpdateAdminFeedbackAsync);
        admin.MapPost("/{feedbackId:guid}/refund", RefundAdminFeedbackAsync)
            .RequireAuthorization("AdminOnly");

        endpoints.MapGet("/api/admin/templates/{templateId:guid}/feedback-summary", GetTemplateFeedbackSummaryAsync)
            .WithTags("Admin.Feedback")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        return endpoints;
    }

    private static async Task<Results<Ok<SubmitFeedbackResponse>, ValidationProblem, ProblemHttpResult>> SubmitFeedbackAsync(
        HttpContext context,
        [FromBody] SubmitFeedbackRequest request,
        [FromServices] IValidator<SubmitFeedbackCommand> validator,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToProblem(subjectError);
        }

        var command = new SubmitFeedbackCommand(
            userId,
            request.Type,
            request.Category,
            request.Rating,
            request.Message,
            request.GenerationId,
            request.TemplateId,
            request.PetId,
            request.SourceScreen,
            request.AppVersion,
            request.Platform,
            request.DeviceModel,
            request.Locale);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SubmitAsync(command, cancellationToken);

        return result.IsFailure
            ? ToProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminFeedbackPageResponse>, ProblemHttpResult>> ListAdminFeedbackAsync(
        [FromQuery] string? status,
        [FromQuery] string? priority,
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] Guid? generationId,
        [FromQuery] Guid? templateId,
        [FromQuery] string? platform,
        [FromQuery] DateTime? fromUtc,
        [FromQuery] DateTime? toUtc,
        [FromQuery] Guid? userId,
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminAsync(
            new AdminFeedbackQuery(status, priority, type, category, generationId, templateId, platform, fromUtc, toUtc, userId, skip, take),
            cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminFeedbackDetailsResponse>, ProblemHttpResult>> GetAdminFeedbackAsync(
        Guid feedbackId,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminAsync(feedbackId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<AdminFeedbackDetailsResponse>, ValidationProblem, ProblemHttpResult>> UpdateAdminFeedbackAsync(
        HttpContext context,
        Guid feedbackId,
        [FromBody] UpdateFeedbackAdminRequest request,
        [FromServices] IValidator<UpdateFeedbackAdminCommand> validator,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToProblem(subjectError);
        }

        var command = new UpdateFeedbackAdminCommand(
            feedbackId,
            adminUserId,
            request.Status,
            request.Priority,
            request.AdminNote);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateAdminAsync(command, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<CreditRefundResponse>, ValidationProblem, ProblemHttpResult>> RefundAdminFeedbackAsync(
        HttpContext context,
        Guid feedbackId,
        [FromBody] RefundFeedbackCreditsRequest request,
        [FromServices] IValidator<RefundFeedbackCreditsCommand> validator,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var (adminUserId, subjectError) = TryGetAdminUserId(context);
        if (subjectError is not null)
        {
            return ToProblem(subjectError);
        }

        var command = new RefundFeedbackCreditsCommand(
            feedbackId,
            adminUserId,
            request.Amount,
            request.Reason);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.RefundCreditsAsync(command, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TemplateFeedbackSummaryResponse>, ProblemHttpResult>> GetTemplateFeedbackSummaryAsync(
        Guid templateId,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetTemplateSummaryAsync(templateId, cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static (Guid? UserId, Error? Error) TryGetSubject(HttpContext context)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("sub");

        return Guid.TryParse(subject, out var userId)
            ? (userId, null)
            : (null, new Error(InvalidSubjectCode, InvalidSubjectMessage));
    }

    private static (Guid UserId, Error? Error) TryGetAdminUserId(HttpContext context)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("sub");

        return Guid.TryParse(subject, out var userId)
            ? (userId, null)
            : (Guid.Empty, new Error(InvalidSubjectCode, InvalidSubjectMessage));
    }

    private static ProblemHttpResult ToProblem(Error error)
    {
        var statusCode = error.Code switch
        {
            "templates.invalid_subject" => StatusCodes.Status401Unauthorized,
            "GENERATION_JOB_NOT_FOUND" or "feedback.not_found" => StatusCodes.Status404NotFound,
            "feedback.forbidden" => StatusCodes.Status403Forbidden,
            "feedback.rate_limited" => StatusCodes.Status429TooManyRequests,
            "feedback.refund_unavailable" => StatusCodes.Status409Conflict,
            "feedback.refund_already_issued" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return TypedResults.Problem(title: error.Code, detail: GetProblemDetail(error.Code, statusCode), statusCode: statusCode);
    }

    private static string GetProblemDetail(string errorCode, int statusCode)
    {
        return errorCode switch
        {
            "templates.invalid_subject" => "Authentication failed.",
            "GENERATION_JOB_NOT_FOUND" => "Generation was not found.",
            "feedback.not_found" => "Feedback entry was not found.",
            "feedback.forbidden" => "Feedback action is not allowed for this user.",
            "feedback.rate_limited" => "Feedback was submitted too frequently. Please try again later.",
            "feedback.refund_unavailable" => "Feedback refund is not available.",
            "feedback.refund_already_issued" => "Feedback refund has already been issued.",
            "feedback.invalid_refund_amount" => "Feedback refund amount is invalid.",
            _ when statusCode == StatusCodes.Status404NotFound => "Requested feedback resource was not found.",
            _ when statusCode == StatusCodes.Status403Forbidden => "Feedback action is forbidden.",
            _ when statusCode == StatusCodes.Status429TooManyRequests => "Too many feedback requests were sent. Please try again later.",
            _ when statusCode == StatusCodes.Status409Conflict => "Feedback request conflicts with the current resource state.",
            _ => "Feedback request could not be completed.",
        };
    }

    private sealed record SubmitFeedbackRequest(
        string Type,
        string Category,
        int? Rating,
        string? Message,
        Guid? GenerationId,
        Guid? TemplateId,
        Guid? PetId,
        string? SourceScreen,
        string? AppVersion,
        string? Platform,
        string? DeviceModel,
        string? Locale);

    private sealed record UpdateFeedbackAdminRequest(string? Status, string? Priority, string? AdminNote);

    private sealed record RefundFeedbackCreditsRequest(int? Amount, string? Reason);
}
