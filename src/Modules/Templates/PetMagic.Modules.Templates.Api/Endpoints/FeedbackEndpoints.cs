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
    private const string InvalidSubjectMessage = InvalidSubjectCode;
    private const int MaxFeedbackRequestBodyBytes = 8 * 1024;
    private const int MaxAdminFeedbackMutationRequestBodyBytes = 8 * 1024;

    public static IEndpointRouteBuilder MapFeedbackEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/feedback", SubmitFeedbackAsync)
            .WithTags("Feedback")
            .RequireAuthorization()
            .RequireRateLimiting("templates")
            .AddEndpointFilter(ApplyPrivateFeedbackResponseHeadersAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxFeedbackRequestBodyBytes));

        var admin = endpoints.MapGroup("/api/admin/feedback")
            .WithTags("Admin.Feedback")
            .RequireAuthorization("ModeratorOrAdmin")
            .AddEndpointFilter(ApplyPrivateFeedbackResponseHeadersAsync)
            .RequireRateLimiting("admin");

        admin.MapGet("/", ListAdminFeedbackAsync);
        admin.MapGet("/{feedbackId:guid}", GetAdminFeedbackAsync);
        admin.MapPut("/{feedbackId:guid}", UpdateAdminFeedbackAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminFeedbackMutationRequestBodyBytes));
        admin.MapPost("/{feedbackId:guid}/refund", RefundAdminFeedbackAsync)
            .RequireAuthorization("AdminOnly")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminFeedbackMutationRequestBodyBytes));

        endpoints.MapGet("/api/admin/templates/{templateId:guid}/feedback-summary", GetTemplateFeedbackSummaryAsync)
            .WithTags("Admin.Feedback")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin")
            .AddEndpointFilter(ApplyPrivateFeedbackResponseHeadersAsync);

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateFeedbackResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.SubmitAsync(command, cancellationToken);

        return result.IsFailure
            ? ToUserProblem(result.Error)
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
        HttpContext context,
        Guid feedbackId,
        [FromServices] IFeedbackService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminAsync(feedbackId, cancellationToken);
        return result.IsFailure
            ? ToProblem(result.Error)
            : TypedResults.Ok(RestrictAdminFeedbackDetailsForRole(context, result.Value));
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var result = await service.UpdateAdminAsync(command, cancellationToken);
        return result.IsFailure
            ? ToProblem(result.Error)
            : TypedResults.Ok(RestrictAdminFeedbackDetailsForRole(context, result.Value));
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
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

    private static AdminFeedbackDetailsResponse RestrictAdminFeedbackDetailsForRole(
        HttpContext context,
        AdminFeedbackDetailsResponse details)
    {
        return context.User.IsInRole("Admin")
            ? details
            : details with { CanRefund = false, Refund = null, RefundUnavailableReason = null };
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

        return TypedResults.Problem(
            title: error.Code,
            statusCode: statusCode,
            extensions: BuildProblemExtensions(error.Code));
    }

    private static ProblemHttpResult ToUserProblem(Error error)
    {
        if (error.Code == "feedback.forbidden")
        {
            return TypedResults.Problem(
                title: "feedback.not_found",
                statusCode: StatusCodes.Status404NotFound,
                extensions: BuildProblemExtensions("feedback.not_found"));
        }

        return ToProblem(error);
    }

    private static Dictionary<string, object?> BuildProblemExtensions(string errorCode)
    {
        return new Dictionary<string, object?> { ["code"] = errorCode };
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
