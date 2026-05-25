using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatErrors
{
    public static readonly Error InvalidAttachmentUpload = new("support.attachment_invalid_upload", "Support attachment upload is invalid.");
    public static readonly Error AttachmentContentTypeNotAllowed = new("support.attachment_content_type_not_allowed", "Support attachment content type is not allowed.");
    public static readonly Error AttachmentMimeMismatch = new("support.attachment_mime_mismatch", "Support attachment MIME type does not match file content.");
    public static readonly Error AttachmentFileTooLarge = new("support.attachment_file_too_large", "Support attachment exceeds the maximum allowed size.");
    public static readonly Error AttachmentStorageFailed = new("support.attachment_storage_failed", "Support attachment could not be stored.");
    public static readonly Error AttachmentRetryNotAllowed = new("support.attachment_retry_not_allowed", "Support attachment retry is not allowed for this message state.");
}