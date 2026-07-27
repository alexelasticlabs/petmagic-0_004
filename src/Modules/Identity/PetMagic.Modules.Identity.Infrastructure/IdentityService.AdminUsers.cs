using System.Data;

using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private const string AdminWalletIdempotencyScope = "admin_user_wallet";
    private const string AdminBulkEmailIdempotencyScope = "admin_bulk_email";
    private const string AdminBulkEmailQueuedAction = "admin.bulk_email.queued";

    public async Task<Result<UserListPageResponse>> ListUsersAsync(
        int skip,
        int take,
        string? search,
        string? role,
        string? status,
        bool? isPremium,
        string? sort,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(0, skip);
        var normalizedTake = NormalizeTake(take, 100, 200);
        var normalizedSort = NormalizeAdminUsersSort(sort);
        if (normalizedSort is null)
        {
            return Result.Failure<UserListPageResponse>(IdentityErrors.InvalidUserSort);
        }

        var query = userManager.Users.AsNoTracking();
        var normalizedSearch = search?.Trim();
        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            var matchesUserId = Guid.TryParse(normalizedSearch, out var searchedUserId);
            var searchPattern = $"%{EscapePostgresLikePattern(normalizedSearch)}%";
            var normalizedSearchLower = normalizedSearch.ToLowerInvariant();
            var useCaseInsensitiveLike = dbContext.Database.ProviderName?.Contains("Npgsql", StringComparison.OrdinalIgnoreCase) == true;

            query = useCaseInsensitiveLike
                ? query.Where(user =>
                    (matchesUserId && user.Id == searchedUserId)
                    || (user.Email != null && EF.Functions.ILike(user.Email, searchPattern, "\\"))
                    || (user.DisplayName != null && EF.Functions.ILike(user.DisplayName, searchPattern, "\\")))
                : query.Where(user =>
                    (matchesUserId && user.Id == searchedUserId)
                    || ((user.Email ?? string.Empty).ToLower().Contains(normalizedSearchLower))
                    || ((user.DisplayName ?? string.Empty).ToLower().Contains(normalizedSearchLower)));
        }

        var normalizedRole = NormalizeSystemRole(role);
        if (!string.IsNullOrWhiteSpace(normalizedRole) && !string.Equals(normalizedRole, "all", StringComparison.OrdinalIgnoreCase))
        {
            if (!SystemRoles.All.Contains(normalizedRole))
            {
                return Result.Success(new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false, TotalCount: 0));
            }

            var roleEntity = await roleManager.FindByNameAsync(normalizedRole);
            if (roleEntity is null)
            {
                return Result.Success(new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false, TotalCount: 0));
            }

            var roleUserIds = dbContext.UserRoles
                .AsNoTracking()
                .Where(userRole => userRole.RoleId == roleEntity.Id)
                .Select(userRole => userRole.UserId);

            query = query.Where(user => roleUserIds.Contains(user.Id));
        }

        if (isPremium.HasValue)
        {
            query = query.Where(user => user.IsPremium == isPremium.Value);
        }

        var normalizedStatus = status?.Trim().ToLowerInvariant();
        if (!string.IsNullOrWhiteSpace(normalizedStatus) && normalizedStatus != "all")
        {
            query = normalizedStatus switch
            {
                "active" => query.Where(user => user.IsActive && user.EmailConfirmed),
                "blocked" => query.Where(user => !user.IsActive),
                "unconfirmed" => query.Where(user => user.IsActive && !user.EmailConfirmed),
                _ => query.Where(_ => false)
            };
        }

        var totalCount = await query.CountAsync(cancellationToken);
        if (IsAdminUsersLastActivitySort(normalizedSort))
        {
            return Result.Success(await ListUsersByLastActivityAsync(
                query,
                normalizedSkip,
                normalizedTake,
                totalCount,
                normalizedSort,
                cancellationToken));
        }

        var users = await ApplyAdminUsersSort(query, normalizedSort)
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToListAsync(cancellationToken);

        if (users.Count == 0)
        {
            return Result.Success(new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false, totalCount));
        }

        var hasMore = users.Count > normalizedTake;
        if (hasMore)
        {
            users.RemoveAt(users.Count - 1);
        }

        return Result.Success(await MapAdminUsersPageAsync(users, normalizedSkip, normalizedTake, hasMore, totalCount, cancellationToken));
    }

    private async Task<UserListPageResponse> ListUsersByLastActivityAsync(
        IQueryable<AppUser> query,
        int normalizedSkip,
        int normalizedTake,
        int totalCount,
        string normalizedSort,
        CancellationToken cancellationToken)
    {
        var candidates = await query.ToListAsync(cancellationToken);
        if (candidates.Count == 0)
        {
            return new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false, totalCount);
        }

        var candidateUserIds = candidates.Select(user => user.Id).ToArray();
        var lastActivityByUserId = await LoadAdminUserLastActivityAsync(candidateUserIds, cancellationToken);
        var orderedUsers = normalizedSort == "last_activity_asc"
            ? candidates
                .OrderBy(user => ResolveAdminUserLastActivity(lastActivityByUserId, user.Id) ?? DateTime.MinValue)
                .ThenBy(user => user.CreatedAtUtc)
                .ThenBy(user => user.Id)
            : candidates
                .OrderByDescending(user => ResolveAdminUserLastActivity(lastActivityByUserId, user.Id) ?? DateTime.MinValue)
                .ThenByDescending(user => user.CreatedAtUtc)
                .ThenByDescending(user => user.Id);

        var users = orderedUsers
            .Skip(normalizedSkip)
            .Take(normalizedTake + 1)
            .ToList();
        var hasMore = users.Count > normalizedTake;
        if (hasMore)
        {
            users.RemoveAt(users.Count - 1);
        }

        return await MapAdminUsersPageAsync(
            users,
            normalizedSkip,
            normalizedTake,
            hasMore,
            totalCount,
            cancellationToken,
            lastActivityByUserId);
    }

    private async Task<UserListPageResponse> MapAdminUsersPageAsync(
        IReadOnlyList<AppUser> users,
        int normalizedSkip,
        int normalizedTake,
        bool hasMore,
        int totalCount,
        CancellationToken cancellationToken,
        IReadOnlyDictionary<Guid, DateTime?>? preloadedLastActivityByUserId = null)
    {
        if (users.Count == 0)
        {
            return new UserListPageResponse([], normalizedSkip, normalizedTake, HasMore: false, totalCount);
        }

        var userIds = users.Select(x => x.Id).ToArray();
        var lastActivityByUserId = preloadedLastActivityByUserId
            ?? await LoadAdminUserLastActivityAsync(userIds, cancellationToken);
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
                ToAvatarResponse(user),
                ResolveAdminUserLastActivity(lastActivityByUserId, user.Id)))
            .ToArray();

        return new UserListPageResponse(output, normalizedSkip, normalizedTake, hasMore, totalCount);
    }

    public async Task<Result<AdminUserDashboardMetricsResponse>> GetAdminUserDashboardMetricsAsync(
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var currentWeekStart = StartOfUtcDay(now.AddDays(-6));
        var previousWeekStart = currentWeekStart.AddDays(-7);

        var users = userManager.Users.AsNoTracking();
        var userCounters = await users
            .GroupBy(_ => 1)
            .Select(group => new DashboardUserCounters(
                group.Count(),
                group.Count(user => user.IsPremium),
                group.Count(user => user.IsActive),
                group.Count(user => !user.IsActive),
                group.Count(user => user.CreatedAtUtc >= currentWeekStart),
                group.Count(user => user.CreatedAtUtc >= previousWeekStart && user.CreatedAtUtc < currentWeekStart),
                group.Count(user => user.CreatedAtUtc >= now.AddDays(-30)),
                group.Count(user => user.CreatedAtUtc >= now.AddDays(-90))))
            .SingleOrDefaultAsync(cancellationToken)
            ?? new DashboardUserCounters(0, 0, 0, 0, 0, 0, 0, 0);

        var roleCounts = await GetDashboardRoleCountsAsync(cancellationToken);
        return Result.Success(new AdminUserDashboardMetricsResponse(
            userCounters.TotalUsers,
            userCounters.PremiumUsers,
            userCounters.ActiveUsers,
            userCounters.BlockedUsers,
            roleCounts.AdminUsers,
            roleCounts.ModeratorUsers,
            roleCounts.RegularUsers,
            userCounters.UsersThisWeek,
            userCounters.UsersPreviousWeek,
            userCounters.UsersThisWeek,
            userCounters.NewUsersLast30Days,
            userCounters.NewUsersLast90Days));
    }

    private async Task<IReadOnlyDictionary<Guid, DateTime?>> LoadAdminUserLastActivityAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, DateTime?>();
        }

        var auditActivityTask = dbContext.AuditEvents
            .AsNoTracking()
            .Where(auditEvent => auditEvent.SubjectUserId.HasValue && userIds.Contains(auditEvent.SubjectUserId.Value))
            .GroupBy(auditEvent => auditEvent.SubjectUserId!.Value)
            .Select(group => new AdminUserLastActivityRow(
                group.Key,
                group.Max(auditEvent => auditEvent.OccurredAtUtc)))
            .ToListAsync(cancellationToken);

        var economyAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserEconomyAnalyticsReader>();
        var templateAnalyticsReader = serviceProvider.GetRequiredService<IAdminUserTemplateAnalyticsReader>();
        var economyActivityTask = economyAnalyticsReader.GetAdminUserLastActivityAsync(userIds, cancellationToken);
        var templateActivityTask = templateAnalyticsReader.GetAdminUserLastActivityAsync(userIds, cancellationToken);

        await Task.WhenAll(auditActivityTask, economyActivityTask, templateActivityTask);

        var lastActivityByUserId = new Dictionary<Guid, DateTime?>();
        foreach (var row in await auditActivityTask)
        {
            ApplyAdminUserLastActivity(lastActivityByUserId, row.UserId, row.LastActivityAtUtc);
        }

        foreach (var row in await economyActivityTask)
        {
            ApplyAdminUserLastActivity(lastActivityByUserId, row.Key, row.Value);
        }

        foreach (var row in await templateActivityTask)
        {
            ApplyAdminUserLastActivity(lastActivityByUserId, row.Key, row.Value);
        }

        return lastActivityByUserId;
    }

    private static void ApplyAdminUserLastActivity(
        IDictionary<Guid, DateTime?> lastActivityByUserId,
        Guid userId,
        DateTime lastActivityAtUtc)
    {
        if (!lastActivityByUserId.TryGetValue(userId, out var current)
            || !current.HasValue
            || lastActivityAtUtc > current.Value)
        {
            lastActivityByUserId[userId] = lastActivityAtUtc;
        }
    }

    private static DateTime? ResolveAdminUserLastActivity(
        IReadOnlyDictionary<Guid, DateTime?> lastActivityByUserId,
        Guid userId)
    {
        return lastActivityByUserId.TryGetValue(userId, out var lastActivityAtUtc)
            ? lastActivityAtUtc
            : null;
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

    private async Task<DashboardRoleCounts> GetDashboardRoleCountsAsync(CancellationToken cancellationToken)
    {
        var roleCounts = await dbContext.UserRoles
            .AsNoTracking()
            .Join(
                dbContext.Roles.AsNoTracking(),
                userRole => userRole.RoleId,
                role => role.Id,
                (userRole, role) => new
                {
                    userRole.UserId,
                    RoleName = role.Name ?? string.Empty
                })
            .Where(row =>
                row.RoleName == SystemRoles.Admin ||
                row.RoleName == SystemRoles.Moderator ||
                row.RoleName == SystemRoles.User)
            .GroupBy(row => row.RoleName)
            .Select(group => new
            {
                RoleName = group.Key,
                Count = group.Select(row => row.UserId).Distinct().Count()
            })
            .ToDictionaryAsync(row => row.RoleName, row => row.Count, StringComparer.Ordinal, cancellationToken);

        return new DashboardRoleCounts(
            roleCounts.GetValueOrDefault(SystemRoles.Admin),
            roleCounts.GetValueOrDefault(SystemRoles.Moderator),
            roleCounts.GetValueOrDefault(SystemRoles.User));
    }

    private static DateTime StartOfUtcDay(DateTime value)
    {
        return new DateTime(value.Year, value.Month, value.Day, 0, 0, 0, DateTimeKind.Utc);
    }

    private sealed record DashboardUserCounters(
        int TotalUsers,
        int PremiumUsers,
        int ActiveUsers,
        int BlockedUsers,
        int UsersThisWeek,
        int UsersPreviousWeek,
        int NewUsersLast30Days,
        int NewUsersLast90Days);

    private sealed record DashboardRoleCounts(
        int AdminUsers,
        int ModeratorUsers,
        int RegularUsers);

    private sealed record AdminUserLastActivityRow(
        Guid UserId,
        DateTime LastActivityAtUtc);

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
        var idempotencyKey = command.IdempotencyKey?.Trim();
        var operationResult = normalizedOperation switch
        {
            "credit" => await economyService.CreditAsync(
                new CreditBalanceCommand(
                    command.UserId,
                    command.Amount,
                    WalletLedgerSource.AdminGrant,
                    reason,
                    idempotencyKey,
                    LedgerReason: reason,
                    IdempotencyScope: AdminWalletIdempotencyScope),
                cancellationToken),
            "debit" => await economyService.SpendAsync(
                new SpendBalanceCommand(
                    command.UserId,
                    command.Amount,
                    reason,
                    WalletLedgerSource.AdminDebit,
                    idempotencyKey,
                    IdempotencyScope: AdminWalletIdempotencyScope),
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
            cancellationToken,
            targetType: "user",
            targetId: command.UserId.ToString("D"),
            newValue: $"{source}:{command.Amount}:{reason}",
            eventId: CreateAdminWalletAuditEventId(command.UserId, idempotencyKey));

        return Result.Success(new AdminUserWalletOperationResponse(
            command.UserId,
            normalizedOperation,
            operationResult.Value.Delta,
            operationResult.Value.NewBalance,
            source,
            reason,
            operationResult.Value.OccurredAtUtc));
    }

    private static Guid? CreateAdminWalletAuditEventId(Guid userId, string? idempotencyKey)
    {
        if (string.IsNullOrWhiteSpace(idempotencyKey))
        {
            return null;
        }

        var rawKey = $"{AdminWalletIdempotencyScope}:{userId:D}:{idempotencyKey.Trim()}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey)).AsSpan(0, 16));
    }

    public async Task<Result> DeleteAdminUserAsync(DeleteAdminUserCommand command, CancellationToken cancellationToken)
    {
        return await DeleteUserInternalAsync(
            command.UserId,
            "admin.user.deleted",
            "User account deleted by admin.",
            cancellationToken);
    }

    public async Task<Result<AdminEmailBroadcastQueueResponse>> SendBulkEmailAsync(
        SendBulkEmailCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedAudience = command.Audience.Trim().ToLowerInvariant();
        var normalizedSubject = command.Subject.Trim();
        var normalizedBody = command.Body.Trim();
        var selectedIds = string.Equals(normalizedAudience, EmailAudiences.Selected, StringComparison.Ordinal)
            ? command.UserIds?
                .Where(id => id != Guid.Empty)
                .Distinct()
                .OrderBy(id => id)
                .ToArray() ?? []
            : [];
        var idempotencyKey = command.IdempotencyKey?.Trim();
        var httpContext = httpContextAccessor.HttpContext;
        var actorUserId = ResolveActorUserId(httpContext);
        var requestHash = CreateAdminBulkEmailRequestHash(
            normalizedAudience,
            normalizedSubject,
            normalizedBody,
            selectedIds);
        var idempotencyEventId = string.IsNullOrWhiteSpace(idempotencyKey)
            ? (Guid?)null
            : CreateAdminBulkEmailAuditEventId(actorUserId, idempotencyKey);

        if (idempotencyEventId.HasValue)
        {
            var existingBroadcast = await dbContext.AdminEmailBroadcasts
                .AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == idempotencyEventId.Value, cancellationToken);
            if (existingBroadcast is not null)
            {
                return ResolveAdminBulkEmailReplay(existingBroadcast, requestHash);
            }
        }

        var query = userManager.Users
            .Where(x => x.IsActive && x.EmailConfirmed && !string.IsNullOrWhiteSpace(x.Email));

        if (string.Equals(normalizedAudience, EmailAudiences.Premium, StringComparison.Ordinal))
        {
            query = query.Where(x => x.IsPremium);
        }
        else if (string.Equals(normalizedAudience, EmailAudiences.Selected, StringComparison.Ordinal))
        {
            query = query.Where(x => selectedIds.Contains(x.Id));
        }

        var recipients = await query
            .OrderBy(x => x.Id)
            .Select(x => new { x.Id, x.Email })
            .ToListAsync(cancellationToken);

        var now = DateTime.UtcNow;
        var broadcastId = idempotencyEventId ?? Guid.NewGuid();
        var broadcastStatus = recipients.Count == 0
            ? AdminEmailBroadcastStatus.Completed
            : AdminEmailBroadcastStatus.Queued;
        dbContext.AdminEmailBroadcasts.Add(new AdminEmailBroadcast
        {
            Id = broadcastId,
            ActorUserId = actorUserId,
            Audience = normalizedAudience,
            Subject = normalizedSubject,
            RequestHash = requestHash,
            Status = broadcastStatus,
            RecipientCount = recipients.Count,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            CompletedAtUtc = recipients.Count == 0 ? now : null
        });

        foreach (var recipient in recipients)
        {
            dbContext.EmailDispatchJobs.Add(CreateBroadcastEmailJob(
                broadcastId,
                recipient.Id,
                recipient.Email!,
                normalizedSubject,
                normalizedBody,
                now));
        }

        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = broadcastId,
            ActorUserId = actorUserId,
            ActorRole = ResolveActorRole(httpContext),
            Action = AdminBulkEmailQueuedAction,
            TargetType = "email-broadcast",
            TargetId = broadcastId.ToString("D"),
            NewValue = requestHash,
            IpAddress = ResolveClientIpAddress(httpContext),
            UserAgent = httpContext?.Request.Headers.UserAgent.ToString(),
            CorrelationId = CorrelationContext.ResolveOrCreate(),
            Details = $"Bulk email queued for {recipients.Count} recipients. Audience: {normalizedAudience}.",
            CreatedAtUtc = now,
            OccurredAtUtc = now
        });

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException) when (idempotencyEventId.HasValue)
        {
            dbContext.ChangeTracker.Clear();
            var persistedBroadcast = await dbContext.AdminEmailBroadcasts
                .AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == idempotencyEventId.Value, cancellationToken);
            if (persistedBroadcast is not null)
            {
                return ResolveAdminBulkEmailReplay(persistedBroadcast, requestHash);
            }

            throw;
        }

        return Result.Success(ToAdminEmailBroadcastQueueResponse(
            broadcastId,
            recipients.Count,
            broadcastStatus,
            now));
    }

    private static Guid CreateAdminBulkEmailAuditEventId(Guid? actorUserId, string idempotencyKey)
    {
        var actorScope = actorUserId?.ToString("D") ?? "system";
        var rawKey = $"{AdminBulkEmailIdempotencyScope}:{actorScope}:{idempotencyKey.Trim()}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(rawKey)).AsSpan(0, 16));
    }

    private static string CreateAdminBulkEmailRequestHash(
        string audience,
        string subject,
        string body,
        IReadOnlyList<Guid> selectedUserIds)
    {
        var canonicalRequest = new StringBuilder();
        AppendLengthPrefixed(canonicalRequest, audience);
        AppendLengthPrefixed(canonicalRequest, subject);
        AppendLengthPrefixed(canonicalRequest, body);
        foreach (var userId in selectedUserIds)
        {
            AppendLengthPrefixed(canonicalRequest, userId.ToString("D"));
        }

        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonicalRequest.ToString())));
    }

    private static void AppendLengthPrefixed(StringBuilder builder, string value)
    {
        builder.Append(value.Length).Append(':').Append(value);
    }

    private static Result<AdminEmailBroadcastQueueResponse> ResolveAdminBulkEmailReplay(
        AdminEmailBroadcast existingBroadcast,
        string requestHash)
    {
        return string.Equals(existingBroadcast.RequestHash, requestHash, StringComparison.Ordinal)
            ? Result.Success(ToAdminEmailBroadcastQueueResponse(
                existingBroadcast.Id,
                existingBroadcast.RecipientCount,
                existingBroadcast.Status,
                existingBroadcast.CreatedAtUtc))
            : Result.Failure<AdminEmailBroadcastQueueResponse>(IdentityErrors.BulkEmailIdempotencyConflict);
    }

    public async Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken)
    {
        var normalizedRole = NormalizeSystemRole(command.Role);
        return await ExecuteAdminUserMutationAsync(
            lockAdminInvariant: false,
            async mutationCancellationToken =>
            {
                var user = await userManager.FindByIdAsync(command.UserId.ToString());
                if (user is null)
                {
                    return Result.Failure(IdentityErrors.UserNotFound);
                }

                var currentRoles = await userManager.GetRolesAsync(user);
                if (currentRoles.Contains(normalizedRole, StringComparer.Ordinal))
                {
                    return Result.Success();
                }

                if (!await roleManager.RoleExistsAsync(normalizedRole))
                {
                    return Result.Failure(IdentityErrors.OperationFailed);
                }

                var addResult = await userManager.AddToRoleAsync(user, normalizedRole);
                if (!addResult.Succeeded)
                {
                    return Result.Failure(IdentityErrors.OperationFailed);
                }

                var accessInvalidation = await InvalidateUserAccessAsync(
                    user,
                    revokeRefreshSessions: false,
                    mutationCancellationToken);
                if (accessInvalidation.IsFailure)
                {
                    return accessInvalidation;
                }

                await WriteAuditAsync(
                    user.Id,
                    "user.role.assigned",
                    $"Assigned role '{normalizedRole}'.",
                    mutationCancellationToken,
                    targetType: "user",
                    targetId: user.Id.ToString("D"),
                    oldValue: string.Join(",", currentRoles.OrderBy(role => role, StringComparer.OrdinalIgnoreCase)),
                    newValue: string.Join(",", currentRoles.Append(normalizedRole).OrderBy(role => role, StringComparer.OrdinalIgnoreCase)));
                return Result.Success();
            },
            cancellationToken);
    }

    public async Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken)
    {
        var normalizedRole = NormalizeSystemRole(command.Role);
        return await ExecuteAdminUserMutationAsync(
            lockAdminInvariant: string.Equals(normalizedRole, SystemRoles.Admin, StringComparison.Ordinal),
            async mutationCancellationToken =>
            {
                var user = await userManager.FindByIdAsync(command.UserId.ToString());
                if (user is null)
                {
                    return Result.Failure(IdentityErrors.UserNotFound);
                }

                if (string.Equals(normalizedRole, SystemRoles.User, StringComparison.Ordinal))
                {
                    return Result.Failure(IdentityErrors.CannotRevokeBaseRole);
                }

                var currentRoles = await userManager.GetRolesAsync(user);
                if (!currentRoles.Contains(normalizedRole, StringComparer.Ordinal))
                {
                    return Result.Success();
                }

                if (string.Equals(normalizedRole, SystemRoles.Admin, StringComparison.Ordinal)
                    && await IsLastAdminAsync(user.Id, mutationCancellationToken))
                {
                    return Result.Failure(IdentityErrors.CannotRemoveLastAdmin);
                }

                var removeResult = await userManager.RemoveFromRoleAsync(user, normalizedRole);
                if (!removeResult.Succeeded)
                {
                    return Result.Failure(IdentityErrors.OperationFailed);
                }

                var accessInvalidation = await InvalidateUserAccessAsync(
                    user,
                    revokeRefreshSessions: true,
                    mutationCancellationToken);
                if (accessInvalidation.IsFailure)
                {
                    return accessInvalidation;
                }

                await WriteAuditAsync(
                    user.Id,
                    "user.role.revoked",
                    $"Revoked role '{normalizedRole}'.",
                    mutationCancellationToken,
                    targetType: "user",
                    targetId: user.Id.ToString("D"),
                    oldValue: string.Join(",", currentRoles.OrderBy(role => role, StringComparer.OrdinalIgnoreCase)),
                    newValue: string.Join(",", currentRoles.Where(role => !string.Equals(role, normalizedRole, StringComparison.Ordinal)).OrderBy(role => role, StringComparer.OrdinalIgnoreCase)));
                return Result.Success();
            },
            cancellationToken);
    }

    private static string NormalizeSystemRole(string? role)
    {
        var normalizedRole = role?.Trim();
        if (string.IsNullOrWhiteSpace(normalizedRole))
        {
            return string.Empty;
        }

        foreach (var supportedRole in SystemRoles.All)
        {
            if (string.Equals(supportedRole, normalizedRole, StringComparison.OrdinalIgnoreCase))
            {
                return supportedRole;
            }
        }

        return normalizedRole;
    }

    public async Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var oldValue = user.IsPremium.ToString();
        user.IsPremium = command.IsPremium;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(
            user.Id,
            "user.premium.updated",
            $"Premium status changed to '{command.IsPremium}'.",
            cancellationToken,
            targetType: "user",
            targetId: user.Id.ToString("D"),
            oldValue: oldValue,
            newValue: command.IsPremium.ToString());
        return Result.Success();
    }

    public async Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken)
    {
        return await ExecuteAdminUserMutationAsync(
            lockAdminInvariant: !command.IsActive,
            async mutationCancellationToken =>
            {
                var user = await userManager.FindByIdAsync(command.UserId.ToString());
                if (user is null)
                {
                    return Result.Failure(IdentityErrors.UserNotFound);
                }

                var oldValue = user.IsActive.ToString();
                var roles = await userManager.GetRolesAsync(user);
                if (!command.IsActive
                    && roles.Contains(SystemRoles.Admin, StringComparer.Ordinal)
                    && await IsLastAdminAsync(user.Id, mutationCancellationToken))
                {
                    return Result.Failure(IdentityErrors.CannotRemoveLastAdmin);
                }

                user.IsActive = command.IsActive;
                var updateResult = await userManager.UpdateAsync(user);
                if (!updateResult.Succeeded)
                {
                    return Result.Failure(IdentityErrors.OperationFailed);
                }

                var accessInvalidation = await InvalidateUserAccessAsync(
                    user,
                    revokeRefreshSessions: true,
                    mutationCancellationToken);
                if (accessInvalidation.IsFailure)
                {
                    return accessInvalidation;
                }

                await WriteAuditAsync(
                    user.Id,
                    command.IsActive ? "user.unblocked" : "user.blocked",
                    $"Active status changed to '{command.IsActive}'.",
                    mutationCancellationToken,
                    targetType: "user",
                    targetId: user.Id.ToString("D"),
                    oldValue: oldValue,
                    newValue: command.IsActive.ToString());
                return Result.Success();
            },
            cancellationToken);
    }

    private async Task<Result> DeleteUserInternalAsync(
        Guid userId,
        string auditAction,
        string auditDetails,
        CancellationToken cancellationToken)
    {
        string? avatarUrl = null;
        var result = await ExecuteAdminUserMutationAsync(
            lockAdminInvariant: true,
            async mutationCancellationToken =>
            {
                var user = await userManager.FindByIdAsync(userId.ToString());
                if (user is null)
                {
                    return Result.Failure(IdentityErrors.UserNotFound);
                }

                var roles = await userManager.GetRolesAsync(user);
                if (roles.Contains(SystemRoles.Admin, StringComparer.Ordinal)
                    && await IsLastAdminAsync(user.Id, mutationCancellationToken))
                {
                    return Result.Failure(IdentityErrors.CannotRemoveLastAdmin);
                }

                avatarUrl = user.AvatarUrl;
                var now = DateTime.UtcNow;
                var externalProviders = await dbContext.ExternalAuthProviders
                    .Where(x => x.UserId == userId)
                    .ToListAsync(mutationCancellationToken);
                await BlockDeletedAccountIdentifiersAsync(user.Email, externalProviders, now, mutationCancellationToken);

                var deleteUserResult = await userManager.DeleteAsync(user);
                if (!deleteUserResult.Succeeded)
                {
                    return Result.Failure(IdentityErrors.OperationFailed);
                }

                var refreshSessions = await dbContext.RefreshTokenSessions
                    .Where(x => x.UserId == userId)
                    .ToListAsync(mutationCancellationToken);

                var emailCodes = await dbContext.UserEmailCodes
                    .Where(x => x.UserId == userId)
                    .ToListAsync(mutationCancellationToken);

                var emailJobs = await dbContext.EmailDispatchJobs
                    .Where(x => x.UserId == userId)
                    .ToListAsync(mutationCancellationToken);

                foreach (var refreshSession in refreshSessions.Where(static x => x.RevokedAtUtc is null))
                {
                    refreshSession.RevokedAtUtc = now;
                }

                if (emailCodes.Count > 0)
                {
                    dbContext.UserEmailCodes.RemoveRange(emailCodes);
                }

                if (emailJobs.Count > 0)
                {
                    dbContext.EmailDispatchJobs.RemoveRange(emailJobs);
                }

                await dbContext.SaveChangesAsync(mutationCancellationToken);
                await WriteAuditAsync(
                    userId,
                    auditAction,
                    auditDetails,
                    mutationCancellationToken,
                    targetType: "user",
                    targetId: userId.ToString("D"));

                return Result.Success();
            },
            cancellationToken);

        if (result.IsSuccess)
        {
            await avatarStorage.DeleteAsync(avatarUrl, CancellationToken.None);
        }

        return result;
    }

    private async Task BlockDeletedAccountIdentifiersAsync(
        string? email,
        IReadOnlyCollection<ExternalAuthProvider> externalProviders,
        DateTime deletedAtUtc,
        CancellationToken cancellationToken)
    {
        var normalizedEmail = NormalizeEmail(email);
        if (!string.IsNullOrWhiteSpace(normalizedEmail)
            && !await dbContext.DeletedAccountBlocks.AnyAsync(x => x.Email == normalizedEmail, cancellationToken))
        {
            dbContext.DeletedAccountBlocks.Add(new DeletedAccountBlock
            {
                Id = Guid.NewGuid(),
                Email = normalizedEmail,
                DeletedAtUtc = deletedAtUtc
            });
        }

        foreach (var externalProvider in externalProviders)
        {
            if (await dbContext.DeletedAccountBlocks.AnyAsync(
                    x => x.Provider == externalProvider.Provider && x.ProviderUserId == externalProvider.ProviderUserId,
                    cancellationToken))
            {
                continue;
            }

            dbContext.DeletedAccountBlocks.Add(new DeletedAccountBlock
            {
                Id = Guid.NewGuid(),
                Provider = externalProvider.Provider,
                ProviderUserId = externalProvider.ProviderUserId,
                DeletedAtUtc = deletedAtUtc
            });
        }
    }

    private async Task<bool> IsLastAdminAsync(Guid userId, CancellationToken cancellationToken)
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
                userManager.Users.AsNoTracking().Where(user => user.IsActive),
                userRole => userRole.UserId,
                user => user.Id,
                (_, _) => true)
            .AnyAsync(cancellationToken);
    }

    private Task<Result> ExecuteAdminUserMutationAsync(
        bool lockAdminInvariant,
        Func<CancellationToken, Task<Result>> mutation,
        CancellationToken cancellationToken)
    {
        return AdminRoleInvariantExecutor.ExecuteAsync(
            dbContext,
            lockAdminInvariant,
            mutation,
            static result => result.IsSuccess,
            cancellationToken);
    }

    private async Task<Result> InvalidateUserAccessAsync(
        AppUser user,
        bool revokeRefreshSessions,
        CancellationToken cancellationToken)
    {
        var securityStampResult = await userManager.UpdateSecurityStampAsync(user);
        if (!securityStampResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        if (revokeRefreshSessions)
        {
            await RevokeRefreshTokensAsync(user.Id, DateTime.UtcNow, cancellationToken);
        }

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

    private static string EscapePostgresLikePattern(string value)
    {
        return value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("%", "\\%", StringComparison.Ordinal)
            .Replace("_", "\\_", StringComparison.Ordinal);
    }

    private static string? NormalizeAdminUsersSort(string? sort)
    {
        var normalizedSort = sort?.Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalizedSort) || normalizedSort == "default")
        {
            return "created_desc";
        }

        return normalizedSort is "created_desc" or "created_asc" or "last_activity_desc" or "last_activity_asc"
            ? normalizedSort
            : null;
    }

    private static bool IsAdminUsersLastActivitySort(string normalizedSort)
    {
        return normalizedSort is "last_activity_desc" or "last_activity_asc";
    }

    private static IOrderedQueryable<AppUser> ApplyAdminUsersSort(IQueryable<AppUser> query, string normalizedSort)
    {
        return normalizedSort switch
        {
            "created_asc" => query.OrderBy(user => user.CreatedAtUtc).ThenBy(user => user.Id),
            _ => query.OrderByDescending(user => user.CreatedAtUtc).ThenByDescending(user => user.Id)
        };
    }
}
