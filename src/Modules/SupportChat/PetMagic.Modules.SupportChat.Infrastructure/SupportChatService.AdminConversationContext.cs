using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        SupportConversationMessagesQuery query,
        CancellationToken cancellationToken)
    {
        var exists = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .AnyAsync(x => x.Id == conversationId, cancellationToken);
        if (!exists)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        return Result.Success(await BuildConversationDetailAsync(conversationId, query, cancellationToken));
    }

    public Task<Result<SupportConversationDetailResponse>> GetAdminConversationAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
        => GetAdminConversationAsync(conversationId, new SupportConversationMessagesQuery(), cancellationToken);

    public async Task<Result<SupportTicketContextResponse>> GetAdminTicketContextAsync(
        Guid conversationId,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .AsNoTracking()
            .Where(x => x.Id == conversationId)
            .Select(x => new
            {
                x.RelatedGenerationId,
                x.RelatedPaymentId,
                x.RelatedSubscriptionId
            })
            .FirstOrDefaultAsync(cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportTicketContextResponse>(ConversationNotFound);
        }

        return Result.Success(new SupportTicketContextResponse(
            TokenBalance: 0,
            Plan: "Free",
            PremiumStatus: "Inactive",
            LastPayment: null,
            LinkedGeneration: conversation.RelatedGenerationId,
            LastGeneration: null,
            LastGenerationError: null,
            GenerationErrorsCount: 0,
            RelatedPaymentId: conversation.RelatedPaymentId,
            RelatedSubscriptionId: conversation.RelatedSubscriptionId));
    }
}
