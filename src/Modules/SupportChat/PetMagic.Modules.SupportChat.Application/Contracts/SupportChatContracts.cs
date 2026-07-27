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
    bool UnassignedOnly = false,
    string? Source = null,
    string? Priority = null,
    string? Search = null,
    int Page = 1,
    int PageSize = 50,
    string? Sort = null,
    IReadOnlyList<string>? Statuses = null,
    string? Queue = null,
    Guid? InitiatorUserId = null);

public sealed record SupportConversationInboxPageResponse(
    IReadOnlyList<SupportConversationSummaryResponse> Items,
    int Page,
    int PageSize,
    int TotalCount,
    bool HasMore);

public sealed record AdminSupportInboxMetricsResponse(
    int TotalConversations,
    int OpenConversations,
    int ClosedConversations,
    int UnassignedConversations,
    int UnreadForAdminConversations,
    IReadOnlyList<AdminSupportOperatorWorkloadResponse>? OperatorWorkloads = null);

public sealed record AdminSupportOperatorWorkloadResponse(
    Guid OperatorUserId,
    string DisplayName,
    int OpenConversations,
    int HighPriorityConversations,
    int UrgentConversations,
    int WaitingForUserConversations);

public sealed record SupportConversationMessagesQuery(
    int Take = 60,
    DateTime? BeforeMessageCreatedAtUtc = null,
    Guid? BeforeMessageId = null);

public sealed record SendSupportMessageCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    Guid? ReplyToMessageId = null,
    string? Locale = null,
    string? IdempotencyKey = null);

public sealed record SupportMessageAttachmentInput(
    string FileUrl,
    string MimeType,
    string FileName,
    long SizeBytes,
    double? DurationSeconds = null,
    int? Width = null,
    int? Height = null,
    string? StorageKey = null,
    DateTime? ExpiresAtUtc = null,
    DateTime? DeletedAtUtc = null,
    bool IsDeleted = false);

public sealed record SendSupportAttachmentsCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    IReadOnlyList<SupportMessageAttachmentInput> Attachments,
    Guid? ReplyToMessageId = null,
    string? Locale = null,
    string? IdempotencyKey = null);

public sealed record CreateSupportAttachmentMessageCommand(
    Guid ConversationId,
    Guid SenderUserId,
    string Body,
    bool IsAdmin,
    string AttachmentFileName,
    string AttachmentContentType,
    Guid? ReplyToMessageId = null,
    string? Locale = null,
    string? IdempotencyKey = null);

public static class SupportMessageIdempotency
{
    public const string HeaderName = "Idempotency-Key";

    public const int MaxKeyLength = 128;

    public static bool TryNormalize(string? value, out string? normalizedValue)
    {
        normalizedValue = value?.Trim();
        if (string.IsNullOrEmpty(normalizedValue))
        {
            normalizedValue = null;
            return value is null;
        }

        return normalizedValue.Length <= MaxKeyLength;
    }
}

public sealed record UpdateSupportAttachmentMessageCommand(
    Guid ConversationId,
    Guid MessageId,
    Guid SenderUserId,
    bool IsAdmin,
    SupportAttachmentUploadStatus AttachmentUploadStatus,
    string? AttachmentUrl = null,
    string? AttachmentStorageKey = null,
    string? AttachmentFileName = null,
    string? AttachmentContentType = null,
    long? AttachmentFileSizeBytes = null,
    DateTime? AttachmentExpiresAtUtc = null,
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
    Guid? AssignedAdminId,
    string? Reason = null,
    long? ExpectedVersion = null,
    bool CanAssignOthers = false);

public static class SupportConversationMetadataLimits
{
    public const int MaxTagCount = 12;

    public const int MaxTagLength = 40;
}

public sealed record UpdateSupportConversationMetadataCommand(
    Guid ConversationId,
    Guid AdminUserId,
    SupportConversationPriority Priority,
    IReadOnlyList<string> Tags);

public sealed record UpsertSupportReplyTemplateCommand(
    Guid? TemplateId,
    Guid AdminUserId,
    string Title,
    string Body,
    bool IsEnabled,
    int SortOrder,
    int? ExpectedVersion = null,
    string? Reason = null);

public sealed record DeleteSupportReplyTemplateCommand(
    Guid TemplateId,
    Guid AdminUserId,
    int? ExpectedVersion = null,
    string? Reason = null);

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
    IReadOnlyList<string> Tags,
    string? AssistantScenario,
    string? LastMessagePreview,
    DateTime? LastMessageAtUtc,
    string? LastMessageSenderType,
    DateTime? WaitingSinceUtc,
    int WaitingMinutes,
    bool UnreadForAdmin,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? ResolvedAtUtc,
    DateTime? ReopenUntilUtc,
    DateTime? ClosedAtUtc,
    Guid? ClosedByUserId,
    DateTime? ReopenedAtUtc,
    Guid? ReopenedByUserId,
    int? FeedbackRating,
    bool IsReadOnly,
    bool CanReopen,
    long Version = 1,
    SupportConversationSlaResponse? Sla = null);

public sealed record SupportMessageAttachmentResponse(
    string FileUrl,
    string Type,
    string MimeType,
    string FileName,
    long SizeBytes,
    double? DurationSeconds,
    int? Width,
    int? Height,
    bool IsDeleted = false,
    DateTime? ExpiresAtUtc = null,
    DateTime? DeletedAtUtc = null);

public sealed record SupportMessagePendingAttachmentResponse(
    string FileName,
    string MimeType,
    long? SizeBytes);

public sealed record SupportMessageResponse(
    Guid MessageId,
    Guid ConversationId,
    Guid SenderUserId,
    string SenderDisplayName,
    bool IsFromAdmin,
    string SenderType,
    string Body,
    Guid? ReplyToMessageId,
    string? ReplyToPreview,
    string? AttachmentUploadStatus,
    string? AttachmentUploadErrorCode,
    SupportMessagePendingAttachmentResponse? PendingAttachment,
    IReadOnlyList<SupportMessageAttachmentResponse> Attachments,
    bool IsRead,
    DateTime? ReadAtUtc,
    DateTime? DeliveredAtUtc,
    bool IsInternalNote,
    DateTime CreatedAtUtc,
    bool IsIdempotencyReplay = false);

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
    IReadOnlyList<string> Tags,
    string? AssistantScenario,
    Guid? RelatedGenerationId,
    Guid? RelatedPaymentId,
    Guid? RelatedSubscriptionId,
    int UserUnreadCount,
    int AdminUnreadCount,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    DateTime? LastMessageAtUtc,
    string? LastMessagePreview,
    string? LastMessageSenderType,
    DateTime? WaitingSinceUtc,
    int WaitingMinutes,
    DateTime? ResolvedAtUtc,
    DateTime? ReopenUntilUtc,
    DateTime? ClosedAtUtc,
    Guid? ClosedByUserId,
    DateTime? ReopenedAtUtc,
    Guid? ReopenedByUserId,
    int? FeedbackRating,
    string? FeedbackComment,
    DateTime? FeedbackSubmittedAtUtc,
    bool IsReadOnly,
    bool CanReopen,
    IReadOnlyList<string> AvailableActions,
    bool HasOlderMessages,
    DateTime? OldestLoadedMessageCreatedAtUtc,
    IReadOnlyList<SupportMessageResponse> Messages,
    long Version = 1,
    SupportConversationSlaResponse? Sla = null);

public sealed record SupportConversationSlaResponse(
    DateTime FirstResponseDueAtUtc,
    DateTime ResolutionDueAtUtc,
    DateTime? FirstResponseAtUtc,
    string FirstResponseStatus,
    string ResolutionStatus,
    bool IsResolutionPaused,
    int FirstResponseRemainingMinutes,
    int ResolutionRemainingMinutes);

public sealed record SupportTicketContextResponse(
    int TokenBalance,
    string Plan,
    string PremiumStatus,
    object? LastPayment,
    Guid? LinkedGeneration,
    object? LastGeneration,
    string? LastGenerationError,
    int GenerationErrorsCount,
    Guid? RelatedPaymentId,
    Guid? RelatedSubscriptionId);

public sealed record SupportReplyTemplateResponse(
    Guid TemplateId,
    string Title,
    string Body,
    bool IsEnabled,
    int SortOrder,
    DateTime CreatedAtUtc,
    DateTime UpdatedAtUtc,
    int Version = 1,
    DateTime? DisabledAtUtc = null);

public sealed record SupportReplyTemplateVersionResponse(
    Guid TemplateId,
    int Version,
    string Title,
    string Body,
    bool IsEnabled,
    int SortOrder,
    Guid ActorUserId,
    string? Reason,
    DateTime CapturedAtUtc,
    bool IsCurrent);
