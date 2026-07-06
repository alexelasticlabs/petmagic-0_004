using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private const int AttachmentBatchMaxCount = 5;
    private const int AttachmentFileNameMaxLength = 256;
    private const int AttachmentContentTypeMaxLength = 128;
    private const string AttachmentStorageFailedCode = "support.attachment_storage_failed";

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
                ["files"] = ["support.attachment_file_required"]
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
            validationErrors["body"] = ["support.message_body_too_long"];
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
                validationErrors["replyToMessageId"] = ["support.reply_target_invalid"];
            }
        }

        if (validationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(validationErrors);
        }

        var metadataValidationErrors = ValidateAttachmentFiles(files, attachmentStorage);
        if (metadataValidationErrors.Count > 0)
        {
            return TypedResults.ValidationProblem(metadataValidationErrors);
        }

        var storedAttachments = new List<StoredSupportAttachmentResponse>(files.Count);
        foreach (var file in files)
        {
            var fileName = NormalizeAttachmentFileName(file);
            var requestedContentType = NormalizeAttachmentContentType(file);

            await using var stream = file.OpenReadStream();
            var storeResult = await attachmentStorage.StoreAsync(
                new SupportAttachmentUploadCommand(
                    fileName,
                    requestedContentType,
                    stream,
                    file.Length),
                cancellationToken);

            if (storeResult.IsFailure)
            {
                await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
                return ToProblem(SafeAttachmentUploadError(storeResult.Error));
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
            return TypedResults.ValidationProblem(validation.ToValidationCodeDictionary());
        }

        var sendResult = await service.SendMessageWithAttachmentsAsync(command, cancellationToken);
        if (sendResult.IsFailure)
        {
            await CleanupStoredAttachmentsAsync(storedAttachments, attachmentStorage);
            return ToProblem(sendResult.Error);
        }

        return TypedResults.Ok(SignAttachmentUrls(sendResult.Value, attachmentReadUrlSigner));
    }

    private static Dictionary<string, string[]> ValidateAttachmentFiles(
        IReadOnlyList<IFormFile> files,
        ISupportAttachmentStorage attachmentStorage)
    {
        var validationErrors = new Dictionary<string, string[]>();
        for (var index = 0; index < files.Count; index++)
        {
            AddAttachmentMetadataValidationErrors(files[index], $"files[{index}]", attachmentStorage, validationErrors);
        }

        return validationErrors;
    }

    private static Dictionary<string, string[]> ValidateSingleAttachmentMetadata(
        IFormFile file,
        ISupportAttachmentStorage attachmentStorage)
    {
        var validationErrors = new Dictionary<string, string[]>();
        AddAttachmentMetadataValidationErrors(file, nameof(file), attachmentStorage, validationErrors);
        return validationErrors;
    }

    private static void AddAttachmentMetadataValidationErrors(
        IFormFile file,
        string fieldPrefix,
        ISupportAttachmentStorage attachmentStorage,
        IDictionary<string, string[]> validationErrors)
    {
        var fileName = NormalizeAttachmentFileName(file);
        if (string.IsNullOrWhiteSpace(fileName))
        {
            validationErrors[$"{fieldPrefix}.fileName"] = ["support.attachment_file_name_required"];
        }
        else if (fileName.Length > AttachmentFileNameMaxLength)
        {
            validationErrors[$"{fieldPrefix}.fileName"] = ["support.attachment_file_name_too_long"];
        }

        var contentType = NormalizeAttachmentContentType(file);
        if (contentType.Length > AttachmentContentTypeMaxLength)
        {
            validationErrors[$"{fieldPrefix}.contentType"] = ["support.attachment_content_type_too_long"];
        }

        var maxFileSizeBytes = attachmentStorage.ResolveMaxFileSizeBytes(contentType);
        if (maxFileSizeBytes is not null && file.Length > maxFileSizeBytes.Value)
        {
            validationErrors[$"{fieldPrefix}.file"] = ["support.attachment_file_too_large"];
        }
    }

    private static string NormalizeAttachmentFileName(IFormFile file)
    {
        return RemoveAttachmentMetadataControlCharacters(Path.GetFileName(file.FileName)).Trim();
    }

    private static string NormalizeAttachmentContentType(IFormFile file)
    {
        var contentType = string.IsNullOrWhiteSpace(file.ContentType)
            ? "application/octet-stream"
            : RemoveAttachmentMetadataControlCharacters(file.ContentType).Trim();

        return string.IsNullOrWhiteSpace(contentType)
            ? "application/octet-stream"
            : contentType;
    }

    private static string RemoveAttachmentMetadataControlCharacters(string value)
    {
        if (string.IsNullOrEmpty(value) || !value.Any(char.IsControl))
        {
            return value;
        }

        var builder = new StringBuilder(value.Length);
        foreach (var character in value)
        {
            if (!char.IsControl(character))
            {
                builder.Append(character);
            }
        }

        return builder.ToString();
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
            validationErrors["body"] = ["support.message_body_too_long"];
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
            validationErrors["replyToMessageId"] = ["support.reply_target_invalid"];
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

    private static Error SafeAttachmentUploadError(Error error)
    {
        return new Error(
            SafeAttachmentUploadErrorCode(error.Code),
            "Support attachment could not be stored.");
    }

    private static string SafeAttachmentUploadErrorCode(string? code)
    {
        var trimmed = code?.Trim();
        if (string.IsNullOrWhiteSpace(trimmed))
        {
            return AttachmentStorageFailedCode;
        }

        var sanitized = SafeLogValues.SanitizeText(trimmed, 128);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized
            : AttachmentStorageFailedCode;
    }
}
