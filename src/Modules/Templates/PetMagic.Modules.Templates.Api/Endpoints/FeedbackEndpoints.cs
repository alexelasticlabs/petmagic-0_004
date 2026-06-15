using System.Security.Claims;

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
    private const string InvalidSubjectMessage = "Invalid access token subject.";

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

    private static async Task<Results<Ok<SubmitFeedbackResponse>, ProblemHttpResult>> SubmitFeedbackAsync(
        HttpContext context,
        [FromBody] SubmitFeedbackRequest request,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return TypedResults.Problem(title: subjectError.Code, detail: subjectError.Message, statusCode: StatusCodes.Status401Unauthorized);
        }

        var result = await service.SubmitAsync(
            new SubmitFeedbackCommand(
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
                request.Locale),
            cancellationToken);

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

    private static async Task<Results<Ok<AdminFeedbackDetailsResponse>, ProblemHttpResult>> UpdateAdminFeedbackAsync(
        HttpContext context,
        Guid feedbackId,
        [FromBody] UpdateFeedbackAdminRequest request,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var adminUserId = ResolveAdminUserId(context);
        var result = await service.UpdateAdminAsync(
            new UpdateFeedbackAdminCommand(feedbackId, adminUserId, request.Status, request.Priority, request.AdminNote),
            cancellationToken);
        return result.IsFailure ? ToProblem(result.Error) : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<CreditRefundResponse>, ProblemHttpResult>> RefundAdminFeedbackAsync(
        HttpContext context,
        Guid feedbackId,
        [FromBody] RefundFeedbackCreditsRequest request,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var adminUserId = ResolveAdminUserId(context);
        var result = await service.RefundCreditsAsync(
            new RefundFeedbackCreditsCommand(feedbackId, adminUserId, request.Amount, request.Reason),
            cancellationToken);
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

    private static Guid ResolveAdminUserId(HttpContext context)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("sub");
        return Guid.TryParse(subject, out var userId) ? userId : Guid.Empty;
    }

    private static ProblemHttpResult ToProblem(Error error)
    {
        var statusCode = error.Code switch
        {
            "GENERATION_JOB_NOT_FOUND" or "feedback.not_found" => StatusCodes.Status404NotFound,
            "feedback.forbidden" => StatusCodes.Status403Forbidden,
            "feedback.rate_limited" => StatusCodes.Status429TooManyRequests,
            "feedback.refund_already_issued" => StatusCodes.Status409Conflict,
            _ => StatusCodes.Status400BadRequest
        };

        return TypedResults.Problem(title: error.Code, detail: error.Message, statusCode: statusCode);
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
