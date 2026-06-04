using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    public async Task<Result<UserListPageResponse>> ListUsersAsync(int skip, int take, CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 100, 200);
        var users = await userManager.Users
            .AsNoTracking()
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        if (users.Count == 0)
        {
            return Result.Success(new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false));
        }

        var hasMore = users.Count > normalizedTake;
        if (hasMore)
        {
            users.RemoveAt(users.Count - 1);
        }

        var userIds = users.Select(x => x.Id).ToArray();
        var roleRows = await dbContext.UserRoles
            .AsNoTracking()
            .Where(x => userIds.Contains(x.UserId))
            .Join(
                dbContext.Roles.AsNoTracking(),
                userRole => userRole.RoleId,
                role => role.Id,
                (userRole, role) => new
                {
                    userRole.UserId,
                    RoleName = role.Name ?? string.Empty
                })
            .ToListAsync(cancellationToken);

        var rolesByUserId = roleRows
            .GroupBy(x => x.UserId)
            .ToDictionary(
                group => group.Key,
                group => (IReadOnlyList<string>)[.. group
                    .Select(x => x.RoleName)
                    .OrderBy(x => x, StringComparer.OrdinalIgnoreCase)]);

        var output = users
            .Select(user => new UserListItemResponse(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                user.IsPremium,
                user.IsActive,
                user.EmailConfirmed,
                user.AccountStatus.ToString(),
                user.TermsOfUseAccepted,
                user.PrivacyPolicyAccepted,
                user.MarketingEmailsEnabled,
                ToLegalAcceptanceResponse(user),
                rolesByUserId.GetValueOrDefault(user.Id) ?? [],
                user.CreatedAtUtc,
                ToAvatarResponse(user)))
            .ToArray();

        return Result.Success(new UserListPageResponse(output, normalizedSkip, normalizedTake, hasMore));
    }

    public async Task<Result<AdminUserDetailResponse>> GetAdminUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<AdminUserDetailResponse>(IdentityErrors.UserNotFound);
        }

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToAdminUserDetailResponse(user, roles));
    }

    public async Task<Result<AdminUserAnalyticsResponse>> GetAdminUserAnalyticsAsync(Guid userId, CancellationToken cancellationToken)
    {
        var economyAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserEconomyAnalyticsReader>();
        var templateAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserTemplateAnalyticsReader>();
        var analyticsService = new IdentityAdminUserAnalyticsService(
            userManager,
            dbContext,
            economyAnalyticsReader,
            templateAnalyticsReader);

        return await analyticsService.GetAdminUserAnalyticsAsync(userId, cancellationToken);
    }

    public async Task<Result<AdminUserWalletOperationResponse>> AdjustAdminUserWalletAsync(AdminAdjustUserWalletCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<AdminUserWalletOperationResponse>(IdentityErrors.UserNotFound);
        }

        var economyService = serviceProvider.GetRequiredService<IEconomyService>();
        var normalizedOperation = command.Operation.Trim().ToLowerInvariant();
        var reason = command.Reason.Trim();
        var operationResult = normalizedOperation switch
        {
            "credit" => await economyService.CreditAsync(
                new CreditBalanceCommand(command.UserId, command.Amount, WalletLedgerSource.AdminGrant, reason),
                cancellationToken),
            "debit" => await economyService.SpendAsync(
                new SpendBalanceCommand(command.UserId, command.Amount, reason, WalletLedgerSource.AdminDebit),
                cancellationToken),
            _ => Result.Failure<WalletOperationResponse>(IdentityErrors.OperationFailed)
        };

        if (operationResult.IsFailure)
        {
            return Result.Failure<AdminUserWalletOperationResponse>(operationResult.Error);
        }

        var source = normalizedOperation == "credit" ? WalletLedgerSource.AdminGrant : WalletLedgerSource.AdminDebit;

        await WriteAuditAsync(
            command.UserId,
            normalizedOperation == "credit" ? "admin.user.wallet.credited" : "admin.user.wallet.debited",
            $"{command.Amount} tokens. Reason: {reason}",
            cancellationToken);

        return Result.Success(new AdminUserWalletOperationResponse(
            command.UserId,
            normalizedOperation,
            normalizedOperation == "credit" ? command.Amount : -command.Amount,
            operationResult.Value.NewBalance,
            source,
            reason,
            operationResult.Value.OccurredAtUtc));
    }

    public async Task<Result> DeleteAdminUserAsync(DeleteAdminUserCommand command, CancellationToken cancellationToken)
    {
        return await DeleteUserInternalAsync(
            command.UserId,
            "admin.user.deleted",
            "User account deleted by admin.",
            cancellationToken);
    }

    public async Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken)
    {
        var query = userManager.Users
            .Where(x => x.IsActive && x.EmailConfirmed && !string.IsNullOrWhiteSpace(x.Email));

        if (string.Equals(command.Audience, EmailAudiences.Premium, StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(x => x.IsPremium);
        }
        else if (string.Equals(command.Audience, EmailAudiences.Selected, StringComparison.OrdinalIgnoreCase))
        {
            var selectedIds = command.UserIds?
                .Where(id => id != Guid.Empty)
                .Distinct()
                .ToArray() ?? [];

            query = query.Where(x => selectedIds.Contains(x.Id));
        }

        var recipients = await query
            .Select(x => new { x.Id, x.Email })
            .ToListAsync(cancellationToken);

        if (recipients.Count == 0)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        foreach (var recipient in recipients)
        {
            dbContext.EmailDispatchJobs.Add(CreateBroadcastEmailJob(recipient.Id, recipient.Email!, command.Subject, command.Body, now));
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(null, "admin.bulk_email.queued", $"Bulk email queued for {recipients.Count} recipients.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        if (!await roleManager.RoleExistsAsync(command.Role))
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        var addResult = await userManager.AddToRoleAsync(user, command.Role);
        if (!addResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.assigned", $"Assigned role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        if (string.Equals(command.Role, SystemRoles.User, StringComparison.Ordinal))
        {
            return Result.Failure(IdentityErrors.CannotRevokeBaseRole);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (!currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        var removeResult = await userManager.RemoveFromRoleAsync(user, command.Role);
        if (!removeResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.revoked", $"Revoked role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsPremium = command.IsPremium;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.premium.updated", $"Premium status changed to '{command.IsPremium}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsActive = command.IsActive;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.active.updated", $"Active status changed to '{command.IsActive}'.", cancellationToken);
        return Result.Success();
    }

    private async Task<Result> DeleteUserInternalAsync(
        Guid userId,
        string auditAction,
        string auditDetails,
        CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var avatarUrl = user.AvatarUrl;
        var deleteUserResult = await userManager.DeleteAsync(user);
        if (!deleteUserResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        var refreshSessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);

        var emailCodes = await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);

        var emailJobs = await dbContext.EmailDispatchJobs
            .Where(x => x.UserId == userId)
            .ToListAsync(cancellationToken);

        if (refreshSessions.Count > 0)
        {
            dbContext.RefreshTokenSessions.RemoveRange(refreshSessions);
        }

        if (emailCodes.Count > 0)
        {
            dbContext.UserEmailCodes.RemoveRange(emailCodes);
        }

        if (emailJobs.Count > 0)
        {
            dbContext.EmailDispatchJobs.RemoveRange(emailJobs);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await avatarStorage.DeleteAsync(avatarUrl, CancellationToken.None);
        await WriteAuditAsync(userId, auditAction, auditDetails, cancellationToken);

        return Result.Success();
    }

    private static int NormalizeTake(int take, int fallback, int max)
    {
        if (take <= 0)
        {
            return fallback;
        }

        return Math.Min(take, max);
    }
}
