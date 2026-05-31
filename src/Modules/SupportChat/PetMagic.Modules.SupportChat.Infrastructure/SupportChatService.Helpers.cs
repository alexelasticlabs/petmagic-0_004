using System.Text.Json;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private static IReadOnlyList<SupportMessageAttachmentInput> BuildLegacyAttachmentInputs(SendSupportMessageCommand command)
    {
        if (string.IsNullOrWhiteSpace(command.AttachmentUrl)
            || string.IsNullOrWhiteSpace(command.AttachmentFileName)
            || string.IsNullOrWhiteSpace(command.AttachmentContentType)
            || command.AttachmentFileSizeBytes is null or <= 0)
        {
            return [];
        }

        return
        [
            new SupportMessageAttachmentInput(
                command.AttachmentUrl,
                command.AttachmentContentType,
                command.AttachmentFileName,
                command.AttachmentFileSizeBytes.Value)
        ];
    }

    private static IReadOnlyList<SupportMessageAttachmentInput> NormalizeAttachmentInputs(
        IReadOnlyList<SupportMessageAttachmentInput>? attachments)
    {
        if (attachments is null || attachments.Count == 0)
        {
            return [];
        }

        return attachments
            .Where(attachment =>
                !string.IsNullOrWhiteSpace(attachment.FileUrl)
                && !string.IsNullOrWhiteSpace(attachment.FileName)
                && !string.IsNullOrWhiteSpace(attachment.MimeType)
                && attachment.SizeBytes > 0)
            .ToList();
    }

    private string? ResolveStorageKey(string fileUrl, string? explicitStorageKey)
    {
        if (!string.IsNullOrWhiteSpace(explicitStorageKey))
        {
            return explicitStorageKey.Trim();
        }

        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return null;
        }

        var baseUrl = attachmentStorageOptions.PublicBaseUrl.TrimEnd('/');
        if (!fileUrl.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = fileUrl[baseUrl.Length..].TrimStart('/');
        return string.IsNullOrWhiteSpace(relativePath)
            ? null
            : relativePath.Replace('\\', '/');
    }

    private static IReadOnlyList<SupportMessageAttachmentResponse> BuildAttachmentResponses(ConversationMessage message)
    {
        if (message.Attachments.Count > 0)
        {
            return message.Attachments
                .OrderBy(attachment => attachment.SortOrder)
                .Select(attachment => new SupportMessageAttachmentResponse(
                    attachment.IsDeleted ? string.Empty : attachment.FileUrl,
                    ResolveAttachmentType(attachment.MimeType),
                    attachment.MimeType,
                    attachment.FileName,
                    attachment.SizeBytes,
                    attachment.DurationSeconds,
                    attachment.Width,
                    attachment.Height,
                    attachment.IsDeleted,
                    attachment.ExpiresAtUtc,
                    attachment.DeletedAtUtc))
                .ToList();
        }

        if (string.IsNullOrWhiteSpace(message.AttachmentUrl)
            || string.IsNullOrWhiteSpace(message.AttachmentFileName)
            || string.IsNullOrWhiteSpace(message.AttachmentContentType)
            || message.AttachmentFileSizeBytes is null or <= 0)
        {
            return [];
        }

        return
        [
            new SupportMessageAttachmentResponse(
                message.AttachmentUrl,
                ResolveAttachmentType(message.AttachmentContentType),
                message.AttachmentContentType,
                message.AttachmentFileName,
                message.AttachmentFileSizeBytes.Value,
                DurationSeconds: null,
                Width: null,
                Height: null,
                IsDeleted: false,
                ExpiresAtUtc: null,
                DeletedAtUtc: null)
        ];
    }

    private static string ResolveAttachmentType(string mimeType)
    {
        if (mimeType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return "image";
        }

        if (mimeType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            return "video";
        }

        return "file";
    }

    private static string BuildMessagePreview(
        string trimmedBody,
        IReadOnlyList<SupportMessageAttachmentInput> attachments)
    {
        if (!string.IsNullOrWhiteSpace(trimmedBody))
        {
            return trimmedBody;
        }

        if (attachments.Count == 0)
        {
            return string.Empty;
        }

        if (attachments.Count == 1)
        {
            return attachments[0].FileName;
        }

        return $"{attachments.Count} attachments";
    }

    private static SupportAttachmentUploadStatus? ParseAttachmentUploadStatus(int? rawValue)
    {
        if (!rawValue.HasValue)
        {
            return null;
        }

        return Enum.IsDefined(typeof(SupportAttachmentUploadStatus), rawValue.Value)
            ? (SupportAttachmentUploadStatus)rawValue.Value
            : null;
    }

    private static Error? ValidateConversationCanAcceptMessage(SupportConversation conversation, bool isAdmin, DateTime now)
    {
        var normalizedStatus = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId);
        if (normalizedStatus == SupportConversationStatus.Closed)
        {
            return isAdmin ? SupportChatErrors.ConversationReadOnly : null;
        }
        return null;
    }

    private static bool ShouldReactivateConversationForUserMessage(SupportConversation conversation, DateTime now)
    {
        return ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
    }

    private static void MarkResolved(SupportConversation conversation, DateTime now)
    {
        MarkClosed(conversation, now, closedByUserId: null);
    }

    private static void MarkClosed(SupportConversation conversation, DateTime now, Guid? closedByUserId)
    {
        conversation.Status = SupportConversationStatus.Closed;
        conversation.ResolvedAtUtc ??= now;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = now;
        conversation.ClosedByUserId = closedByUserId;
        conversation.WaitingSinceUtc = null;
        conversation.UpdatedAtUtc = now;
    }

    private static void MarkActive(SupportConversation conversation, SupportConversationStatus status, DateTime now, Guid? reopenedByUserId = null)
    {
        var wasClosed = ToCanonicalStatus(conversation.Status, conversation.AssignedAdminId) == SupportConversationStatus.Closed;
        conversation.Status = status;
        conversation.ResolvedAtUtc = null;
        conversation.ReopenUntilUtc = null;
        conversation.ClosedAtUtc = null;
        conversation.ClosedByUserId = null;
        if (wasClosed || reopenedByUserId.HasValue)
        {
            conversation.ReopenedAtUtc = now;
            conversation.ReopenedByUserId = reopenedByUserId;
        }

        conversation.WaitingSinceUtc = ResolveWaitingSince(status, conversation.LastMessageAtUtc, conversation.CreatedAtUtc);
        conversation.UpdatedAtUtc = now;
    }

    private Task AppendStatusChangedEventAsync(
        SupportConversation conversation,
        SupportConversationStatus currentStatus,
        SupportConversationStatus nextStatus)
    {
        return AppendSystemEventAsync(conversation, $"Status changed: {currentStatus} -> {nextStatus}");
    }

    private static DateTime? ResolveWaitingSince(
        SupportConversationStatus status,
        DateTime? lastMessageAtUtc,
        DateTime createdAtUtc)
    {
        return status switch
        {
            SupportConversationStatus.New or SupportConversationStatus.InProgress => lastMessageAtUtc ?? createdAtUtc,
            _ => null
        };
    }

    private static int CalculateWaitingMinutes(DateTime? waitingSinceUtc, DateTime now)
    {
        if (!waitingSinceUtc.HasValue)
        {
            return 0;
        }

        return Math.Max(0, (int)Math.Floor((now - waitingSinceUtc.Value).TotalMinutes));
    }

    private static IReadOnlyList<string> ResolveAvailableActions(SupportConversationStatus status, bool hasAssignment)
    {
        return status switch
        {
            SupportConversationStatus.New => ["close"],
            SupportConversationStatus.InProgress => hasAssignment
                ? ["mark-waiting-for-user", "close", "unassign"]
                : ["mark-waiting-for-user", "close"],
            SupportConversationStatus.WaitingForUser => ["mark-in-progress", "close"],
            SupportConversationStatus.Closed => ["reopen"],
            _ => []
        };
    }

    private static DateTime? ResolveReopenUntil(SupportConversation conversation)
    {
        return ResolveReopenUntil(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc);
    }

    private static DateTime? ResolveReopenUntil(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc)
    {
        return null;
    }

    private static bool CanReopenConversation(SupportConversation conversation, DateTime now)
    {
        return CanReopenConversation(conversation.Status, conversation.ResolvedAtUtc, conversation.ReopenUntilUtc, now);
    }

    private static bool CanReopenConversation(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static bool IsConversationReadOnly(SupportConversation conversation, DateTime now)
    {
        return IsConversationReadOnly(
            conversation.Status,
            conversation.ResolvedAtUtc,
            conversation.ReopenUntilUtc,
            conversation.ClosedAtUtc,
            now);
    }

    private static bool IsConversationReadOnly(
        SupportConversationStatus status,
        DateTime? resolvedAtUtc,
        DateTime? reopenUntilUtc,
        DateTime? closedAtUtc,
        DateTime now)
    {
        return ToCanonicalStatus(status) == SupportConversationStatus.Closed;
    }

    private static SupportConversationStatus ToCanonicalStatus(
        SupportConversationStatus status,
        Guid? assignedAdminId = null)
    {
        return (int)status switch
        {
            LegacyResolvedStatusValue => SupportConversationStatus.Closed,
            LegacyWaitingForSupportStatusValue => assignedAdminId.HasValue
                ? SupportConversationStatus.InProgress
                : SupportConversationStatus.New,
            (int)SupportConversationStatus.New => SupportConversationStatus.New,
            (int)SupportConversationStatus.InProgress => SupportConversationStatus.InProgress,
            (int)SupportConversationStatus.Closed => SupportConversationStatus.Closed,
            (int)SupportConversationStatus.WaitingForUser => SupportConversationStatus.WaitingForUser,
            _ => SupportConversationStatus.New
        };
    }

    private static SupportConversationSource ToCanonicalSource(SupportConversationSource source)
    {
        return (int)source switch
        {
            LegacyDirectSourceValue => SupportConversationSource.MobileChat,
            (int)SupportConversationSource.MobileAssistant => SupportConversationSource.MobileAssistant,
            (int)SupportConversationSource.MobileChat => SupportConversationSource.MobileChat,
            (int)SupportConversationSource.AdminCreated => SupportConversationSource.AdminCreated,
            (int)SupportConversationSource.System => SupportConversationSource.System,
            _ => SupportConversationSource.MobileChat
        };
    }

    private static string ResolveSenderDisplayType(SupportMessageSenderType senderType, bool isFromAdmin) =>
        senderType.ToString();

    private static string ResolveMessageSenderDisplayName(
        SupportMessageSenderType senderType,
        string? email,
        string? displayName,
        bool isFromAdmin) => senderType switch
        {
            SupportMessageSenderType.System => "System",
            SupportMessageSenderType.Bot => "PetMagic Support",
            _ => ResolveDisplayName(email, displayName, isFromAdmin),
        };

    private static string ResolveDisplayName(string? email, string? displayName, bool isAdminSender = false)
    {
        if (!string.IsNullOrWhiteSpace(displayName))
        {
            return displayName;
        }

        if (!string.IsNullOrWhiteSpace(email))
        {
            return email;
        }

        return isAdminSender ? "PetMagic Support" : "PetMagic User";
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length <= maxLength)
        {
            return value;
        }

        return string.Concat(value.AsSpan(0, maxLength), "...");
    }

    private static IReadOnlyList<string> ParseTags(string? tagsJson)
    {
        if (string.IsNullOrWhiteSpace(tagsJson))
        {
            return [];
        }

        try
        {
            var parsed = JsonSerializer.Deserialize<string[]>(tagsJson);
            if (parsed is null || parsed.Length == 0)
            {
                return [];
            }

            return parsed
                .Select(tag => tag?.Trim())
                .Where(tag => !string.IsNullOrWhiteSpace(tag))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(12)
                .ToList()!;
        }
        catch
        {
            return [];
        }
    }

    private static List<string>? NormalizeTags(IReadOnlyList<string>? tags)
    {
        if (tags is null)
        {
            return [];
        }

        if (tags.Count > 12)
        {
            return null;
        }

        var normalized = tags
            .Select(tag => tag.Trim())
            .Where(tag => !string.IsNullOrWhiteSpace(tag))
            .Select(tag => tag.Length <= 40 ? tag : tag[..40])
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();

        return normalized.Count > 12 ? null : normalized;
    }

    private static string SerializeTags(IReadOnlyList<string> tags)
    {
        return JsonSerializer.Serialize(tags);
    }
}

