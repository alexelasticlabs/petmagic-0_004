using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.SupportChat.Infrastructure;

internal static class SupportChatErrors
{
    public static readonly Error InvalidAttachmentUpload = new("support.attachment_invalid_upload", "Support attachment upload is invalid.");
    public static readonly Error AttachmentContentTypeNotAllowed = new("support.attachment_content_type_not_allowed", "Support attachment content type is not allowed.");
    public static readonly Error AttachmentMimeMismatch = new("support.attachment_mime_mismatch", "Support attachment MIME type does not match file content.");
    public static readonly Error AttachmentFileTooLarge = new("support.attachment_file_too_large", "Support attachment exceeds the maximum allowed size.");
    public static readonly Error AttachmentBatchLimitExceeded = new("support.attachment_batch_limit_exceeded", "Support message allows up to 5 attachments.");
    public static readonly Error AttachmentStorageFailed = new("support.attachment_storage_failed", "Support attachment could not be stored.");
    public static readonly Error AttachmentRetryNotAllowed = new("support.attachment_retry_not_allowed", "Support attachment retry is not allowed for this message state.");
    public static readonly Error ConversationReadOnly = new("support.conversation_read_only", "Support conversation is read-only.");
    public static readonly Error ReopenWindowExpired = new("support.reopen_window_expired", "Support conversation can no longer be reopened.");
    public static readonly Error FeedbackNotAllowed = new("support.feedback_not_allowed", "Support feedback is only allowed after the conversation is resolved or closed.");
    public static readonly Error InvalidFeedbackRating = new("support.feedback_rating_invalid", "Support feedback rating must be between 1 and 5.");
    public static readonly Error InvalidPushToken = new("support.push_token_invalid", "Support push token is invalid.");
    public static readonly Error InvalidAssignedAdmin = new("support.assigned_admin_invalid", "Assigned support operator is invalid.");
    public static readonly Error ConversationAlreadyAssigned = new("support.conversation_already_assigned", "Support conversation is already assigned to another operator.");
    public static readonly Error ConversationNotOwned = new("support.conversation_not_owned", "Support conversation must be assigned to the current operator.");
}
