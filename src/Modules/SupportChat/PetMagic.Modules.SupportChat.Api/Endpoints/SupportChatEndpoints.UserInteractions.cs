using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
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
        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                file.ContentType ?? "application/octet-stream",
                stream,
                file.Length),
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
        var storeResult = await attachmentStorage.StoreAsync(
            new SupportAttachmentUploadCommand(
                Path.GetFileName(file.FileName),
                requestedContentType,
                stream,
                file.Length),
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
}
