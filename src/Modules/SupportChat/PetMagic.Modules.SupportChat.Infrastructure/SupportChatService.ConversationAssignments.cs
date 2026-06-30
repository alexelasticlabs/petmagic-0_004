using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    public async Task<Result<SupportConversationDetailResponse>> UpdateConversationStatusAsync(
        UpdateSupportConversationStatusCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        var now = DateTime.UtcNow;
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        var nextStatus = ToCanonicalStatus(command.Status);

        if (currentStatus == SupportConversationStatus.New && nextStatus == SupportConversationStatus.InProgress)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        if (currentStatus != nextStatus && !IsAllowedStatusTransition(currentStatus, nextStatus))
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        conversation.AssignedAdminId ??= command.AdminUserId;
        if (nextStatus == SupportConversationStatus.Closed)
        {
            MarkClosed(conversation, now, command.AdminUserId);
            await AppendSystemEventAsync(conversation, "Ticket closed by operator");
        }
        else
        {
            if (currentStatus == SupportConversationStatus.Closed && nextStatus == SupportConversationStatus.InProgress)
            {
                MarkActive(conversation, nextStatus, now, command.AdminUserId);
                await AppendSystemEventAsync(conversation, "Ticket reopened by operator");
            }
            else
            {
                MarkActive(conversation, nextStatus, now);
            }

            if (currentStatus == SupportConversationStatus.New && nextStatus == SupportConversationStatus.InProgress)
            {
                await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
            }
        }

        if (currentStatus != nextStatus)
        {
            await AppendStatusChangedEventAsync(conversation, currentStatus, nextStatus);
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private static bool IsAllowedStatusTransition(
        SupportConversationStatus currentStatus,
        SupportConversationStatus nextStatus)
    {
        return currentStatus switch
        {
            SupportConversationStatus.New => nextStatus is SupportConversationStatus.Closed,
            SupportConversationStatus.InProgress => nextStatus is SupportConversationStatus.Closed,
            SupportConversationStatus.WaitingForUser => nextStatus is SupportConversationStatus.Closed,
            SupportConversationStatus.Closed => nextStatus is SupportConversationStatus.InProgress,
            _ => false
        };
    }

    public async Task<Result<SupportConversationDetailResponse>> AssignConversationAsync(
        AssignSupportConversationCommand command,
        CancellationToken cancellationToken)
    {
        var conversation = await supportChatDbContext.SupportConversations
            .FirstOrDefaultAsync(x => x.Id == command.ConversationId, cancellationToken);
        if (conversation is null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ConversationNotFound);
        }

        var now = DateTime.UtcNow;
        var currentStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (currentStatus == SupportConversationStatus.Closed)
        {
            return Result.Failure<SupportConversationDetailResponse>(InvalidStatusTransition);
        }

        if (command.AssignedAdminId.HasValue)
        {
            var assignedAdmin = await identityUserLookupService.GetUserByIdAsync(
                command.AssignedAdminId.Value,
                cancellationToken);
            var hasSupportRole = assignedAdmin?.Roles.Contains(SystemRoles.Admin, StringComparer.Ordinal) == true
                || assignedAdmin?.Roles.Contains(SystemRoles.Moderator, StringComparer.Ordinal) == true;
            if (!hasSupportRole)
            {
                return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.InvalidAssignedAdmin);
            }
        }

        conversation.AssignedAdminId = command.AssignedAdminId;
        conversation.UpdatedAtUtc = now;
        if (command.AssignedAdminId.HasValue && currentStatus == SupportConversationStatus.New)
        {
            MarkActive(conversation, SupportConversationStatus.InProgress, now);
            await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
            await AppendStatusChangedEventAsync(conversation, currentStatus, SupportConversationStatus.InProgress);
        }
        else if (command.AssignedAdminId.HasValue)
        {
            await AppendSystemEventAsync(conversation, "Ticket assigned to operator");
        }
        else
        {
            await AppendSystemEventAsync(conversation, "Ticket unassigned");
        }

        await supportChatDbContext.SaveChangesAsync(cancellationToken);
        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }
}
