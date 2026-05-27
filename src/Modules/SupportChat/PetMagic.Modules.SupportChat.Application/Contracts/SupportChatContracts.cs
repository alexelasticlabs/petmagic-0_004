using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Application.Contracts;

public sealed record OpenSupportConversationCommand(
    Guid UserId,
    string? InitialMessage,
    SupportConversationPriority Priority,
    SupportConversationSource Source = SupportConversationSource.MobileChat,
    string? AssistantScenario = null,
    Guid? RelatedGenerationId = null,
    Guid? RelatedPaymentId = null,
    Guid? RelatedSubscriptionId = null);

public sealed record ListAdminSupportInboxQuery(
    string? Status,
    Guid? AssignedAdminId = null,
    bool UnassignedOnly = false);

public sealed record SendSupportMessageCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    string? AttachmentUrl = null,
    string? AttachmentFileName = null,
    string? AttachmentContentType = null,
    long? AttachmentFileSizeBytes = null,
    string? Locale = null);

public sealed record CreateSupportAttachmentMessageCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    string AttachmentFileName,
    string AttachmentContentType,
    string? Locale = null);

public sealed record UpdateSupportAttachmentMessageCommand(
    Guid ConversationId,
    Guid MessageId,
    Guid SenderUserId,
    bool IsAdmin,
    SupportAttachmentUploadStatus AttachmentUploadStatus,
    string? AttachmentUrl = null,
    string? AttachmentFileName = null,
    string? AttachmentContentType = null,
    long? AttachmentFileSizeBytes = null,
    string? AttachmentUploadErrorCode = null);

public sealed record MarkSupportConversationReadCommand(
    Guid ConversationId,
    Guid UserId,
    bool IsAdmin);

public sealed record ResolveSupportConversationCommand(
    Guid ConversationId,
    Guid UserId,
    bool IsAdmin);

public sealed record CloseSupportConversationCommand(
    Guid ConversationId,
    Guid UserId,
    bool IsAdmin);

public sealed record ReopenSupportConversationCommand(
    Guid ConversationId,
    Guid UserId,
    bool IsAdmin);

public sealed record SubmitSupportConversationFeedbackCommand(
    Guid ConversationId,
    Guid UserId,
    int Rating,
    string? Comment);

public sealed record RegisterSupportPushTokenCommand(
    Guid UserId,
    string Token,
    string? Platform,
    string? DeviceId,
    string? AppVersion,
    string? Locale);

public sealed record UnregisterSupportPushTokenCommand(
    Guid UserId,
    string Token);

public sealed record UpdateSupportConversationStatusCommand(
    Guid ConversationId,
    Guid AdminUserId,
    SupportConversationStatus Status);

public sealed record AssignSupportConversationCommand(
    Guid ConversationId,
    Guid AdminUserId,
    Guid? AssignedAdminId);

public sealed record UpsertSupportReplyTemplateCommand(
    Guid? TemplateId,
    Guid AdminUserId,
    string Title,
    string Body,
    bool IsEnabled,
    int SortOrder);

public sealed record DeleteSupportReplyTemplateCommand(
    Guid TemplateId,
    Guid AdminUserId);

public sealed record SupportConversationSummaryResponse(
    Guid ConversationId,
    Guid InitiatorUserId,
    string UserEmail,
    string? UserDisplayName,
    Guid? AssignedAdminId,
    string? AssignedAdminDisplayName,
    string Status,
    string Priority,
    string Source,
    string? AssistantScenario,
    string? LastMessagePreview,
    DateTime? LastMessageAtUtc,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? ResolvedAtUtc,
    DateTime? ReopenUntilUtc,
    DateTime? ClosedAtUtc,
    int? FeedbackRating,
    bool IsReadOnly,
    bool CanReopen);

public sealed record SupportMessageResponse(
    Guid MessageId,
    Guid ConversationId,
    Guid SenderUserId,
    string SenderDisplayName,
    bool IsFromAdmin,
    string SenderType,
    string Body,
    string? AttachmentUrl,
    string? AttachmentFileName,
    string? AttachmentContentType,
    long? AttachmentFileSizeBytes,
    string? AttachmentUploadStatus,
    string? AttachmentUploadErrorCode,
    bool IsRead,
    DateTime? ReadAtUtc,
    DateTime CreatedAtUtc);

public sealed record SupportConversationDetailResponse(
    Guid ConversationId,
    Guid InitiatorUserId,
    string UserEmail,
    string? UserDisplayName,
    Guid? AssignedAdminId,
    string? AssignedAdminDisplayName,
    string Status,
    string Priority,
    string Source,
    string? AssistantScenario,
    Guid? RelatedGenerationId,
    Guid? RelatedPaymentId,
    Guid? RelatedSubscriptionId,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? LastMessageAtUtc,
    DateTime? ResolvedAtUtc,
    DateTime? ReopenUntilUtc,
    DateTime? ClosedAtUtc,
    int? FeedbackRating,
    string? FeedbackComment,
    DateTime? FeedbackSubmittedAtUtc,
    bool IsReadOnly,
    bool CanReopen,
    IReadOnlyList<SupportMessageResponse> Messages);

public sealed record SupportReplyTemplateResponse(
    Guid TemplateId,
    string Title,
    string Body,
    bool IsEnabled,
    int SortOrder,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc);
