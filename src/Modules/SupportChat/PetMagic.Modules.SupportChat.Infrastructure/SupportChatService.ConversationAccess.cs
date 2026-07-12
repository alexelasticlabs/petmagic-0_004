using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> OpenConversationAsync(OpenSupportConversationCommand command, CancellationToken cancellationToken)
    {
        if (command.Priority != SupportConversationPriority.Normal)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidPriority);
        }

        if (command.Source is not (SupportConversationSource.MobileChat or SupportConversationSource.MobileAssistant))
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidSource);
        }

        var relatedResourceError = await ValidateRelatedResourcesAsync(
            command.UserId,
            command.RelatedGenerationId,
            command.RelatedPaymentId,
            command.RelatedSubscriptionId,
            cancellationToken);
        if (relatedResourceError is not null)
        {
            return Result.Failure<SupportConversationDetailResponse>(relatedResourceError);
        }

        var createdConversation = false;
        var appendedInitialMessage = false;
        var conversation = await supportChatDbContext.SupportConversations
            .Include(x => x.Messages)
            .FirstOrDefaultAsync(x => x.InitiatorUserId == command.UserId, cancellationToken);

        if (conversation is null)
        {
            var now = DateTime.UtcNow;
            conversation = new SupportConversation
            {
                Id = Guid.NewGuid(),
                InitiatorUserId = command.UserId,
                Priority = command.Priority,
                Status = SupportConversationStatus.New,
                Source = command.Source,
                AssistantScenario = command.AssistantScenario?.Trim(),
                RelatedGenerationId = command.RelatedGenerationId,
                RelatedPaymentId = command.RelatedPaymentId,
                RelatedSubscriptionId = command.RelatedSubscriptionId,
                CreatedAtUtc = now,
                UpdatedAtUtc = now
            };

            supportChatDbContext.SupportConversations.Add(conversation);
            createdConversation = true;

            if (command.Source == SupportConversationSource.MobileChat)
            {
                await AppendSystemEventAsync(
                    conversation,
                    "Ticket created from Mobile Chat");
            }

            if (command.Source == SupportConversationSource.MobileAssistant
                && !string.IsNullOrWhiteSpace(command.AssistantScenario))
            {
                var scenarioLabel = ResolveScenarioLabel(command.AssistantScenario);
                await AppendSystemEventAsync(
                    conversation,
                    $"User completed the \"{scenarioLabel}\" assistant flow and created a support ticket.");
            }
        }

        if (!string.IsNullOrWhiteSpace(command.InitialMessage))
        {
            var now = DateTime.UtcNow;
            if (ShouldReactivateConversationForUserMessage(conversation, now))
            {
                MarkActive(conversation, SupportConversationStatus.New, now);
            }

            var canAppendError = ValidateConversationCanAcceptMessage(conversation, isAdmin: false, now);
            if (canAppendError is not null)
            {
                return Result.Failure<SupportConversationDetailResponse>(canAppendError);
            }

            await AppendMessageAsync(
                conversation,
                command.UserId,
                command.InitialMessage,
                isAdmin: false,
                replyToMessageId: null,
                replyToPreview: null,
                senderType: SupportMessageSenderType.User,
                attachmentUrl: null,
                attachmentFileName: null,
                attachmentContentType: null,
                attachmentFileSizeBytes: null,
                attachmentUploadStatus: null,
                attachmentUploadErrorCode: null,
                attachments: [],
                markAsReadAtUtc: null,
                updateAssignmentAndStatus: true);
            appendedInitialMessage = true;

            if (createdConversation)
            {
                await AppendSystemEventAsync(
                    conversation,
                    "User sent first message");
            }
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        if (createdConversation || appendedInitialMessage)
        {
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private async Task<Error?> ValidateRelatedResourcesAsync(
        Guid userId,
        Guid? relatedGenerationId,
        Guid? relatedPaymentId,
        Guid? relatedSubscriptionId,
        CancellationToken cancellationToken)
    {
        if (relatedGenerationId.HasValue)
        {
            if (templateGenerationService is null)
            {
                return SupportChatErrors.RelatedResourceNotFound;
            }

            var generation = await templateGenerationService.GetAsync(
                userId,
                relatedGenerationId.Value,
                cancellationToken);
            if (generation.IsFailure)
            {
                return SupportChatErrors.RelatedResourceNotFound;
            }
        }

        if (relatedPaymentId.HasValue
            && (economyResourceOwnershipReader is null
                || !await economyResourceOwnershipReader.OwnsPurchaseOrderAsync(
                    userId,
                    relatedPaymentId.Value,
                    cancellationToken)))
        {
            return SupportChatErrors.RelatedResourceNotFound;
        }

        if (relatedSubscriptionId.HasValue
            && (economyResourceOwnershipReader is null
                || !await economyResourceOwnershipReader.OwnsSubscriptionAsync(
                    userId,
                    relatedSubscriptionId.Value,
                    cancellationToken)))
        {
            return SupportChatErrors.RelatedResourceNotFound;
        }

        return null;
    }

    public async Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(
        Guid userId,
        SupportConversationMessagesQuery query,
        CancellationToken cancellationToken)
    {
        var conversationId = await supportChatDbContext.SupportConversations
            .Where(x => x.InitiatorUserId == userId)
            .Select(x => (Guid?)x.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (conversationId is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId.Value, query, cancellationToken));
    }

    public Task<Result<SupportConversationDetailResponse>> GetUserConversationAsync(
        Guid userId,
        CancellationToken cancellationToken)
        => GetUserConversationAsync(userId, new SupportConversationMessagesQuery(), cancellationToken);
}
