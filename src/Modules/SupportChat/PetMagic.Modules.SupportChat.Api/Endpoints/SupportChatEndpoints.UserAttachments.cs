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
    private static Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendUserAttachmentsAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromServices] IValidator<SendSupportAttachmentsCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
        [FromServices] ISupportChatService service,
        CancellationToken cancellationToken)
    {
        return SendAttachmentsCoreAsync(
            httpContext,
            conversationId,
            isAdmin: false,
            validator,
            attachmentStorage,
            attachmentReadUrlSigner,
            service,
            cancellationToken);
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendUserAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromForm] IFormFile? file,
        [FromForm] string? body,
        [FromForm] string? locale,
        [FromForm] string? replyToMessageId,
        [FromServices] IValidator<SendSupportMessageCommand> validator,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
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

        var formValidationErrors = ValidateSingleAttachmentFormFields(body, replyToMessageId, out var parsedReplyToMessageId);
        if (formValidationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(formValidationErrors);
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
                ReplyToMessageId: parsedReplyToMessageId,
                Locale: ResolvePreferredLocale(locale, httpContext)),
            cancellationToken);

        if (createMessageResult.IsFailure)
        {
            return ToUserProblem(createMessageResult.Error);
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
            return ToUserProblem(uploadingStatusResult.Error);
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
                return ToUserProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
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
                return ToUserProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
        }

        return TypedResults.Ok(SignAttachmentUrls(completeStatusResult.Value, attachmentReadUrlSigner));
    }

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> RetryUserAttachmentAsync(
        HttpContext httpContext,
        [FromRoute] Guid conversationId,
        [FromRoute] Guid messageId,
        [FromForm] IFormFile? file,
        [FromServices] ISupportAttachmentStorage attachmentStorage,
        [FromServices] ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
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
            return ToUserProblem(retryStatusResult.Error);
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
            return ToUserProblem(uploadingStatusResult.Error);
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
                return ToUserProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
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

            var failedStatusResult = await service.UpdateAttachmentMessageAsync(
                new UpdateSupportAttachmentMessageCommand(
                    conversationId,
                    messageId,
                    userId,
                    IsAdmin: false,
                    AttachmentUploadStatus: SupportAttachmentUploadStatus.Failed,
                    AttachmentUploadErrorCode: completeStatusResult.Error.Code),
                cancellationToken);

            if (failedStatusResult.IsFailure)
            {
                return ToUserProblem(failedStatusResult.Error);
            }

            return TypedResults.Ok(SignAttachmentUrls(failedStatusResult.Value, attachmentReadUrlSigner));
        }

        return TypedResults.Ok(SignAttachmentUrls(completeStatusResult.Value, attachmentReadUrlSigner));
    }
}
