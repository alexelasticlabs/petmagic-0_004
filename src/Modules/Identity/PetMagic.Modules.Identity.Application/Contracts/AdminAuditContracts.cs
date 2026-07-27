using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Identity.Application.Contracts;

public static class AdminAuditCategories
{
    public const string Identity = "identity";
    public const string Economy = "economy";
    public const string Content = "content";
    public const string Support = "support";
    public const string Gamification = "gamification";
    public const string System = "system";

    public static readonly IReadOnlySet<string> All = new HashSet<string>(StringComparer.Ordinal)
    {
        Identity,
        Economy,
        Content,
        Support,
        Gamification,
        System,
    };
}

public sealed record AdminAuditEventsQuery(
    int? Skip,
    int? Take,
    string? Search,
    string? Category,
    Guid? ActorUserId,
    Guid? SubjectUserId,
    DateTime? FromUtc,
    DateTime? ToUtc);

public sealed record AdminAuditEventListItemResponse(
    Guid AuditEventId,
    string Action,
    string Category,
    Guid? ActorUserId,
    string? ActorDisplayName,
    string? ActorEmail,
    string? ActorRole,
    Guid? SubjectUserId,
    string? SubjectDisplayName,
    string? SubjectEmail,
    string? TargetType,
    string? TargetId,
    string? CorrelationId,
    DateTime OccurredAtUtc);

public sealed record AdminAuditEventsSummaryResponse(
    int TotalEvents,
    int UniqueActors,
    int AccessEvents,
    int SystemEvents);

public sealed record AdminAuditEventsPageResponse(
    IReadOnlyList<AdminAuditEventListItemResponse> Items,
    int Skip,
    int Take,
    int TotalCount,
    bool HasMore,
    AdminAuditEventsSummaryResponse Summary);

public sealed record AdminAuditEventDetailResponse(
    Guid AuditEventId,
    string Action,
    string Category,
    Guid? ActorUserId,
    string? ActorDisplayName,
    string? ActorEmail,
    string? ActorRole,
    Guid? SubjectUserId,
    string? SubjectDisplayName,
    string? SubjectEmail,
    string? TargetType,
    string? TargetId,
    string? CorrelationId,
    DateTime OccurredAtUtc,
    string? OldValue,
    string? NewValue,
    string Details,
    string? IpAddress,
    string? UserAgent,
    DateTime CreatedAtUtc);

public static class AdminAuditErrors
{
    public static readonly Error SearchTooLong = new(
        "audit.search_too_long",
        "Audit search must not exceed 120 characters.");

    public static readonly Error CategoryInvalid = new(
        "audit.category_invalid",
        "Audit category is invalid.");

    public static readonly Error DateRangeInvalid = new(
        "audit.date_range_invalid",
        "Audit date range must be ordered and must not exceed 90 days.");

    public static readonly Error EventNotFound = new(
        "audit.event_not_found",
        "Audit event was not found.");
}
