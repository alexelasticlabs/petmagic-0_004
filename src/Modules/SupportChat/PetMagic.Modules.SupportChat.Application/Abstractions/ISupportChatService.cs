using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Application.Abstractions;

public sealed record SupportConversationRealtimeEvent(
    Guid ConversationId,
    Guid InitiatorUserId,
    DateTime UpdatedAtUtc);

public sealed record SupportAttachmentUploadCommand(
    string FileName,
    string ContentType,
    byte[] Content);

public sealed record SupportChatPushNotification(
    Guid ConversationId,
    Guid UserId,
    Guid MessageId,
    string SenderDisplayName,
    string Body,
    bool HasAttachment);

public sealed record StoredSupportAttachmentResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    string? LocalPath);

public interface ISupportChatRealtimeNotifier
{
    Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken);
}

public interface ISupportAttachmentStorage
{
    Task<Result<StoredSupportAttachmentResponse>> StoreAsync(SupportAttachmentUploadCommand attachment, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken);
}

public interface ISupportChatPushNotificationSender
{
    Task NotifyUserAsync(SupportChatPushNotification notification, CancellationToken cancellationToken);
}

public interface ISupportPushTokenService
{
    Task<Result> RegisterAsync(RegisterSupportPushTokenCommand command, CancellationToken cancellationToken);

    Task<Result> UnregisterAsync(UnregisterSupportPushTokenCommand command, CancellationToken cancellationToken);
}

public interface ISupportChatService
{
    Task<Result<SupportConversationDetailResponse>> OpenConversationAsync(OpenSupportConversationCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<SupportConversationSummaryResponse>>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(Guid conversationId, CancellationToken cancellationToken);

    Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken);

    Task<Result<SupportMessageResponse>> CreateAttachmentMessageAsync(CreateSupportAttachmentMessageCommand command, CancellationToken cancellationToken);

    Task<Result<SupportMessageResponse>> UpdateAttachmentMessageAsync(UpdateSupportAttachmentMessageCommand command, CancellationToken cancellationToken);

    Task<Result> MarkConversationReadAsync(MarkSupportConversationReadCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> ResolveConversationAsync(ResolveSupportConversationCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> CloseConversationAsync(CloseSupportConversationCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> ReopenConversationAsync(ReopenSupportConversationCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> SubmitConversationFeedbackAsync(SubmitSupportConversationFeedbackCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> UpdateConversationStatusAsync(UpdateSupportConversationStatusCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> AssignConversationAsync(AssignSupportConversationCommand command, CancellationToken cancellationToken);
}
