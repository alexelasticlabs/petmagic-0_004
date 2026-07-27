using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class IdentityAdminAuditQueryService(IdentityDbContext dbContext) : IAdminAuditQueryService
{
    private const int DefaultTake = 25;
    private const int MaxTake = 100;
    private const int MaxSearchLength = 120;
    private static readonly TimeSpan MaxDateRange = TimeSpan.FromDays(90);

    private static readonly HashSet<string> EconomyTargetTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "purchase_order",
        "economy_incident",
        "subscription",
        "subscription_plan",
        "payment_provider_configuration",
        "currency_pack",
        "redeem_code",
    };

    private static readonly HashSet<string> ContentTargetTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        "template",
        "templategenerationjob",
        "template_generation",
        "feedback",
        "template_analytics_event",
        "template_of_the_day",
        "template_of_the_day_settings",
    };

    public async Task<Result<AdminAuditEventsPageResponse>> ListAsync(
        AdminAuditEventsQuery query,
        CancellationToken cancellationToken)
    {
        var normalizedSearch = query.Search?.Trim();
        if (normalizedSearch is { Length: > MaxSearchLength })
        {
            return Result.Failure<AdminAuditEventsPageResponse>(AdminAuditErrors.SearchTooLong);
        }

        var normalizedCategory = NormalizeOptional(query.Category)?.ToLowerInvariant();
        if (normalizedCategory is not null && !AdminAuditCategories.All.Contains(normalizedCategory))
        {
            return Result.Failure<AdminAuditEventsPageResponse>(AdminAuditErrors.CategoryInvalid);
        }

        DateTime? fromUtc = query.FromUtc.HasValue ? NormalizeUtc(query.FromUtc.Value) : null;
        DateTime? toUtc = query.ToUtc.HasValue ? NormalizeUtc(query.ToUtc.Value) : null;
        if (fromUtc.HasValue && !toUtc.HasValue)
        {
            if (fromUtc.Value > DateTime.MaxValue - MaxDateRange)
            {
                return Result.Failure<AdminAuditEventsPageResponse>(AdminAuditErrors.DateRangeInvalid);
            }

            toUtc = fromUtc.Value + MaxDateRange;
        }

        if (!fromUtc.HasValue && toUtc.HasValue)
        {
            if (toUtc.Value < DateTime.MinValue + MaxDateRange)
            {
                return Result.Failure<AdminAuditEventsPageResponse>(AdminAuditErrors.DateRangeInvalid);
            }

            fromUtc = toUtc.Value - MaxDateRange;
        }

        if (fromUtc.HasValue
            && toUtc.HasValue
            && (fromUtc.Value > toUtc.Value || toUtc.Value - fromUtc.Value > MaxDateRange))
        {
            return Result.Failure<AdminAuditEventsPageResponse>(AdminAuditErrors.DateRangeInvalid);
        }

        var skip = Math.Max(0, query.Skip ?? 0);
        var take = Math.Clamp(query.Take ?? DefaultTake, 1, MaxTake);
        var filteredQuery = dbContext.AuditEvents.AsNoTracking();

        if (query.ActorUserId.HasValue)
        {
            filteredQuery = filteredQuery.Where(x => x.ActorUserId == query.ActorUserId.Value);
        }

        if (query.SubjectUserId.HasValue)
        {
            filteredQuery = filteredQuery.Where(x => x.SubjectUserId == query.SubjectUserId.Value);
        }

        if (fromUtc.HasValue)
        {
            filteredQuery = filteredQuery.Where(x => x.OccurredAtUtc >= fromUtc.Value);
        }

        if (toUtc.HasValue)
        {
            filteredQuery = filteredQuery.Where(x => x.OccurredAtUtc <= toUtc.Value);
        }

        if (!string.IsNullOrWhiteSpace(normalizedSearch))
        {
            var normalizedSearchLower = normalizedSearch.ToLowerInvariant();
            var searchIsGuid = Guid.TryParse(normalizedSearch, out var searchGuid);
            filteredQuery = filteredQuery.Where(auditEvent =>
                auditEvent.Action.ToLower().Contains(normalizedSearchLower)
                || (auditEvent.ActorRole ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (auditEvent.TargetType ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (auditEvent.TargetId ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (auditEvent.CorrelationId ?? string.Empty).ToLower().Contains(normalizedSearchLower)
                || (searchIsGuid
                    && (auditEvent.Id == searchGuid
                        || auditEvent.ActorUserId == searchGuid
                        || auditEvent.SubjectUserId == searchGuid))
                || dbContext.Users.Any(user =>
                    (auditEvent.ActorUserId == user.Id || auditEvent.SubjectUserId == user.Id)
                    && (((user.Email ?? string.Empty).ToLower().Contains(normalizedSearchLower))
                        || ((user.DisplayName ?? string.Empty).ToLower().Contains(normalizedSearchLower)))));
        }

        filteredQuery = ApplyCategoryFilter(filteredQuery, normalizedCategory);

        var totalCount = await filteredQuery.CountAsync(cancellationToken);
        var uniqueActors = await filteredQuery
            .Where(x => x.ActorUserId.HasValue)
            .Select(x => x.ActorUserId!.Value)
            .Distinct()
            .CountAsync(cancellationToken);
        var accessEvents = await filteredQuery.CountAsync(
            x => x.Action.ToLower().StartsWith("auth.")
                || x.Action.ToLower().StartsWith("user.")
                || x.Action.ToLower().Contains(".role.")
                || x.Action.ToLower().Contains(".blocked")
                || x.Action.ToLower().Contains(".unblocked")
                || x.Action.ToLower() == "admin.user.deleted",
            cancellationToken);
        var systemEvents = await ApplyCategoryFilter(filteredQuery, AdminAuditCategories.System)
            .CountAsync(cancellationToken);

        var rows = await filteredQuery
            .OrderByDescending(x => x.OccurredAtUtc)
            .ThenByDescending(x => x.Id)
            .Skip(skip)
            .Take(take)
            .Select(x => new AuditEventListRow(
                x.Id,
                x.Action,
                x.ActorUserId,
                x.ActorRole,
                x.SubjectUserId,
                x.TargetType,
                x.TargetId,
                x.CorrelationId,
                x.OccurredAtUtc))
            .ToListAsync(cancellationToken);

        var identities = await LoadIdentitiesAsync(
            rows.SelectMany(x => new[] { x.ActorUserId, x.SubjectUserId })
                .Where(x => x.HasValue)
                .Select(x => x!.Value)
                .Distinct()
                .ToArray(),
            cancellationToken);
        var items = rows.Select(row => MapListItem(row, identities)).ToList();

        return Result.Success(new AdminAuditEventsPageResponse(
            items,
            skip,
            take,
            totalCount,
            (long)skip + items.Count < totalCount,
            new AdminAuditEventsSummaryResponse(
                totalCount,
                uniqueActors,
                accessEvents,
                systemEvents)));
    }

    public async Task<Result<AdminAuditEventDetailResponse>> GetAsync(
        Guid eventId,
        CancellationToken cancellationToken)
    {
        var auditEvent = await dbContext.AuditEvents
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == eventId, cancellationToken);
        if (auditEvent is null)
        {
            return Result.Failure<AdminAuditEventDetailResponse>(AdminAuditErrors.EventNotFound);
        }

        var identityIds = new[] { auditEvent.ActorUserId, auditEvent.SubjectUserId }
            .Where(x => x.HasValue)
            .Select(x => x!.Value)
            .Distinct()
            .ToArray();
        var identities = await LoadIdentitiesAsync(identityIds, cancellationToken);
        identities.TryGetValue(auditEvent.ActorUserId ?? Guid.Empty, out var actor);
        identities.TryGetValue(auditEvent.SubjectUserId ?? Guid.Empty, out var subject);

        return Result.Success(new AdminAuditEventDetailResponse(
            auditEvent.Id,
            SanitizeRequired(auditEvent.Action, 120),
            ResolveCategory(auditEvent.Action, auditEvent.TargetType),
            auditEvent.ActorUserId,
            SanitizeOptional(actor?.DisplayName, 120),
            SanitizeOptional(actor?.Email, 320),
            SanitizeOptional(auditEvent.ActorRole, 80),
            auditEvent.SubjectUserId,
            SanitizeOptional(subject?.DisplayName, 120),
            SanitizeOptional(subject?.Email, 320),
            SanitizeOptional(auditEvent.TargetType, 80),
            SanitizeOptional(auditEvent.TargetId, 160),
            SanitizeOptional(auditEvent.CorrelationId, 128),
            auditEvent.OccurredAtUtc,
            SanitizeOptional(auditEvent.OldValue, 2000),
            SanitizeOptional(auditEvent.NewValue, 2000),
            SanitizeRequired(auditEvent.Details, 2000),
            SanitizeOptional(auditEvent.IpAddress, 64),
            SanitizeOptional(auditEvent.UserAgent, 512),
            auditEvent.CreatedAtUtc));
    }

    private async Task<IReadOnlyDictionary<Guid, AuditIdentityRow>> LoadIdentitiesAsync(
        IReadOnlyCollection<Guid> userIds,
        CancellationToken cancellationToken)
    {
        if (userIds.Count == 0)
        {
            return new Dictionary<Guid, AuditIdentityRow>();
        }

        return await dbContext.Users
            .AsNoTracking()
            .Where(x => userIds.Contains(x.Id))
            .Select(x => new AuditIdentityRow(x.Id, x.DisplayName, x.Email))
            .ToDictionaryAsync(x => x.UserId, cancellationToken);
    }

    private static AdminAuditEventListItemResponse MapListItem(
        AuditEventListRow row,
        IReadOnlyDictionary<Guid, AuditIdentityRow> identities)
    {
        identities.TryGetValue(row.ActorUserId ?? Guid.Empty, out var actor);
        identities.TryGetValue(row.SubjectUserId ?? Guid.Empty, out var subject);

        return new AdminAuditEventListItemResponse(
            row.AuditEventId,
            SanitizeRequired(row.Action, 120),
            ResolveCategory(row.Action, row.TargetType),
            row.ActorUserId,
            SanitizeOptional(actor?.DisplayName, 120),
            SanitizeOptional(actor?.Email, 320),
            SanitizeOptional(row.ActorRole, 80),
            row.SubjectUserId,
            SanitizeOptional(subject?.DisplayName, 120),
            SanitizeOptional(subject?.Email, 320),
            SanitizeOptional(row.TargetType, 80),
            SanitizeOptional(row.TargetId, 160),
            SanitizeOptional(row.CorrelationId, 128),
            row.OccurredAtUtc);
    }

    private static IQueryable<AuditEvent> ApplyCategoryFilter(
        IQueryable<AuditEvent> query,
        string? category)
    {
        return category switch
        {
            AdminAuditCategories.Support => query.Where(x =>
                x.Action.ToLower().StartsWith("admin.support.")
                || (x.TargetType ?? string.Empty).ToLower() == "supportconversation"),
            AdminAuditCategories.Gamification => query.Where(x =>
                x.Action.ToLower().StartsWith("admin.gamification.")
                || (x.TargetType ?? string.Empty).ToLower() == "dailystreak"),
            AdminAuditCategories.Economy => query.Where(x =>
                x.Action.ToLower().StartsWith("admin.payment.")
                || x.Action.ToLower().StartsWith("admin.economy.")
                || x.Action.ToLower().StartsWith("admin.subscription.")
                || x.Action.ToLower().Contains(".wallet.")
                || (x.TargetType ?? string.Empty).ToLower() == "purchase_order"
                || (x.TargetType ?? string.Empty).ToLower() == "economy_incident"
                || (x.TargetType ?? string.Empty).ToLower() == "subscription"
                || (x.TargetType ?? string.Empty).ToLower() == "subscription_plan"
                || (x.TargetType ?? string.Empty).ToLower() == "payment_provider_configuration"
                || (x.TargetType ?? string.Empty).ToLower() == "currency_pack"
                || (x.TargetType ?? string.Empty).ToLower() == "redeem_code"),
            AdminAuditCategories.Content => query.Where(x =>
                x.Action.ToLower().StartsWith("admin.templates.")
                || x.Action.ToLower().StartsWith("admin.template_")
                || x.Action.ToLower().StartsWith("admin.content.")
                || x.Action.ToLower().StartsWith("admin.feedback.")
                || (x.TargetType ?? string.Empty).ToLower() == "template"
                || (x.TargetType ?? string.Empty).ToLower() == "templategenerationjob"
                || (x.TargetType ?? string.Empty).ToLower() == "template_generation"
                || (x.TargetType ?? string.Empty).ToLower() == "feedback"
                || (x.TargetType ?? string.Empty).ToLower() == "template_analytics_event"
                || (x.TargetType ?? string.Empty).ToLower() == "template_of_the_day"
                || (x.TargetType ?? string.Empty).ToLower() == "template_of_the_day_settings"),
            AdminAuditCategories.Identity => query.Where(x =>
                !(x.Action.ToLower().StartsWith("admin.payment.")
                    || x.Action.ToLower().StartsWith("admin.economy.")
                    || x.Action.ToLower().StartsWith("admin.subscription.")
                    || x.Action.ToLower().Contains(".wallet."))
                && (x.Action.ToLower().StartsWith("auth.")
                    || x.Action.ToLower().StartsWith("user.")
                    || x.Action.ToLower().StartsWith("admin.user.")
                    || x.Action.ToLower().StartsWith("admin.bulk_email.")
                    || (x.TargetType ?? string.Empty).ToLower() == "user"
                    || (x.TargetType ?? string.Empty).ToLower() == "email-broadcast")),
            AdminAuditCategories.System => query.Where(x =>
                !(x.Action.ToLower().StartsWith("admin.support.")
                    || (x.TargetType ?? string.Empty).ToLower() == "supportconversation"
                    || x.Action.ToLower().StartsWith("admin.gamification.")
                    || (x.TargetType ?? string.Empty).ToLower() == "dailystreak"
                    || x.Action.ToLower().StartsWith("admin.payment.")
                    || x.Action.ToLower().StartsWith("admin.economy.")
                    || x.Action.ToLower().StartsWith("admin.subscription.")
                    || x.Action.ToLower().Contains(".wallet.")
                    || (x.TargetType ?? string.Empty).ToLower() == "purchase_order"
                    || (x.TargetType ?? string.Empty).ToLower() == "economy_incident"
                    || (x.TargetType ?? string.Empty).ToLower() == "subscription"
                    || (x.TargetType ?? string.Empty).ToLower() == "subscription_plan"
                    || (x.TargetType ?? string.Empty).ToLower() == "payment_provider_configuration"
                    || (x.TargetType ?? string.Empty).ToLower() == "currency_pack"
                    || (x.TargetType ?? string.Empty).ToLower() == "redeem_code"
                    || x.Action.ToLower().StartsWith("admin.templates.")
                    || x.Action.ToLower().StartsWith("admin.template_")
                    || x.Action.ToLower().StartsWith("admin.content.")
                    || x.Action.ToLower().StartsWith("admin.feedback.")
                    || (x.TargetType ?? string.Empty).ToLower() == "template"
                    || (x.TargetType ?? string.Empty).ToLower() == "templategenerationjob"
                    || (x.TargetType ?? string.Empty).ToLower() == "template_generation"
                    || (x.TargetType ?? string.Empty).ToLower() == "feedback"
                    || (x.TargetType ?? string.Empty).ToLower() == "template_analytics_event"
                    || (x.TargetType ?? string.Empty).ToLower() == "template_of_the_day"
                    || (x.TargetType ?? string.Empty).ToLower() == "template_of_the_day_settings"
                    || x.Action.ToLower().StartsWith("auth.")
                    || x.Action.ToLower().StartsWith("user.")
                    || x.Action.ToLower().StartsWith("admin.user.")
                    || x.Action.ToLower().StartsWith("admin.bulk_email.")
                    || (x.TargetType ?? string.Empty).ToLower() == "user"
                    || (x.TargetType ?? string.Empty).ToLower() == "email-broadcast")),
            _ => query,
        };
    }

    private static bool IsEconomyAction(string action)
    {
        var normalized = action.ToLowerInvariant();
        return normalized.StartsWith("admin.payment.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.economy.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.subscription.", StringComparison.Ordinal)
            || normalized.Contains(".wallet.", StringComparison.Ordinal);
    }

    private static bool IsEconomyTargetType(string? targetType)
    {
        return targetType is not null && EconomyTargetTypes.Contains(targetType);
    }

    private static bool IsContentAction(string action)
    {
        var normalized = action.ToLowerInvariant();
        return normalized.StartsWith("admin.templates.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.template_", StringComparison.Ordinal)
            || normalized.StartsWith("admin.content.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.feedback.", StringComparison.Ordinal);
    }

    private static bool IsContentTargetType(string? targetType)
    {
        return targetType is not null && ContentTargetTypes.Contains(targetType);
    }

    private static bool IsIdentityAction(string action)
    {
        var normalized = action.ToLowerInvariant();
        return normalized.StartsWith("auth.", StringComparison.Ordinal)
            || normalized.StartsWith("user.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.user.", StringComparison.Ordinal)
            || normalized.StartsWith("admin.bulk_email.", StringComparison.Ordinal);
    }

    private static string ResolveCategory(string action, string? targetType)
    {
        var normalizedAction = action.ToLowerInvariant();
        var normalizedTargetType = targetType?.ToLowerInvariant();
        if (normalizedAction.StartsWith("admin.support.", StringComparison.Ordinal)
            || normalizedTargetType == "supportconversation")
        {
            return AdminAuditCategories.Support;
        }

        if (normalizedAction.StartsWith("admin.gamification.", StringComparison.Ordinal)
            || normalizedTargetType == "dailystreak")
        {
            return AdminAuditCategories.Gamification;
        }

        if (IsEconomyAction(action) || IsEconomyTargetType(targetType))
        {
            return AdminAuditCategories.Economy;
        }

        if (IsContentAction(action) || IsContentTargetType(targetType))
        {
            return AdminAuditCategories.Content;
        }

        if (IsIdentityAction(action)
            || normalizedTargetType is "user" or "email-broadcast")
        {
            return AdminAuditCategories.Identity;
        }

        return AdminAuditCategories.System;
    }

    private static string? NormalizeOptional(string? value)
    {
        var normalized = value?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }

    private static DateTime NormalizeUtc(DateTime value)
    {
        return value.Kind switch
        {
            DateTimeKind.Utc => value,
            DateTimeKind.Local => value.ToUniversalTime(),
            _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
        };
    }

    private static string SanitizeRequired(string? value, int maxLength)
    {
        return SafeLogValues.SanitizeText(value, maxLength);
    }

    private static string? SanitizeOptional(string? value, int maxLength)
    {
        var sanitized = SafeLogValues.SanitizeText(value, maxLength);
        return sanitized.Length > 0 ? sanitized : null;
    }

    private sealed record AuditEventListRow(
        Guid AuditEventId,
        string Action,
        Guid? ActorUserId,
        string? ActorRole,
        Guid? SubjectUserId,
        string? TargetType,
        string? TargetId,
        string? CorrelationId,
        DateTime OccurredAtUtc);

    private sealed record AuditIdentityRow(Guid UserId, string? DisplayName, string? Email);
}
