using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

using PetMagic.BuildingBlocks.Observability;
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

        var ownershipError = ValidateAdminOwnership(conversation, command.AdminUserId);
        if (ownershipError is not null)
        {
            return Result.Failure<SupportConversationDetailResponse>(ownershipError);
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

        if (command.AssignedAdminId.HasValue && command.AssignedAdminId.Value != command.AdminUserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.InvalidAssignedAdmin);
        }

        if (command.AssignedAdminId.HasValue
            && conversation.AssignedAdminId.HasValue
            && conversation.AssignedAdminId.Value != command.AdminUserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.ConversationAlreadyAssigned);
        }

        if (!command.AssignedAdminId.HasValue
            && conversation.AssignedAdminId.HasValue
            && conversation.AssignedAdminId.Value != command.AdminUserId)
        {
            return Result.Failure<SupportConversationDetailResponse>(SupportChatErrors.ConversationNotOwned);
        }

        var isIdempotent = conversation.AssignedAdminId == command.AssignedAdminId;
        if (isIdempotent)
        {
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }

            return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
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
        if (transaction is not null)
        {
            await transaction.CommitAsync(cancellationToken);
        }

        if (adminAuditLog is not null)
        {
            await adminAuditLog.WriteAsync(
                new AdminAuditEntry(
                    command.AssignedAdminId.HasValue ? "admin.support.ticket.assigned" : "admin.support.ticket.unassigned",
                    "SupportConversation",
                    conversation.Id.ToString("D"),
                    OldValue: null,
                    NewValue: command.AssignedAdminId?.ToString("D"),
                    SubjectUserId: conversation.InitiatorUserId),
                cancellationToken);
        }

        await NotifyConversationUpdatedAsync(conversation, cancellationToken);
        return Result.Success(await BuildConversationDetailAsync(conversation.Id, cancellationToken));
    }

    private async Task<IDbContextTransaction?> BeginSupportAdminActionTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(supportChatDbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? await supportChatDbContext.Database.BeginTransactionAsync(cancellationToken)
            : null;
    }

    private async Task LockConversationRowForAdminActionAsync(Guid conversationId, CancellationToken cancellationToken)
    {
        await supportChatDbContext.Database.SqlQueryRaw<Guid>(
            """
            SELECT "Id" AS "Value"
            FROM support_conversations
            WHERE "Id" = {0}
            FOR UPDATE
            """,
            conversationId)
            .ToListAsync(cancellationToken);
    }
}
