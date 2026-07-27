using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class AccountLifecycleCleanupWorker(
    IServiceScopeFactory scopeFactory,
    ILogger<AccountLifecycleCleanupWorker> logger) : BackgroundService
{
    private static readonly TimeSpan LoopInterval = TimeSpan.FromMinutes(30);
    private static readonly TimeSpan PendingToExpiredAfter = TimeSpan.FromDays(7);
    private static readonly TimeSpan ExpiredToDeleteAfter = TimeSpan.FromDays(30);
    private const int BatchSize = 200;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunCycleAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                logger.LogError(
                    "Account lifecycle cleanup cycle failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
            }

            await Task.Delay(LoopInterval, stoppingToken);
        }
    }

    private async Task RunCycleAsync(CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<Guid>>>();

        var now = DateTime.UtcNow;
        var pendingThreshold = now - PendingToExpiredAfter;
        var expiredThreshold = now - ExpiredToDeleteAfter;

        var pendingUsers = await dbContext.Users
            .Where(x => x.AccountStatus == AccountStatus.PendingEmailVerification
                && !x.EmailConfirmed
                && (x.AccountStatusUpdatedAtUtc ?? x.CreatedAtUtc) <= pendingThreshold)
            .Take(BatchSize)
            .ToListAsync(cancellationToken);

        if (pendingUsers.Count > 0)
        {
            foreach (var user in pendingUsers)
            {
                user.AccountStatus = AccountStatus.Expired;
                user.AccountStatusUpdatedAtUtc = now;
            }

            dbContext.AuditEvents.AddRange(pendingUsers.Select(user => new AuditEvent
            {
                Id = Guid.NewGuid(),
                SubjectUserId = user.Id,
                Action = "account.expired",
                Details = "Pending email verification window elapsed.",
                OccurredAtUtc = now
            }));

            await dbContext.SaveChangesAsync(cancellationToken);
        }

        var expiredUserIds = await dbContext.Users
            .Where(x => x.AccountStatus == AccountStatus.Expired
                && !x.EmailConfirmed
                && (x.AccountStatusUpdatedAtUtc ?? x.CreatedAtUtc) <= expiredThreshold)
            .OrderBy(x => x.AccountStatusUpdatedAtUtc ?? x.CreatedAtUtc)
            .Select(x => x.Id)
            .Take(BatchSize)
            .ToListAsync(cancellationToken);

        if (expiredUserIds.Count == 0)
        {
            return;
        }

        foreach (var userId in expiredUserIds)
        {
            await DeleteExpiredUserAsync(
                dbContext,
                userManager,
                roleManager,
                userId,
                expiredThreshold,
                now,
                cancellationToken);
        }
    }

    private async Task DeleteExpiredUserAsync(
        IdentityDbContext dbContext,
        UserManager<AppUser> userManager,
        RoleManager<IdentityRole<Guid>> roleManager,
        Guid userId,
        DateTime expiredThreshold,
        DateTime now,
        CancellationToken cancellationToken)
    {
        await AdminRoleInvariantExecutor.ExecuteAsync(
            dbContext,
            lockAdminInvariant: true,
            async mutationCancellationToken =>
            {
                // The candidate list is intentionally only a hint. Reload under the
                // shared invariant lock so a recovered or newly privileged account
                // is never deleted from stale lifecycle state.
                dbContext.ChangeTracker.Clear();
                var user = await userManager.FindByIdAsync(userId.ToString());
                if (user is null
                    || user.AccountStatus != AccountStatus.Expired
                    || user.EmailConfirmed
                    || (user.AccountStatusUpdatedAtUtc ?? user.CreatedAtUtc) > expiredThreshold)
                {
                    return false;
                }

                var roles = await userManager.GetRolesAsync(user);
                if (roles.Contains(SystemRoles.Admin, StringComparer.Ordinal)
                    && await IsLastActiveAdminAsync(
                        dbContext,
                        roleManager,
                        user.Id,
                        mutationCancellationToken))
                {
                    return false;
                }

                var sessions = await dbContext.RefreshTokenSessions
                    .Where(x => x.UserId == user.Id)
                    .ToListAsync(mutationCancellationToken);
                var codes = await dbContext.UserEmailCodes
                    .Where(x => x.UserId == user.Id)
                    .ToListAsync(mutationCancellationToken);
                var jobs = await dbContext.EmailDispatchJobs
                    .Where(x => x.UserId == user.Id)
                    .ToListAsync(mutationCancellationToken);

                dbContext.RefreshTokenSessions.RemoveRange(sessions);
                dbContext.UserEmailCodes.RemoveRange(codes);
                dbContext.EmailDispatchJobs.RemoveRange(jobs);
                dbContext.AuditEvents.Add(new AuditEvent
                {
                    Id = Guid.NewGuid(),
                    SubjectUserId = user.Id,
                    Action = "account.deleted_expired",
                    Details = "Expired account retention window elapsed.",
                    OccurredAtUtc = now
                });

                var deleteResult = await userManager.DeleteAsync(user);
                if (deleteResult.Succeeded)
                {
                    return true;
                }

                logger.LogWarning(
                    "Failed to delete expired user. UserIdHash={UserIdHash} ErrorCodes={ErrorCodes}",
                    SafeLogValues.StableHash(user.Id.ToString("D")),
                    string.Join("; ", deleteResult.Errors.Select(x => x.Code)));
                return false;
            },
            static deleted => deleted,
            cancellationToken);
    }

    private static async Task<bool> IsLastActiveAdminAsync(
        IdentityDbContext dbContext,
        RoleManager<IdentityRole<Guid>> roleManager,
        Guid userId,
        CancellationToken cancellationToken)
    {
        var adminRole = await roleManager.FindByNameAsync(SystemRoles.Admin);
        if (adminRole is null)
        {
            return true;
        }

        return !await dbContext.UserRoles
            .AsNoTracking()
            .Where(x => x.RoleId == adminRole.Id && x.UserId != userId)
            .Join(
                dbContext.Users.AsNoTracking().Where(user => user.IsActive),
                userRole => userRole.UserId,
                user => user.Id,
                (_, _) => true)
            .AnyAsync(cancellationToken);
    }
}
