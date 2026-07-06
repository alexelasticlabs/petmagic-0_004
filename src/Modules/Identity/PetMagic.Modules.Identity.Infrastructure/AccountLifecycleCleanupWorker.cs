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

        var now = DateTime.UtcNow;
        var pendingThreshold = now - PendingToExpiredAfter;
        var expiredThreshold = now - ExpiredToDeleteAfter;

        var pendingUsers = await dbContext.Users
            .Where(x => x.AccountStatus == AccountStatus.PendingEmailVerification
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
                && (x.AccountStatusUpdatedAtUtc ?? x.CreatedAtUtc) <= expiredThreshold)
            .OrderBy(x => x.AccountStatusUpdatedAtUtc ?? x.CreatedAtUtc)
            .Select(x => x.Id)
            .Take(BatchSize)
            .ToListAsync(cancellationToken);

        if (expiredUserIds.Count == 0)
        {
            return;
        }

        var usersToDelete = await dbContext.Users
            .Where(x => expiredUserIds.Contains(x.Id))
            .ToListAsync(cancellationToken);

        var userIdHashSet = new HashSet<Guid>(expiredUserIds);
        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => userIdHashSet.Contains(x.UserId))
            .ToListAsync(cancellationToken);
        var codes = await dbContext.UserEmailCodes
            .Where(x => userIdHashSet.Contains(x.UserId))
            .ToListAsync(cancellationToken);
        var jobs = await dbContext.EmailDispatchJobs
            .Where(x => x.UserId.HasValue && userIdHashSet.Contains(x.UserId.Value))
            .ToListAsync(cancellationToken);

        dbContext.RefreshTokenSessions.RemoveRange(sessions);
        dbContext.UserEmailCodes.RemoveRange(codes);
        dbContext.EmailDispatchJobs.RemoveRange(jobs);

        dbContext.AuditEvents.AddRange(expiredUserIds.Select(userId => new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = userId,
            Action = "account.deleted_expired",
            Details = "Expired account retention window elapsed.",
            OccurredAtUtc = now
        }));

        await dbContext.SaveChangesAsync(cancellationToken);

        foreach (var user in usersToDelete)
        {
            var deleteResult = await userManager.DeleteAsync(user);
            if (!deleteResult.Succeeded)
            {
                logger.LogWarning(
                    "Failed to delete expired user. UserIdHash={UserIdHash} ErrorCodes={ErrorCodes}",
                    SafeLogValues.StableHash(user.Id.ToString("D")),
                    string.Join("; ", deleteResult.Errors.Select(x => x.Code)));
            }
        }
    }
}
