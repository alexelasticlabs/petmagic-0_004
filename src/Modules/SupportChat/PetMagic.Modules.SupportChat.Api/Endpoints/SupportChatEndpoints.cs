using System.Security.Claims;
using FluentValidation;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static class SupportChatEndpoints
{
    public static IEndpointRouteBuilder MapSupportChatEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var userGroup = endpoints.MapGroup("/api/support")
            .WithTags("Support")
            .RequireAuthorization();

        userGroup.MapPost("/conversation/open", OpenConversationAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapGet("/conversation", GetUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/messages", SendUserMessageAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/read", MarkUserReadAsync);

        var adminGroup = endpoints.MapGroup("/api/admin/support")
            .WithTags("Admin.Support")
            .RequireAuthorization("ModeratorOrAdmin");

        adminGroup.MapGet("/conversations", ListAdminInboxAsync);
        adminGroup.MapGet("/conversations/{conversationId:guid}", GetAdminConversationAsync);
        adminGroup.MapPost("/conversations/{conversationId:guid}/messages", SendAdminMessageAsync)
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/notes", SendAdminInternalNoteAsync)
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/read", MarkAdminReadAsync);
        adminGroup.MapPut("/conversations/{conversationId:guid}/status", UpdateConversationStatusAsync);
        adminGroup.MapPut("/conversations/{conversationId:guid}/assignment", AssignConversationAsync);
        adminGroup.MapGet("/templates", ListReplyTemplatesAsync);
        adminGroup.MapPost("/templates", CreateReplyTemplateAsync);
        adminGroup.MapPut("/templates/{templateId:guid}", UpdateReplyTemplateAsync);
        adminGroup.MapDelete("/templates/{templateId:guid}", DeleteReplyTemplateAsync);

        return endpoints;
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> OpenConversationAsync(
        HttpContext httpContext,
        [FromBody] OpenConversationRequest? request,
        [FromServices] IValidator<OpenSupportConversationCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new OpenSupportConversationCommand(
            userId,
            request?.InitialMessage,
            request?.Priority ?? SupportConversationPriority.Normal);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.OpenConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> GetUserConversationAsync(
        HttpContext httpContext,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.GetUserConversationAsync(userId, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendUserMessageAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SendSupportMessageRequest request,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SendSupportMessageCommand(conversationId, userId, request.Body, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SendMessageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> MarkUserReadAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<MarkSupportConversationReadCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new MarkSupportConversationReadCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.MarkConversationReadAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<IReadOnlyList<SupportConversationSummaryResponse>>, ProblemHttpResult>> ListAdminInboxAsync(
        HttpContext httpContext,
        [FromQuery] string? status,
        [FromQuery] string? assignment,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var normalizedAssignment = assignment?.Trim().ToLowerInvariant();
        if (normalizedAssignment is not null && normalizedAssignment is not ("all" or "mine" or "unassigned"))
        {
            return TypedResults.Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Validation error",
                detail: "Support inbox assignment filter is not supported.");
        }

        var query = normalizedAssignment switch
        {
            "mine" => new ListAdminSupportInboxQuery(status, AssignedAdminId: userId),
            "unassigned" => new ListAdminSupportInboxQuery(status, UnassignedOnly: true),
            _ => new ListAdminSupportInboxQuery(status)
        };

        var result = await service.ListAdminInboxAsync(query, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> GetAdminConversationAsync(
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminConversationAsync(conversationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminMessageAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SendSupportMessageRequest request,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SendSupportMessageCommand(conversationId, userId, request.Body, IsAdmin: true);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SendMessageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminInternalNoteAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SendSupportMessageRequest request,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SendSupportMessageCommand(conversationId, userId, request.Body, IsAdmin: true, IsInternalNote: true);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SendMessageAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> MarkAdminReadAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<MarkSupportConversationReadCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new MarkSupportConversationReadCommand(conversationId, userId, IsAdmin: true);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.MarkConversationReadAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> UpdateConversationStatusAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] UpdateSupportConversationStatusRequest request,
        [FromServices] IValidator<UpdateSupportConversationStatusCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!Enum.TryParse<SupportConversationStatus>(request.Status, true, out var status))
        {
            return TypedResults.Problem(
                title: "support.status_invalid",
                detail: "Support conversation status is not supported.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var command = new UpdateSupportConversationStatusCommand(conversationId, userId, status);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateConversationStatusAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> AssignConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] AssignSupportConversationRequest request,
        [FromServices] IValidator<AssignSupportConversationCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new AssignSupportConversationCommand(conversationId, userId, request.AssignedAdminId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.AssignConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<IReadOnlyList<SupportReplyTemplateResponse>>, ProblemHttpResult>> ListReplyTemplatesAsync(
        [FromServices] ISupportReplyTemplateCatalogService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListAdminTemplatesAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportReplyTemplateResponse>, ValidationProblem, ProblemHttpResult>> CreateReplyTemplateAsync(
        HttpContext httpContext,
        [FromBody] UpsertSupportReplyTemplateRequest request,
        [FromServices] IValidator<UpsertSupportReplyTemplateCommand> validator,
        [FromServices] ISupportReplyTemplateCatalogService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!TryParseTemplateKind(request.Kind, out var kind, out var invalidProblem))
        {
            return invalidProblem!;
        }

        var command = new UpsertSupportReplyTemplateCommand(null, userId, request.Title, request.Body, kind, request.IsEnabled, request.SortOrder);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpsertAdminTemplateAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportReplyTemplateResponse>, ValidationProblem, ProblemHttpResult>> UpdateReplyTemplateAsync(
        HttpContext httpContext,
        [FromRoute] Guid templateId,
        [FromBody] UpsertSupportReplyTemplateRequest request,
        [FromServices] IValidator<UpsertSupportReplyTemplateCommand> validator,
        [FromServices] ISupportReplyTemplateCatalogService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!TryParseTemplateKind(request.Kind, out var kind, out var invalidProblem))
        {
            return invalidProblem!;
        }

        var command = new UpsertSupportReplyTemplateCommand(templateId, userId, request.Title, request.Body, kind, request.IsEnabled, request.SortOrder);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpsertAdminTemplateAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ValidationProblem, ProblemHttpResult>> DeleteReplyTemplateAsync(
        HttpContext httpContext,
        [FromRoute] Guid templateId,
        [FromServices] IValidator<DeleteSupportReplyTemplateCommand> validator,
        [FromServices] ISupportReplyTemplateCatalogService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new DeleteSupportReplyTemplateCommand(templateId, userId);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.DeleteAdminTemplateAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static ProblemHttpResult ToProblem(PetMagic.BuildingBlocks.Results.Error error)
    {
        var statusCode = error.Code switch
        {
            "support.conversation_not_found" => StatusCodes.Status404NotFound,
            "support.template_not_found" => StatusCodes.Status404NotFound,
            "support.forbidden" => StatusCodes.Status403Forbidden,
            "support.invalid_subject" => StatusCodes.Status401Unauthorized,
            _ => StatusCodes.Status400BadRequest,
        };

        return TypedResults.Problem(title: error.Code, detail: error.Message, statusCode: statusCode);
    }

    private static bool TryGetUserId(HttpContext context, out Guid userId, out ProblemHttpResult? unauthorized)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (Guid.TryParse(subject, out userId))
        {
            unauthorized = null;
            return true;
        }

        unauthorized = TypedResults.Problem(
            title: "support.invalid_subject",
            detail: "Invalid access token subject.",
            statusCode: StatusCodes.Status401Unauthorized);
        return false;
    }

    private static bool TryParseTemplateKind(string kindRaw, out SupportReplyTemplateKind kind, out ProblemHttpResult? invalidProblem)
    {
        if (Enum.TryParse<SupportReplyTemplateKind>(kindRaw, true, out kind))
        {
            invalidProblem = null;
            return true;
        }

        invalidProblem = TypedResults.Problem(
            title: "support.template_kind_invalid",
            detail: "Support reply template kind is not supported.",
            statusCode: StatusCodes.Status400BadRequest);
        return false;
    }

    public sealed record OpenConversationRequest(string? InitialMessage, SupportConversationPriority Priority = SupportConversationPriority.Normal);

    public sealed record SendSupportMessageRequest(string Body);

    public sealed record UpdateSupportConversationStatusRequest(string Status);

    public sealed record AssignSupportConversationRequest(Guid? AssignedAdminId);

    public sealed record UpsertSupportReplyTemplateRequest(string Title, string Body, string Kind, bool IsEnabled = true, int SortOrder = 0);
}