using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> SubmitConversationFeedbackAsync(
        SubmitSupportConversationFeedbackCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        if (conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(Forbidden);
        }

        if (ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) != SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.FeedbackNotAllowed);
        }

        if (command.Rating is < 1 or > 5)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.InvalidFeedbackRating);
        }

        var now = DateTime.UtcNow;
        conversation.FeedbackRating = command.Rating;
        conversation.FeedbackComment = string.IsNullOrWhiteSpace(command.Comment)
            ? null
            : command.Comment.Trim();
        conversation.FeedbackSubmittedAtUtc = now;
        conversation.UpdatedAtUtc = now;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    public async Task<Result<SupportConversationDetailResponse>> UpdateConversationMetadataAsync(
        UpdateSupportConversationMetadataCommand command,
        CancellationToken cancellationToken)
    {
        await using var transaction = await BeginSupportAdminActionTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await LockConversationRowForAdminActionAsync(command.ConversationId, cancellationToken);
        }

        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }
        var ownershipError = ValidateAdminOwnership(conversation, command.AdminUserId);
        if (ownershipError is not null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ownershipError);
        }

        var normalizedTags = NormalizeTags(command.Tags);
        if (normalizedTags is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidTags);
        }

        conversation.Priority = command.Priority;
        conversation.TagsJson = SerializeTags(normalizedTags);
        conversation.UpdatedAtUtc = DateTime.UtcNow;

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }
}
