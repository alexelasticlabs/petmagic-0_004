using PetMagic.BuildingBlocks.Storage;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Contracts;
using PetMagic.Modules.SupportChat.Domain.Enums;
using PetMagic.Modules.SupportChat.Infrastructure.Entities;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
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
            return TryNormalizeManagedAttachmentPath(explicitStorageKey, out var managedStorageKey)
                ? managedStorageKey
                : null;
        }

        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return null;
        }

        var trimmed = fileUrl.Trim();
        var baseUrl = attachmentStorageOptions.PublicBaseUrl.TrimEnd('/');
        if (!trimmed.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase)
            || trimmed.Length <= baseUrl.Length
            || trimmed[baseUrl.Length] != '/')
        {
            return null;
        }

        var relativePath = trimmed[baseUrl.Length..].TrimStart('/').Replace('\\', '/');
        return TryNormalizeManagedAttachmentPath(relativePath, out var storageKey)
            ? storageKey
            : null;
    }

    private IReadOnlyList<SupportMessageAttachmentResponse> BuildAttachmentResponses(ConversationMessage message)
    {
        if (message.Attachments.Count > 0)
        {
            return message.Attachments
                .OrderBy(attachment => attachment.SortOrder)
                .Select(attachment =>
                {
                    if (attachment.IsDeleted)
                    {
                        return new SupportMessageAttachmentResponse(
                            string.Empty,
                            "file",
                            string.Empty,
                            "attachment",
                            0,
                            DurationSeconds: null,
                            Width: null,
                            Height: null,
                            IsDeleted: true,
                            ExpiresAtUtc: null,
                            attachment.DeletedAtUtc);
                    }

                    var mimeType = attachment.MimeType?.Trim() ?? string.Empty;
                    var fileName = attachment.FileName?.Trim();
                    return new SupportMessageAttachmentResponse(
                        ResolveManagedAttachmentUrl(attachment.FileUrl, attachment.StorageKey),
                        ResolveAttachmentType(mimeType),
                        mimeType,
                        string.IsNullOrWhiteSpace(fileName) ? "attachment" : fileName,
                        attachment.SizeBytes,
                        attachment.DurationSeconds,
                        attachment.Width,
                        attachment.Height,
                        IsDeleted: false,
                        attachment.ExpiresAtUtc,
                        attachment.DeletedAtUtc);
                })
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
                ResolveManagedAttachmentUrl(message.AttachmentUrl, explicitStorageKey: null),
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

    private string ResolveManagedAttachmentUrl(string? fileUrl, string? explicitStorageKey)
    {
        if (string.IsNullOrWhiteSpace(fileUrl))
        {
            return string.Empty;
        }

        if (ResolveStorageKey(fileUrl, explicitStorageKey) is null)
        {
            return string.Empty;
        }

        var readUrl = attachmentReadUrlSigner.CreateReadUrl(fileUrl);
        return string.IsNullOrWhiteSpace(readUrl)
            ? string.Empty
            : readUrl;
    }

    private static bool TryNormalizeManagedAttachmentPath(string candidate, out string managedPath)
    {
        managedPath = string.Empty;
        var pathOnly = candidate.Trim().Replace('\\', '/').TrimStart('/');
        var queryIndex = pathOnly.IndexOfAny(['?', '#']);
        if (queryIndex >= 0)
        {
            pathOnly = pathOnly[..queryIndex];
        }

        if (string.IsNullOrWhiteSpace(pathOnly)
            || pathOnly.EndsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var segments = pathOnly
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Length <= 1
            || !string.Equals(segments[0], "support-attachments", StringComparison.OrdinalIgnoreCase)
            || segments.Any(IsUnsafeAttachmentPathSegment))
        {
            return false;
        }

        managedPath = string.Join('/', segments);
        return true;
    }

    private static bool IsUnsafeAttachmentPathSegment(string segment)
    {
        return ManagedPathSegments.IsUnsafe(segment);
    }

    private static SupportMessagePendingAttachmentResponse? BuildPendingAttachmentResponse(
        ConversationMessage message,
        IReadOnlyList<SupportMessageAttachmentResponse> attachments)
    {
        if (attachments.Count > 0
            || string.IsNullOrWhiteSpace(message.AttachmentFileName)
            || string.IsNullOrWhiteSpace(message.AttachmentContentType))
        {
            return null;
        }

        return new SupportMessagePendingAttachmentResponse(
            message.AttachmentFileName,
            message.AttachmentContentType,
            message.AttachmentFileSizeBytes);
    }

    private static string ResolveAttachmentType(string? mimeType)
    {
        if (string.IsNullOrWhiteSpace(mimeType))
        {
            return "file";
        }

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
}
