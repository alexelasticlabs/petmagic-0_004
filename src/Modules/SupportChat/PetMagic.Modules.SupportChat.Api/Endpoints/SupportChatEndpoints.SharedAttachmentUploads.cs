using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private const int AttachmentBatchMaxCount = 5;

    private static async Task<Results<Ok<SupportMessageResponse>, ValidationProblem, ProblemHttpResult>> SendAttachmentsCoreAsync(
        HttpContext httpContext,
        Guid conversationId,
        bool isAdmin,
        IValidator<SendSupportAttachmentsCommand> validator,
        ISupportAttachmentStorage attachmentStorage,
        ISupportAttachmentReadUrlSigner attachmentReadUrlSigner,
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

        var rawBody = form.TryGetValue("body", out var bodyValue)
            ? bodyValue.ToString()
            : string.Empty;
        var locale = form.TryGetValue("locale", out var localeValue)
            ? localeValue.ToString()
            : null;
        var validationErrors = new Dictionary<string, string[]>();
        if (rawBody.Length > 4000)
        {
            validationErrors["body"] = ["Support message body must be at most 4000 characters."];
        }

        Guid? replyToMessageId = null;
        if (form.TryGetValue("replyToMessageId", out var replyToMessageValue)
            && !string.IsNullOrWhiteSpace(replyToMessageValue.ToString()))
        {
            if (Guid.TryParse(replyToMessageValue.ToString(), out var parsedReplyToMessageId))
            {
                replyToMessageId = parsedReplyToMessageId;
            }
            else
            {
                validationErrors["replyToMessageId"] = ["Reply target message id must be a valid GUID."];
            }
        }

        if (validationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(validationErrors);
        }

        var storedAttachments = new List<StoredSupportAttachmentResponse>(files.Count);
        foreach (var file in files)
        {
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
                await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
                return ToProblem(storeResult.Error);
            }

            storedAttachments.Add(storeResult.Value);
        }

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

        return TypedResults.Ok(SignAttachmentUrls(sendResult.Value, attachmentReadUrlSigner));
    }

    private static Dictionary<string, string[]> ValidateSingleAttachmentFormFields(
        string? body,
        string? rawReplyToMessageId,
        out Guid? replyToMessageId)
    {
        replyToMessageId = null;
        var validationErrors = new Dictionary<string, string[]>();

        if ((body ?? string.Empty).Length > 4000)
        {
            validationErrors["body"] = ["Support message body must be at most 4000 characters."];
        }

        if (string.IsNullOrWhiteSpace(rawReplyToMessageId))
        {
            return validationErrors;
        }

        if (Guid.TryParse(rawReplyToMessageId, out var parsedReplyToMessageId))
        {
            replyToMessageId = parsedReplyToMessageId;
        }
        else
        {
            validationErrors["replyToMessageId"] = ["Reply target message id must be a valid GUID."];
        }

        return validationErrors;
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
}
