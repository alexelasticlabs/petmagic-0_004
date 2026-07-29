using System.Text.Json;

namespace PetMagic.BuildingBlocks.Notifications;

public static class AdminNotificationPriorities
{
    public const string Normal = "normal";
    public const string Warning = "warning";
    public const string Critical = "critical";
}

public sealed record AdminNotificationMessage(
    string Type,
    int SchemaVersion,
    JsonElement Payload,
    string Category,
    string Priority,
    IReadOnlyCollection<string> AudienceRoles,
    string Source,
    string DeduplicationKey,
    string? Href = null,
    Guid? TargetUserId = null,
    DateTime? OccurredAtUtc = null,
    DateTime? ExpiresAtUtc = null);

public interface IAdminNotificationSink
{
    Task PublishAsync(AdminNotificationMessage message, CancellationToken cancellationToken);
}

public static class AdminNotificationOutbox
{
    public const string Kind = "admin_notification";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public static string Serialize(AdminNotificationMessage message) =>
        JsonSerializer.Serialize(message, JsonOptions);

    public static AdminNotificationMessage Deserialize(string payloadJson) =>
        JsonSerializer.Deserialize<AdminNotificationMessage>(payloadJson, JsonOptions)
        ?? throw new JsonException("Admin notification outbox payload is empty.");
}
