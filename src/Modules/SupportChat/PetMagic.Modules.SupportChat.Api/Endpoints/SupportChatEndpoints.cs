using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static class SupportChatEndpoints
{
    private const int AttachmentBatchMaxCount = 5;

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
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/attachments", SendUserAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/attachments", SendUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryUserAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        userGroup.MapPost("/conversation/{conversationId:guid}/read", MarkUserReadAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/resolve", ResolveUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/close", CloseUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/reopen", ReopenUserConversationAsync);
        userGroup.MapPost("/conversation/{conversationId:guid}/feedback", SubmitUserConversationFeedbackAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireRateLimiting("support-chat");
        userGroup.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireRateLimiting("support-chat");

        var adminGroup = endpoints.MapGroup("/api/admin/support")
            .WithTags("Admin.Support")
            .RequireAuthorization("ModeratorOrAdmin");

        adminGroup.MapGet("/conversations", ListAdminInboxAsync);
        adminGroup.MapGet("/conversations/{conversationId:guid}", GetAdminConversationAsync);
        adminGroup.MapPost("/conversations/{conversationId:guid}/messages", SendAdminMessageAsync)
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/messages/attachments", SendAdminAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/attachments", SendAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", RetryAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/conversations/{conversationId:guid}/read", MarkAdminReadAsync);
        adminGroup.MapPut("/conversations/{conversationId:guid}/status", UpdateConversationStatusAsync);
        adminGroup.MapPut("/conversations/{conversationId:guid}/assignment", AssignConversationAsync);
        adminGroup.MapPut("/conversations/{conversationId:guid}/metadata", UpdateConversationMetadataAsync);
        adminGroup.MapGet("/tickets", ListAdminInboxAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}", GetAdminConversationAsync);
        adminGroup.MapGet("/tickets/{conversationId:guid}/context", GetAdminTicketContextAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/assign-to-me", AssignConversationToMeAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/unassign", UnassignConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-waiting-for-user", MarkConversationWaitingForUserAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/mark-in-progress", MarkConversationInProgressAsync);
        adminGroup.MapPut("/tickets/{conversationId:guid}/metadata", UpdateConversationMetadataAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/close", CloseAdminConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/reopen", ReopenAdminConversationAsync);
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages", SendAdminMessageAsync)
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/messages/attachments", SendAdminAttachmentsAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/attachments", SendAdminAttachmentAsync)
            .DisableAntiforgery()
            .RequireRateLimiting("support-chat");
        adminGroup.MapPost("/tickets/{conversationId:guid}/read", MarkAdminReadAsync);
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
            request?.Priority ?? SupportConversationPriority.Normal,
            request?.Source ?? SupportConversationSource.MobileChat,
            request?.AssistantScenario,
            request?.RelatedGenerationId,
            request?.RelatedPaymentId,
            request?.RelatedSubscriptionId);
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
        [FromQuery] int? take,
        [FromQuery] DateTime? beforeMessageCreatedAtUtc,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await service.GetUserConversationAsync(
            userId,
            new SupportConversationMessagesQuery(
                Take: take ?? 60,
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc),
            cancellationToken);
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

        var command = new SendSupportMessageCommand(
            conversationId,
            userId,
            request.Body,
            IsAdmin: false,
            ReplyToMessageId: request.ReplyToMessageId,
            Locale: ResolvePreferredLocale(request.Locale, httpContext));
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

    private static Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendUserAttachmentsAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<SendSupportAttachmentsCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return SendAttachmentsCoreAsync(
            httpContext,
            conversationId,
            isAdmin: false,
            validator,
            attachmentStorage,
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendUserAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromForm] IFormFile? file,
        [FromForm] string? body,
        [FromForm] string? locale,
        [FromForm] Guid? replyToMessageId,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";
        var normalizedBody = string.IsNullOrWhiteSpace(body)
            ? Path.GetFileName(file.FileName)
            : body.Trim();

        var createMessageResult = await service.CreateAttachmentMessageAsync(
            new CreateSupportAttachmentMessageCommand(
                conversationId,
                userId,
                normalizedBody,
                IsAdmin: false,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType,
                ReplyToMessageId: replyToMessageId,
                Locale: ResolvePreferredLocale(locale, httpContext)),
            cancellationToken);

        if (createMessageResult.IsFailure)
        {
            return ToProblem(createMessageResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                file.ContentType ?? "application/octet-stream",
                memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: false,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: false,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: completeStatusResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(completeStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        return TypedResults.Ok(completeStatusResult.Value);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromForm] IFormFile? file,
        [FromForm] string? body,
        [FromForm] Guid? replyToMessageId,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";
        var normalizedBody = string.IsNullOrWhiteSpace(body)
            ? Path.GetFileName(file.FileName)
            : body.Trim();

        var createMessageResult = await service.CreateAttachmentMessageAsync(
            new CreateSupportAttachmentMessageCommand(
                conversationId,
                userId,
                normalizedBody,
                IsAdmin: true,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType,
                ReplyToMessageId: replyToMessageId),
            cancellationToken);

        if (createMessageResult.IsFailure)
        {
            return ToProblem(createMessageResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                file.ContentType ?? "application/octet-stream",
                memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                createMessageResult.Value.MessageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);

            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    createMessageResult.Value.MessageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: completeStatusResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(completeStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        return TypedResults.Ok(completeStatusResult.Value);
    }

    private static Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAdminAttachmentsAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<SendSupportAttachmentsCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return SendAttachmentsCoreAsync(
            httpContext,
            conversationId,
            isAdmin: true,
            validator,
            attachmentStorage,
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> RetryUserAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromRoute] Guid messageId,
        [FromForm] IFormFile? file,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";

        var retryStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Retry,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (retryStatusResult.IsFailure)
        {
            return ToProblem(retryStatusResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                requestedContentType,
                memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    messageId,
                    userId,
                    IsAdmin: false,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: false,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
            return ToProblem(completeStatusResult.Error);
        }

        return TypedResults.Ok(completeStatusResult.Value);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAttachmentsCoreAsync(
        HttpContext httpContext,
        Guid conversationId,
        bool isAdmin,
        IValidator<SendSupportAttachmentsCommand> validator,
        ISupportAttachmentStorage attachmentStorage,
        ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var form = await httpContext.Request.ReadFormAsync(cancellationToken);
        var files = form.Files.Where(file => file.Length > 0).ToList();
        if (files.Count == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                ["files"] = ["At least one support attachment file is required."]
            });
        }

        if (files.Count > AttachmentBatchMaxCount)
        {
            return ToProblem(new Error(
                "support.attachment_batch_limit_exceeded",
                $"Cannot upload more than {AttachmentBatchMaxCount} attachments in a single message."));
        }

        var storedAttachments = new List<StoredSupportAttachmentResponse>(files.Count);
        foreach (var file in files)
        {
            await using var stream = file.OpenReadStream();
            using var memoryStream = new MemoryStream();
            await stream.CopyToAsync(memoryStream, cancellationToken);

            var storeResult = await attachmentStorage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    Path.GetFileName(file.FileName),
                    file.ContentType ?? "application/octet-stream",
                    memoryStream.ToArray()),
                cancellationToken);

            if (storeResult.IsFailure)
            {
                await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
                return ToProblem(storeResult.Error);
            }

            storedAttachments.Add(storeResult.Value);
        }

        var rawBody = form.TryGetValue("body", out var bodyValue)
            ? bodyValue.ToString()
            : string.Empty;
        var locale = form.TryGetValue("locale", out var localeValue)
            ? localeValue.ToString()
            : null;
        var replyToMessageId = form.TryGetValue("replyToMessageId", out var replyToMessageValue)
            && Guid.TryParse(replyToMessageValue.ToString(), out var parsedReplyToMessageId)
                ? parsedReplyToMessageId
                : (Guid?)null;

        var command = new SendSupportAttachmentsCommand(
            conversationId,
            userId,
            rawBody.Trim(),
            isAdmin,
            storedAttachments
                .Select(attachment => new SupportMessageAttachmentInput(
                    attachment.Url,
                    attachment.ContentType,
                    attachment.FileName,
                    attachment.FileSizeBytes,
                    StorageKey: attachment.StorageKey))
                .ToList(),
            ReplyToMessageId: replyToMessageId,
            Locale: isAdmin ? null : ResolvePreferredLocale(locale, httpContext));

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var sendResult = await service.SendMessageWithAttachmentsAsync(command, cancellationToken);
        if (sendResult.IsFailure)
        {
            await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
            return ToProblem(sendResult.Error);
        }

        return TypedResults.Ok(sendResult.Value);
    }

    private static async Task CleanupStoredAttachmentsAsync(
        IReadOnlyList<StoredSupportAttachmentResponse> storedAttachments,
        ISupportAttachmentStorage attachmentStorage)
    {
        if (storedAttachments.Count == 0)
        {
            return;
        }

        foreach (var attachment in storedAttachments)
        {
            await attachmentStorage.DeleteAsync(attachment.Url, CancellationToken.None);
        }
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> RetryAdminAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromRoute] Guid messageId,
        [FromForm] IFormFile? file,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (file is null || file.Length == 0)
        {
            return TypedResults.ValidationProblem(new Dictionary<string, string[]>
            {
                [nameof(file)] = ["Support attachment file is required."]
            });
        }

        var requestedContentType = file.ContentType ?? "application/octet-stream";

        var retryStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Retry,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (retryStatusResult.IsFailure)
        {
            return ToProblem(retryStatusResult.Error);
        }

        var uploadingStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploading,
                AttachmentFileName: Path.GetFileName(file.FileName),
                AttachmentContentType: requestedContentType),
            cancellationToken);

        if (uploadingStatusResult.IsFailure)
        {
            return ToProblem(uploadingStatusResult.Error);
        }

        await using var stream = file.OpenReadStream();
        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);

        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                requestedContentType,
                memoryStream.ToArray()),
            cancellationToken);

        if (storeResult.IsFailure)
        {
            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    messageId,
                    userId,
                    IsAdmin: true,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: storeResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(failedStatusResult.Value);
        }

        var completeStatusResult = await service.UpdateAttachmentMessageAsync(
            new UpdateSupportAttachmentMessageCommand(
                conversationId,
                messageId,
                userId,
                IsAdmin: true,
                AttachmentUploadStatus: SupportAttachmentUploadStatus.Uploaded,
                AttachmentUrl: storeResult.Value.Url,
                AttachmentStorageKey: storeResult.Value.StorageKey,
                AttachmentFileName: storeResult.Value.FileName,
                AttachmentContentType: storeResult.Value.ContentType,
                AttachmentFileSizeBytes: storeResult.Value.FileSizeBytes),
            cancellationToken);

        if (completeStatusResult.IsFailure)
        {
            await attachmentStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
            return ToProblem(completeStatusResult.Error);
        }

        return TypedResults.Ok(completeStatusResult.Value);
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

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> ResolveUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<ResolveSupportConversationCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new ResolveSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ResolveConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> CloseUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<CloseSupportConversationCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new CloseSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.CloseConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> ReopenUserConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<ReopenSupportConversationCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new ReopenSupportConversationCommand(conversationId, userId, IsAdmin: false);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.ReopenConversationAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> SubmitUserConversationFeedbackAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] SubmitSupportConversationFeedbackRequest request,
        [FromServices] IValidator<SubmitSupportConversationFeedbackCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var command = new SubmitSupportConversationFeedbackCommand(conversationId, userId, request.Rating, request.Comment);
        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.SubmitConversationFeedbackAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RegisterPushTokenAsync(
        HttpContext httpContext,
        [FromBody] RegisterPushTokenRequest request,
        [FromServices] ISupportPushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await pushTokenService.RegisterAsync(
            new RegisterSupportPushTokenCommand(
                userId,
                request.Token,
                request.Platform,
                request.DeviceId,
                request.AppVersion,
                request.Locale),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> UnregisterPushTokenAsync(
        HttpContext httpContext,
        [FromBody] UnregisterPushTokenRequest request,
        [FromServices] ISupportPushTokenService pushTokenService,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        var result = await pushTokenService.UnregisterAsync(
            new UnregisterSupportPushTokenCommand(userId, request.Token),
            cancellationToken);

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
        [FromQuery] Guid? assignedTo,
        [FromQuery] string? source,
        [FromQuery] string? priority,
        [FromQuery] string? search,
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] string? sort,
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

        var requestedPage = page is null or <= 0 ? 1 : page.Value;
        var requestedPageSize = pageSize is null or <= 0 ? 50 : pageSize.Value;
        var query = normalizedAssignment switch
        {
            "mine" => new ListAdminSupportInboxQuery(status, AssignedAdminId: userId, Source: source, Priority: priority, Search: search, Page: requestedPage, PageSize: requestedPageSize, Sort: sort),
            "unassigned" => new ListAdminSupportInboxQuery(status, UnassignedOnly: true, Source: source, Priority: priority, Search: search, Page: requestedPage, PageSize: requestedPageSize, Sort: sort),
            _ => new ListAdminSupportInboxQuery(status, AssignedAdminId: assignedTo, Source: source, Priority: priority, Search: search, Page: requestedPage, PageSize: requestedPageSize, Sort: sort)
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
        [FromQuery] int? take,
        [FromQuery] DateTime? beforeMessageCreatedAtUtc,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminConversationAsync(
            conversationId,
            new SupportConversationMessagesQuery(
                Take: take ?? 60,
                BeforeMessageCreatedAtUtc: beforeMessageCreatedAtUtc),
            cancellationToken);
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

        var command = new SendSupportMessageCommand(
            conversationId,
            userId,
            request.Body,
            IsAdmin: true,
            ReplyToMessageId: request.ReplyToMessageId);
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

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ValidationProblem, ProblemHttpResult>> UpdateConversationMetadataAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromBody] UpdateSupportConversationMetadataRequest request,
        [FromServices] IValidator<UpdateSupportConversationMetadataCommand> validator,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        if (!TryGetUserId(httpContext, out var userId, out var unauthorized))
        {
            return unauthorized!;
        }

        if (!Enum.TryParse<SupportConversationPriority>(request.Priority, true, out var priority))
        {
            return TypedResults.Problem(
                title: "support.priority_invalid",
                detail: "Support conversation priority is not supported.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var command = new UpdateSupportConversationMetadataCommand(
            conversationId,
            userId,
            priority,
            request.Tags ?? []);

        var validation = await validator.ValidateAsync(command, cancellationToken);
        if (!validation.IsValid)
        {
            return TypedResults.ValidationProblem(validation.ToDictionary());
        }

        var result = await service.UpdateConversationMetadataAsync(command, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportTicketContextResponse>, ProblemHttpResult>> GetAdminTicketContextAsync(
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetAdminTicketContextAsync(conversationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> AssignConversationToMeAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
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

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> UnassignConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
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

        return TypedResults.Ok(result.Value);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> MarkConversationWaitingForUserAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.WaitingForUser,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> MarkConversationInProgressAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.InProgress,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> CloseAdminConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.Closed,
            service,
            cancellationToken);
    }

    private static Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> ReopenAdminConversationAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return UpdateAdminConversationStatusAsync(
            httpContext,
            conversationId,
            SupportConversationStatus.InProgress,
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<SupportConversationDetailResponse>, ProblemHttpResult>> UpdateAdminConversationStatusAsync(
        HttpContext httpContext,
        Guid conversationId,
        SupportConversationStatus status,
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

    private static ProblemHttpResult ToProblem(PetMagic.BuildingBlocks.Results.Error error)
    {
        var statusCode = error.Code switch
        {
            "support.conversation_not_found" => StatusCodes.Status404NotFound,
            "support.message_not_found" => StatusCodes.Status404NotFound,
            "support.template_not_found" => StatusCodes.Status404NotFound,
            "support.forbidden" => StatusCodes.Status403Forbidden,
            "support.status_transition_invalid" => StatusCodes.Status400BadRequest,
            "support.priority_invalid" => StatusCodes.Status400BadRequest,
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
