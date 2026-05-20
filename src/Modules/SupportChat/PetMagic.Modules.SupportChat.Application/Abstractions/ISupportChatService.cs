using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Application.Abstractions;

public sealed record SupportConversationRealtimeEvent(
    Guid ConversationId,
    Guid InitiatorUserId,
    DateTime UpdatedAtUtc);

public interface ISupportChatRealtimeNotifier
{
    Task NotifyConversationUpdatedAsync(SupportConversationRealtimeEvent notification, CancellationToken cancellationToken);
}

public interface ISupportChatService
{
    Task<Result<SupportConversationDetailResponse>> OpenConversationAsync(OpenSupportConversationCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(Guid userId, CancellationToken cancellationToken);

    Task<Result<IReadOnlyList<SupportConversationSummaryResponse>>> ListAdminInboxAsync(ListAdminSupportInboxQuery query, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(Guid conversationId, CancellationToken cancellationToken);

    Task<Result<SupportMessageResponse>> SendMessageAsync(SendSupportMessageCommand command, CancellationToken cancellationToken);

    Task<Result> MarkConversationReadAsync(MarkSupportConversationReadCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> UpdateConversationStatusAsync(UpdateSupportConversationStatusCommand command, CancellationToken cancellationToken);

    Task<Result<SupportConversationDetailResponse>> AssignConversationAsync(AssignSupportConversationCommand command, CancellationToken cancellationToken);
}