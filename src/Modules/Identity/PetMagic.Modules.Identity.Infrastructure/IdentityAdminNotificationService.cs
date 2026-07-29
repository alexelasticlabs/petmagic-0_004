using System.Text;
using System.Text.Json;

using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class IdentityAdminNotificationService(
    IdentityDbContext dbContext,
    IAdminNotificationRealtimeNotifier? realtimeNotifier = null)
    : IAdminNotificationService, IAdminNotificationSink
{
    private const int DefaultTake = 20;
    private const int MaxTake = 100;
    private const int MaxReceiptWriteAttempts = 4;
    private const string CriticalPriority = AdminNotificationPriorities.Critical;
    private static readonly HashSet<string> AllowedRoles = new(StringComparer.Ordinal)
    {
        "Admin",
        "Moderator",
    };
    private static readonly HashSet<string> AllowedCategories = new(StringComparer.Ordinal)
    {
        "support",
        "generation",
        "capacity",
        "economy",
        "content",
        "moderation",
        "system",
    };
    private static readonly HashSet<string> AllowedPriorities = new(StringComparer.Ordinal)
    {
        AdminNotificationPriorities.Normal,
        AdminNotificationPriorities.Warning,
        CriticalPriority,
    };
    private static readonly string[] ForbiddenPayloadKeyFragments =
    [
        "email",
        "password",
        "secret",
        "token",
        "exception",
        "stack",
        "authorization",
        "cookie",
        "html",
    ];
    private static readonly string[] AllowedHrefPrefixes =
    [
        "/dashboard",
        "/generations",
        "/support",
        "/economy",
        "/templates",
        "/moderation",
        "/feedback",
        "/users",
        "/audit",
        "/notifications",
    ];

    public async Task<Result<AdminNotificationsPageResponse>> ListAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        AdminNotificationsQuery query,
        CancellationToken cancellationToken)
    {
        var take = Math.Clamp(query.Take ?? DefaultTake, 1, MaxTake);
        var state = NormalizeOptional(query.State)?.ToLowerInvariant() ?? "active";
        var category = NormalizeOptional(query.Category)?.ToLowerInvariant();
        var priority = NormalizeOptional(query.Priority)?.ToLowerInvariant();
        if (state is not ("active" or "unread" or "read" or "archived" or "all")
            || (category is not null && !AllowedCategories.Contains(category))
            || (priority is not null && !AllowedPriorities.Contains(priority)))
        {
            return Result.Failure<AdminNotificationsPageResponse>(AdminNotificationErrors.FilterInvalid);
        }

        CursorValue? cursor = null;
        if (!string.IsNullOrWhiteSpace(query.Cursor))
        {
            cursor = DecodeCursor(query.Cursor!);
            if (cursor is null)
            {
                return Result.Failure<AdminNotificationsPageResponse>(AdminNotificationErrors.CursorInvalid);
            }
        }

        var now = DateTime.UtcNow;
        var audience = ApplyAudience(dbContext.AdminNotificationEvents.AsNoTracking(), userId, roles)
            .Where(x => !x.ExpiresAtUtc.HasValue || x.ExpiresAtUtc > now);

        var unreadCount = await audience.CountAsync(
            x => !x.Receipts.Any(receipt =>
                receipt.UserId == userId && (receipt.ReadAtUtc.HasValue || receipt.ArchivedAtUtc.HasValue)),
            cancellationToken);
        var criticalUnacknowledgedCount = await audience.CountAsync(
            x => x.Priority == CriticalPriority && !x.AcknowledgedAtUtc.HasValue,
            cancellationToken);

        var filtered = audience;
        if (category is not null)
        {
            filtered = filtered.Where(x => x.Category == category);
        }

        if (priority is not null)
        {
            filtered = filtered.Where(x => x.Priority == priority);
        }

        filtered = state switch
        {
            "active" => filtered.Where(x => !x.Receipts.Any(receipt =>
                receipt.UserId == userId && receipt.ArchivedAtUtc.HasValue)),
            "unread" => filtered.Where(x => !x.Receipts.Any(receipt =>
                receipt.UserId == userId && (receipt.ReadAtUtc.HasValue || receipt.ArchivedAtUtc.HasValue))),
            "read" => filtered.Where(x => x.Receipts.Any(receipt =>
                receipt.UserId == userId && receipt.ReadAtUtc.HasValue && !receipt.ArchivedAtUtc.HasValue)),
            "archived" => filtered.Where(x => x.Receipts.Any(receipt =>
                receipt.UserId == userId && receipt.ArchivedAtUtc.HasValue)),
            _ => filtered,
        };

        if (cursor is not null)
        {
            filtered = filtered.Where(x =>
                x.CreatedAtUtc < cursor.CreatedAtUtc
                || (x.CreatedAtUtc == cursor.CreatedAtUtc && x.Id.CompareTo(cursor.Id) < 0));
        }

        var events = await filtered
            .Include(x => x.Receipts.Where(receipt => receipt.UserId == userId))
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .Take(take + 1)
            .ToListAsync(cancellationToken);
        var hasMore = events.Count > take;
        if (hasMore)
        {
            events.RemoveAt(events.Count - 1);
        }

        var items = events.Select(x => Map(x, userId)).ToList();
        var last = events.LastOrDefault();
        return Result.Success(new AdminNotificationsPageResponse(
            items,
            hasMore && last is not null ? EncodeCursor(last.CreatedAtUtc, last.Id) : null,
            unreadCount,
            criticalUnacknowledgedCount,
            now));
    }

    public async Task<Result<AdminNotificationItemResponse>> MarkReadAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken cancellationToken)
    {
        var notification = await FindAccessibleAsync(notificationId, userId, roles, true, cancellationToken);
        if (notification is null)
        {
            return Result.Failure<AdminNotificationItemResponse>(AdminNotificationErrors.NotificationNotFound);
        }

        var receipt = notification.Receipts.SingleOrDefault(x => x.UserId == userId);
        if (receipt is null)
        {
            receipt = new AdminNotificationReceipt
            {
                EventId = notification.Id,
                UserId = userId,
                ReadAtUtc = DateTime.UtcNow,
            };
            notification.Receipts.Add(receipt);
        }
        else if (!receipt.ReadAtUtc.HasValue)
        {
            receipt.ReadAtUtc = DateTime.UtcNow;
        }

        await SaveReceiptAsync(notificationId, userId, receipt, cancellationToken);
        await NotifyChangedAsync(notification, cancellationToken);
        return Result.Success(Map(notification, userId));
    }

    public async Task<Result<int>> MarkAllReadAsync(
        Guid userId,
        IReadOnlyCollection<string> roles,
        DateTime cutoffUtc,
        CancellationToken cancellationToken)
    {
        cutoffUtc = NormalizeUtc(cutoffUtc);
        if (cutoffUtc > DateTime.UtcNow.AddMinutes(1))
        {
            return Result.Failure<int>(AdminNotificationErrors.FilterInvalid);
        }

        var ids = await ApplyAudience(dbContext.AdminNotificationEvents.AsNoTracking(), userId, roles)
            .Where(x => x.CreatedAtUtc <= cutoffUtc)
            .Where(x => !x.ExpiresAtUtc.HasValue || x.ExpiresAtUtc > DateTime.UtcNow)
            .Where(x => !x.Receipts.Any(receipt => receipt.UserId == userId && receipt.ReadAtUtc.HasValue))
            .Select(x => x.Id)
            .ToListAsync(cancellationToken);
        if (ids.Count == 0)
        {
            return Result.Success(0);
        }

        await SaveReadAllReceiptsAsync(ids, userId, DateTime.UtcNow, cancellationToken);
        if (realtimeNotifier is not null)
        {
            await realtimeNotifier.NotifyChangedAsync(roles, userId, cancellationToken);
        }

        return Result.Success(ids.Count);
    }

    public async Task<Result<AdminNotificationItemResponse>> ArchiveAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        CancellationToken cancellationToken)
    {
        var notification = await FindAccessibleAsync(notificationId, userId, roles, true, cancellationToken);
        if (notification is null)
        {
            return Result.Failure<AdminNotificationItemResponse>(AdminNotificationErrors.NotificationNotFound);
        }

        var now = DateTime.UtcNow;
        var receipt = notification.Receipts.SingleOrDefault(x => x.UserId == userId);
        if (receipt is null)
        {
            receipt = new AdminNotificationReceipt
            {
                EventId = notification.Id,
                UserId = userId,
                ReadAtUtc = now,
                ArchivedAtUtc = now,
            };
            notification.Receipts.Add(receipt);
        }
        else
        {
            receipt.ReadAtUtc ??= now;
            receipt.ArchivedAtUtc ??= now;
        }

        await SaveReceiptAsync(notificationId, userId, receipt, cancellationToken);
        await NotifyChangedAsync(notification, cancellationToken);
        return Result.Success(Map(notification, userId));
    }

    public async Task<AdminNotificationAcknowledgeResult> AcknowledgeAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        string reason,
        int expectedVersion,
        CancellationToken cancellationToken)
    {
        reason = reason.Trim();
        if (reason.Length is < 3 or > 500)
        {
            return Invalid(AdminNotificationErrors.AcknowledgementReasonInvalid);
        }

        if (expectedVersion <= 0)
        {
            return Invalid(AdminNotificationErrors.VersionInvalid);
        }

        var notification = await FindAccessibleAsync(notificationId, userId, roles, true, cancellationToken);
        if (notification is null)
        {
            return new AdminNotificationAcknowledgeResult(
                AdminNotificationAcknowledgeStatus.NotFound,
                null,
                AdminNotificationErrors.NotificationNotFound);
        }

        if (notification.Priority != CriticalPriority)
        {
            return Invalid(AdminNotificationErrors.AcknowledgementNotCritical, Map(notification, userId));
        }

        if (notification.AcknowledgedAtUtc.HasValue)
        {
            var current = Map(notification, userId);
            return notification.AcknowledgedByUserId == userId
                && string.Equals(notification.AcknowledgementReason, reason, StringComparison.Ordinal)
                ? new AdminNotificationAcknowledgeResult(
                    AdminNotificationAcknowledgeStatus.IdempotentReplay,
                    current,
                    Error.None)
                : Conflict(current);
        }

        if (notification.Version != expectedVersion)
        {
            return Conflict(Map(notification, userId));
        }

        var now = DateTime.UtcNow;
        notification.AcknowledgedByUserId = userId;
        notification.AcknowledgedAtUtc = now;
        notification.AcknowledgementReason = reason;
        notification.ExpiresAtUtc = now.AddDays(90);
        notification.Version += 1;
        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            ActorUserId = userId,
            ActorRole = string.Join(",", roles.Where(AllowedRoles.Contains).Order()),
            Action = "admin.notification.acknowledged",
            TargetType = "admin_notification",
            TargetId = notification.Id.ToString("D"),
            NewValue = JsonSerializer.Serialize(new { notification.Type, notification.Version }),
            Details = reason,
            CreatedAtUtc = now,
            OccurredAtUtc = now,
        });

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            var current = await FindAccessibleAsync(notificationId, userId, roles, false, cancellationToken);
            return current is null ? Conflict(null) : Conflict(Map(current, userId));
        }

        await NotifyChangedAsync(notification, cancellationToken);
        return new AdminNotificationAcknowledgeResult(
            AdminNotificationAcknowledgeStatus.Acknowledged,
            Map(notification, userId),
            Error.None);
    }

    public async Task PublishAsync(AdminNotificationMessage message, CancellationToken cancellationToken)
    {
        ValidateMessage(message);
        var source = message.Source.Trim().ToLowerInvariant();
        var dedupeKey = message.DeduplicationKey.Trim();
        if (await dbContext.AdminNotificationEvents.AsNoTracking().AnyAsync(
                x => x.Source == source && x.DeduplicationKey == dedupeKey,
                cancellationToken))
        {
            return;
        }

        var occurredAtUtc = NormalizeUtc(message.OccurredAtUtc ?? DateTime.UtcNow);
        var priority = message.Priority.Trim().ToLowerInvariant();
        var roles = message.AudienceRoles.Distinct(StringComparer.Ordinal).Order().ToArray();
        var notification = new AdminNotificationEvent
        {
            Id = Guid.NewGuid(),
            Type = message.Type.Trim().ToLowerInvariant(),
            SchemaVersion = message.SchemaVersion,
            PayloadJson = message.Payload.GetRawText(),
            Category = message.Category.Trim().ToLowerInvariant(),
            Priority = priority,
            AudienceRoles = EncodeRoles(roles),
            TargetUserId = message.TargetUserId,
            Href = NormalizeOptional(message.Href),
            Source = source,
            DeduplicationKey = dedupeKey,
            CreatedAtUtc = occurredAtUtc,
            ExpiresAtUtc = message.ExpiresAtUtc.HasValue
                ? NormalizeUtc(message.ExpiresAtUtc.Value)
                : priority == CriticalPriority ? null : occurredAtUtc.AddDays(30),
            Version = 1,
        };
        dbContext.AdminNotificationEvents.Add(notification);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            dbContext.ChangeTracker.Clear();
            if (await dbContext.AdminNotificationEvents.AsNoTracking().AnyAsync(
                    x => x.Source == source && x.DeduplicationKey == dedupeKey,
                    cancellationToken))
            {
                return;
            }

            throw;
        }

        if (realtimeNotifier is not null)
        {
            await realtimeNotifier.NotifyChangedAsync(roles, message.TargetUserId, cancellationToken);
        }
    }

    private IQueryable<AdminNotificationEvent> ApplyAudience(
        IQueryable<AdminNotificationEvent> query,
        Guid userId,
        IReadOnlyCollection<string> roles)
    {
        var isAdmin = roles.Contains("Admin", StringComparer.Ordinal);
        var isModerator = roles.Contains("Moderator", StringComparer.Ordinal);
        return query.Where(x =>
            (!x.TargetUserId.HasValue || x.TargetUserId == userId)
            && ((isAdmin && EF.Functions.Like(x.AudienceRoles, "%|Admin|%"))
                || (isModerator && EF.Functions.Like(x.AudienceRoles, "%|Moderator|%"))));
    }

    private async Task<AdminNotificationEvent?> FindAccessibleAsync(
        Guid notificationId,
        Guid userId,
        IReadOnlyCollection<string> roles,
        bool tracked,
        CancellationToken cancellationToken)
    {
        IQueryable<AdminNotificationEvent> query = dbContext.AdminNotificationEvents;
        if (!tracked)
        {
            query = query.AsNoTracking();
        }

        return await ApplyAudience(query, userId, roles)
            .Include(x => x.Receipts.Where(receipt => receipt.UserId == userId))
            .SingleOrDefaultAsync(x => x.Id == notificationId, cancellationToken);
    }

    private async Task SaveReceiptAsync(
        Guid notificationId,
        Guid userId,
        AdminNotificationReceipt receipt,
        CancellationToken cancellationToken)
    {
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            var readAtUtc = receipt.ReadAtUtc;
            var archivedAtUtc = receipt.ArchivedAtUtc;
            dbContext.ChangeTracker.Clear();
            var updatedCount = await dbContext.AdminNotificationReceipts
                .Where(x => x.EventId == notificationId && x.UserId == userId)
                .ExecuteUpdateAsync(
                    setters => setters
                        .SetProperty(x => x.ReadAtUtc, x => x.ReadAtUtc ?? readAtUtc)
                        .SetProperty(x => x.ArchivedAtUtc, x => x.ArchivedAtUtc ?? archivedAtUtc),
                    cancellationToken);
            if (updatedCount == 0)
            {
                throw;
            }
        }
    }

    private async Task SaveReadAllReceiptsAsync(
        IReadOnlyCollection<Guid> eventIds,
        Guid userId,
        DateTime readAtUtc,
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= MaxReceiptWriteAttempts; attempt++)
        {
            var existing = await dbContext.AdminNotificationReceipts
                .Where(x => x.UserId == userId && eventIds.Contains(x.EventId))
                .ToDictionaryAsync(x => x.EventId, cancellationToken);
            foreach (var eventId in eventIds)
            {
                if (existing.TryGetValue(eventId, out var receipt))
                {
                    receipt.ReadAtUtc ??= readAtUtc;
                }
                else
                {
                    dbContext.AdminNotificationReceipts.Add(new AdminNotificationReceipt
                    {
                        EventId = eventId,
                        UserId = userId,
                        ReadAtUtc = readAtUtc,
                    });
                }
            }

            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                return;
            }
            catch (DbUpdateException) when (attempt < MaxReceiptWriteAttempts)
            {
                // A concurrent request may have inserted one of the composite
                // event/user receipts after the read. Reload and merge the now
                // authoritative rows instead of surfacing a transient 500.
                dbContext.ChangeTracker.Clear();
            }
        }
    }

    private async Task NotifyChangedAsync(
        AdminNotificationEvent notification,
        CancellationToken cancellationToken)
    {
        if (realtimeNotifier is not null)
        {
            await realtimeNotifier.NotifyChangedAsync(
                DecodeRoles(notification.AudienceRoles),
                notification.TargetUserId,
                cancellationToken);
        }
    }

    private static AdminNotificationItemResponse Map(AdminNotificationEvent notification, Guid userId)
    {
        var receipt = notification.Receipts.SingleOrDefault(x => x.UserId == userId);
        using var payload = JsonDocument.Parse(notification.PayloadJson);
        var acknowledgement = notification.AcknowledgedAtUtc.HasValue
            && notification.AcknowledgedByUserId.HasValue
            && notification.AcknowledgementReason is not null
            ? new AdminNotificationAcknowledgementResponse(
                notification.AcknowledgedByUserId.Value,
                notification.AcknowledgedAtUtc.Value,
                notification.AcknowledgementReason)
            : null;
        return new AdminNotificationItemResponse(
            notification.Id,
            notification.Type,
            notification.SchemaVersion,
            payload.RootElement.Clone(),
            notification.Category,
            notification.Priority,
            notification.Href,
            notification.Source,
            notification.CreatedAtUtc,
            notification.ExpiresAtUtc,
            receipt?.ReadAtUtc,
            receipt?.ArchivedAtUtc,
            acknowledgement,
            notification.Version);
    }

    private static void ValidateMessage(AdminNotificationMessage message)
    {
        var roles = message.AudienceRoles.Distinct(StringComparer.Ordinal).ToArray();
        if (!IsSafeIdentifier(message.Type, 80)
            || message.SchemaVersion <= 0
            || !AllowedCategories.Contains(message.Category.Trim().ToLowerInvariant())
            || !AllowedPriorities.Contains(message.Priority.Trim().ToLowerInvariant())
            || roles.Length == 0
            || roles.Any(role => !AllowedRoles.Contains(role))
            || !IsSafeIdentifier(message.Source, 80)
            || string.IsNullOrWhiteSpace(message.DeduplicationKey)
            || message.DeduplicationKey.Trim().Length > 160
            || !IsSafeHref(message.Href)
            || message.Payload.ValueKind != JsonValueKind.Object
            || Encoding.UTF8.GetByteCount(message.Payload.GetRawText()) > 4000
            || ContainsForbiddenPayloadKey(message.Payload))
        {
            throw new ArgumentException("The admin notification payload is invalid.", nameof(message));
        }
    }

    private static bool ContainsForbiddenPayloadKey(JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            foreach (var property in element.EnumerateObject())
            {
                var normalized = property.Name.ToLowerInvariant();
                if (ForbiddenPayloadKeyFragments.Any(normalized.Contains)
                    || ContainsForbiddenPayloadKey(property.Value))
                {
                    return true;
                }
            }
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            return element.EnumerateArray().Any(ContainsForbiddenPayloadKey);
        }

        return false;
    }

    private static bool IsSafeIdentifier(string value, int maxLength)
    {
        var normalized = value.Trim();
        return normalized.Length is > 0
            && normalized.Length <= maxLength
            && normalized.All(character =>
                char.IsAsciiLetterOrDigit(character) || character is '.' or '_' or '-');
    }

    private static bool IsSafeHref(string? href)
    {
        if (string.IsNullOrWhiteSpace(href))
        {
            return true;
        }

        var normalized = href.Trim();
        return normalized.Length <= 512
            && normalized.StartsWith("/", StringComparison.Ordinal)
            && !normalized.StartsWith("//", StringComparison.Ordinal)
            && !normalized.Contains('\\')
            && Uri.TryCreate(normalized, UriKind.Relative, out _)
            && AllowedHrefPrefixes.Any(prefix =>
                normalized.Equals(prefix, StringComparison.Ordinal)
                || normalized.StartsWith(prefix + "/", StringComparison.Ordinal)
                || normalized.StartsWith(prefix + "?", StringComparison.Ordinal));
    }

    private static string EncodeRoles(IEnumerable<string> roles) => $"|{string.Join('|', roles)}|";

    private static IReadOnlyCollection<string> DecodeRoles(string roles) => roles
        .Split('|', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static string EncodeCursor(DateTime createdAtUtc, Guid id)
    {
        var value = $"{createdAtUtc.Ticks}:{id:D}";
        return Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static CursorValue? DecodeCursor(string cursor)
    {
        try
        {
            var normalized = cursor.Replace('-', '+').Replace('_', '/');
            normalized = normalized.PadRight(normalized.Length + ((4 - normalized.Length % 4) % 4), '=');
            var decoded = Encoding.UTF8.GetString(Convert.FromBase64String(normalized));
            var separator = decoded.IndexOf(':', StringComparison.Ordinal);
            if (separator <= 0
                || !long.TryParse(decoded[..separator], out var ticks)
                || !Guid.TryParse(decoded[(separator + 1)..], out var id))
            {
                return null;
            }

            return new CursorValue(new DateTime(ticks, DateTimeKind.Utc), id);
        }
        catch (FormatException)
        {
            return null;
        }
        catch (ArgumentOutOfRangeException)
        {
            return null;
        }
    }

    private static AdminNotificationAcknowledgeResult Invalid(
        Error error,
        AdminNotificationItemResponse? notification = null) => new(
            AdminNotificationAcknowledgeStatus.Invalid,
            notification,
            error);

    private static AdminNotificationAcknowledgeResult Conflict(
        AdminNotificationItemResponse? notification) => new(
            AdminNotificationAcknowledgeStatus.Conflict,
            notification,
            AdminNotificationErrors.AcknowledgementConflict);

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }

    private static DateTime NormalizeUtc(DateTime value) => value.Kind switch
    {
        DateTimeKind.Utc => value,
        DateTimeKind.Local => value.ToUniversalTime(),
        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
    };

    private sealed record CursorValue(DateTime CreatedAtUtc, Guid Id);
}
