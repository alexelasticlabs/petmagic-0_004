using System.Text.Json;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Identity.Application.Contracts;

public sealed record AdminNotificationsQuery(
    string? Cursor,
    int? Take,
    string? State,
    string? Category,
    string? Priority);

public sealed record AdminNotificationItemResponse(
    Guid NotificationId,
    string Type,
    int SchemaVersion,
    JsonElement Payload,
    string Category,
    string Priority,
    string? Href,
    string Source,
    DateTime CreatedAtUtc,
    DateTime? ExpiresAtUtc,
    DateTime? ReadAtUtc,
    DateTime? ArchivedAtUtc,
    AdminNotificationAcknowledgementResponse? Acknowledgement,
    int Version);

public sealed record AdminNotificationAcknowledgementResponse(
    Guid ActorUserId,
    DateTime AcknowledgedAtUtc,
    string Reason);

public sealed record AdminNotificationsPageResponse(
    IReadOnlyList<AdminNotificationItemResponse> Items,
    string? NextCursor,
    int UnreadCount,
    int CriticalUnacknowledgedCount,
    DateTime AsOfUtc);

public sealed record AdminNotificationReadAllCommand(DateTime CutoffUtc);

public sealed record AdminNotificationAcknowledgeCommand(string Reason);

public enum AdminNotificationAcknowledgeStatus
{
    Acknowledged,
    IdempotentReplay,
    Conflict,
    NotFound,
    Invalid,
}

public sealed record AdminNotificationAcknowledgeResult(
    AdminNotificationAcknowledgeStatus Status,
    AdminNotificationItemResponse? Notification,
    Error Error);

public static class AdminNotificationErrors
{
    public static readonly Error CursorInvalid = new(
        "admin_notifications.cursor_invalid",
        "The notification cursor is invalid.");

    public static readonly Error FilterInvalid = new(
        "admin_notifications.filter_invalid",
        "The notification filter is invalid.");

    public static readonly Error NotificationNotFound = new(
        "admin_notifications.not_found",
        "The notification was not found.");

    public static readonly Error AcknowledgementNotCritical = new(
        "admin_notifications.acknowledgement_not_critical",
        "Only critical notifications can be acknowledged.");

    public static readonly Error AcknowledgementReasonInvalid = new(
        "admin_notifications.acknowledgement_reason_invalid",
        "The acknowledgement reason must contain between 3 and 500 characters.");

    public static readonly Error VersionInvalid = new(
        "admin_notifications.version_invalid",
        "If-Match must contain the current notification version.");

    public static readonly Error AcknowledgementConflict = new(
        "admin_notifications.acknowledgement_conflict",
        "The notification was acknowledged by another operator.");
}
