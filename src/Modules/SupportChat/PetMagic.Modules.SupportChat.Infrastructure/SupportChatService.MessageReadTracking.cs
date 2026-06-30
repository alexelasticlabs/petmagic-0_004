using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result> MarkConversationReadAsync(
        MarkSupportConversationReadCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure(ConversationNotFound);
        }

        if (!command.IsAdmin && conversation.InitiatorUserId != command.UserId)
        {
            return Result.Failure(Forbidden);
        }

        var markAdminMessages = !command.IsAdmin;
        var now = DateTime.UtcNow;
        var changed = false;

        var unreadMessages = await supportChatDbContext.ConversationMessages
            .Where(message => message.ConversationId == conversation.Id
                && message.IsFromAdmin == markAdminMessages
                && message.ReadAtUtc == null)
            .ToListAsync(cancellationToken);

        foreach (var message in unreadMessages)
        {
            message.ReadAtUtc = now;
            changed = true;
        }

        if (changed)
        {
            conversation.UpdatedAtUtc = now;
            await supportChatDbContext.SaveChangesAsync(cancellationToken);
            await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        }

        return Result.Success();
    }
}
