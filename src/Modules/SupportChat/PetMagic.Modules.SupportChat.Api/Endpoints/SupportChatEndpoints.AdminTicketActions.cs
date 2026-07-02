using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> AssignConversationToMeAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.AssignConversationAsync(
            new AssignSupportConversationCommand(conversationId, userId, userId),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> UnassignConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.AssignConversationAsync(
            new AssignSupportConversationCommand(conversationId, userId, null),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> MarkConversationWaitingForUserAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.WaitingForUser,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> MarkConversationInProgressAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.InProgress,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> CloseAdminConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.Closed,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> ReopenAdminConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.InProgress,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> UpdateAdminConversationStatusAsync(
        HttpContext httpContext,
        Guid conversationId,
        SupportConversationStatus status,
        ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.UpdateConversationStatusAsync(
            new UpdateSupportConversationStatusCommand(conversationId, userId, status),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(result.Value, attachmentReadUrlSigner));
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

        var command = new UpsertSupportReplyTemplateCommand(null, userId, request.Title, request.Body, request.IsEnabled, request.SortOrder);
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

        var command = new UpsertSupportReplyTemplateCommand(templateId, userId, request.Title, request.Body, request.IsEnabled, request.SortOrder);
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

    private static ProblemHttpResult ToProblem(Error error)
    {
        var statusCode = error.Code switch
        {
            "support.conversation_not_found" => StatusCodes.Status404NotFound,
            "support.message_not_found" => StatusCodes.Status404NotFound,
            "support.template_not_found" => StatusCodes.Status404NotFound,
            "support.forbidden" => StatusCodes.Status403Forbidden,
            "support.status_transition_invalid" => StatusCodes.Status400BadRequest,
            "support.source_invalid" => StatusCodes.Status400BadRequest,
            "support.priority_invalid" => StatusCodes.Status400BadRequest,
            "support.sort_invalid" => StatusCodes.Status400BadRequest,
            "support.tags_invalid" => StatusCodes.Status400BadRequest,
            "support.invalid_subject" => StatusCodes.Status401Unauthorized,
            "support.attachment_invalid_upload" => StatusCodes.Status400BadRequest,
            "support.attachment_content_type_not_allowed" => StatusCodes.Status400BadRequest,
            "support.attachment_mime_mismatch" => StatusCodes.Status400BadRequest,
            "support.attachment_file_too_large" => StatusCodes.Status400BadRequest,
            "support.attachment_batch_limit_exceeded" => StatusCodes.Status400BadRequest,
            "support.attachment_storage_failed" => StatusCodes.Status400BadRequest,
            "support.attachment_retry_not_allowed" => StatusCodes.Status409Conflict,
            "support.conversation_read_only" => StatusCodes.Status409Conflict,
            "support.reopen_window_expired" => StatusCodes.Status409Conflict,
            "support.feedback_not_allowed" => StatusCodes.Status409Conflict,
            "support.feedback_rating_invalid" => StatusCodes.Status400BadRequest,
            "support.push_token_invalid" => StatusCodes.Status400BadRequest,
            "support.assigned_admin_invalid" => StatusCodes.Status400BadRequest,
            _ => StatusCodes.Status400BadRequest,
        };

        return TypedResults.Problem(title: error.Code, detail: GetProblemDetail(error.Code, statusCode), statusCode: statusCode);
    }

    private static ProblemHttpResult ToUserProblem(Error error)
    {
        if (error.Code == "support.forbidden")
        {
            return TypedResults.Problem(
                title: "support.conversation_not_found",
                detail: GetProblemDetail("support.conversation_not_found", StatusCodes.Status404NotFound),
                statusCode: StatusCodes.Status404NotFound);
        }

        return ToProblem(error);
    }

    private static string GetProblemDetail(string errorCode, int statusCode)
    {
        return errorCode switch
        {
            "support.conversation_not_found" => "Support conversation was not found.",
            "support.message_not_found" => "Support message was not found.",
            "support.template_not_found" => "Support reply template was not found.",
            "support.forbidden" => "Support action is not allowed for this user.",
            "support.status_transition_invalid" => "Support conversation state does not allow this action.",
            "support.source_invalid" => "Support conversation source is invalid.",
            "support.priority_invalid" => "Support conversation priority is invalid.",
            "support.sort_invalid" => "Support inbox sort is invalid.",
            "support.tags_invalid" => "Support conversation tags are invalid.",
            "support.invalid_subject" => "Authentication failed.",
            "support.attachment_invalid_upload" => "Support attachment upload is invalid.",
            "support.attachment_content_type_not_allowed" => "Support attachment content type is not allowed.",
            "support.attachment_mime_mismatch" => "Support attachment type does not match the uploaded file.",
            "support.attachment_file_too_large" => "Support attachment exceeds the maximum allowed size.",
            "support.attachment_batch_limit_exceeded" => "Support message allows too many attachments.",
            "support.attachment_storage_failed" => "Support attachment storage is temporarily unavailable.",
            "support.attachment_retry_not_allowed" => "Attachment retry is not allowed for this message state.",
            "support.conversation_read_only" => "Conversation is read-only.",
            "support.reopen_window_expired" => "Conversation can no longer be reopened.",
            "support.feedback_not_allowed" => "Support feedback is not allowed in the current conversation state.",
            "support.feedback_rating_invalid" => "Support feedback rating is invalid.",
            "support.push_token_invalid" => "Support push token is invalid.",
            "support.assigned_admin_invalid" => "Assigned support operator is invalid.",
            _ when statusCode == StatusCodes.Status404NotFound => "Requested support resource was not found.",
            _ when statusCode == StatusCodes.Status403Forbidden => "Support action is forbidden.",
            _ when statusCode == StatusCodes.Status401Unauthorized => "Support authentication is invalid.",
            _ when statusCode == StatusCodes.Status409Conflict => "Support request conflicts with the current resource state.",
            _ => "Support request could not be completed.",
        };
    }

    private static bool TryGetUserId(HttpContext context, out Guid userId, out ProblemHttpResult? unauthorized)
    {
        var subject = context.User.FindFirstValue("sub") ?? context.User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (Guid.TryParse(subject, out userId))
        {
            unauthorized = null;
            return true;
        }

        unauthorized = ToProblem(new Error(
            "support.invalid_subject",
            "Authentication failed."));
        return false;
    }

    private static string? ResolvePreferredLocale(string? requestLocale, HttpContext context)
    {
        if (!string.IsNullOrWhiteSpace(requestLocale))
        {
            return requestLocale.Trim();
        }

        var acceptLanguage = context.Request.Headers.AcceptLanguage.ToString();
        if (string.IsNullOrWhiteSpace(acceptLanguage))
        {
            return null;
        }

        return acceptLanguage.Split(',', 2, StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries).FirstOrDefault();
    }

    public sealed record OpenConversationRequest(
        string? InitialMessage,
        SupportConversationPriority Priority = SupportConversationPriority.Normal,
        SupportConversationSource Source = SupportConversationSource.MobileChat,
        string? AssistantScenario = null,
        Guid? RelatedGenerationId = null,
        Guid? RelatedPaymentId = null,
        Guid? RelatedSubscriptionId = null);

    public sealed record SendSupportMessageRequest(string Body, string? Locale = null, Guid? ReplyToMessageId = null);

    public sealed record UpdateSupportConversationStatusRequest(string Status);

    public sealed record AssignSupportConversationRequest(Guid? AssignedAdminId);

    public sealed record UpdateSupportConversationMetadataRequest(string Priority, IReadOnlyList<string>? Tags = null);

    public sealed record SubmitSupportConversationFeedbackRequest(int Rating, string? Comment = null);

    public sealed record RegisterPushTokenRequest(string Token, string? Platform, string? DeviceId, string? AppVersion, string? Locale);

    public sealed record UnregisterPushTokenRequest(string Token);

    public sealed record UpsertSupportReplyTemplateRequest(string Title, string Body, bool IsEnabled = true, int SortOrder = 0);
}
