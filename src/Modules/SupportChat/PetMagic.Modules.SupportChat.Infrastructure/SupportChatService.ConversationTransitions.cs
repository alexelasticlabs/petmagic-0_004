using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> ResolveConversationAsync(
        ResolveSupportConversationCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.ConversationReadOnly);
        }

        var now = DateTime.UtcNow;
        MarkClosed(conversation, now, command.UserId);
        await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket closed by operator" : "Ticket closed by user");

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> CloseConversationAsync(
        CloseSupportConversationCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        var now = DateTime.UtcNow;
        MarkClosed(conversation, now, command.UserId);
        await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket closed by operator" : "Ticket closed by user");

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> ReopenConversationAsync(
        ReopenSupportConversationCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        var now = DateTime.UtcNow;
        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed)
        {
            var reopenedStatus = command.IsAdmin ? SupportConversationStatus.InProgress : SupportConversationStatus.New;
            MarkActive(conversation, reopenedStatus, now, command.UserId);
            await AppendSystemEventAsync(conversation, command.IsAdmin ? "Ticket reopened by operator" : "Ticket reopened by user message");
            await AppendStatusChangedEventAsync(conversation, SupportConversationStatus.Closed, reopenedStatus);
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }
}
