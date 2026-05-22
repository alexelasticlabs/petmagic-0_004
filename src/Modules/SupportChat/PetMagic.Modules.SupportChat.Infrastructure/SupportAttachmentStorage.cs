using Microsoft.Extensions.Hosting;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportAttachmentStorageOptions
{
    public string PublicBaseUrl { get; init; } = "http://localhost:5000";

    public string LocalMediaRootPath { get; init; } = Path.Combine("wwwroot", "support-attachments");

    public long MaxFileSizeBytes { get; init; } = 8 * 1024 * 1024;
}

internal sealed class LocalSupportAttachmentStorage(
    SupportAttachmentStorageOptions options,
    IHostEnvironment hostEnvironment) : ISupportAttachmentStorage
{
    private static readonly Dictionary<string, string> ImageSubtypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["jpeg"] = ".jpg",
        ["jpg"] = ".jpg",
        ["png"] = ".png",
        ["webp"] = ".webp",
        ["gif"] = ".gif",
        ["heic"] = ".heic",
        ["heif"] = ".heif"
    };

    private static readonly Dictionary<string, string> ExactContentTypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["application/pdf"] = ".pdf",
        ["application/json"] = ".json",
        ["application/zip"] = ".zip",
        ["application/x-zip-compressed"] = ".zip",
        ["text/plain"] = ".txt",
        ["text/csv"] = ".csv",
        ["application/msword"] = ".doc",
        ["application/vnd.ms-excel"] = ".xls",
        ["application/vnd.ms-powerpoint"] = ".ppt",
        ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"] = ".docx",
        ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"] = ".xlsx",
        ["application/vnd.openxmlformats-officedocument.presentationml.presentation"] = ".pptx"
    };

    private static readonly Dictionary<string, string> ExtensionContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
        [".gif"] = "image/gif",
        [".heic"] = "image/heic",
        [".heif"] = "image/heif",
        [".pdf"] = "application/pdf",
        [".json"] = "application/json",
        [".zip"] = "application/zip",
        [".txt"] = "text/plain",
        [".csv"] = "text/csv",
        [".doc"] = "application/msword",
        [".docx"] = "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        [".xls"] = "application/vnd.ms-excel",
        [".xlsx"] = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        [".ppt"] = "application/vnd.ms-powerpoint",
        [".pptx"] = "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    };

    public async Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
        SupportAttachmentUploadCommand attachment,
        CancellationToken cancellationToken)
    {
        if (attachment.Content.Length == 0)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        if (!TryResolveStoredFileFormat(attachment.ContentType, attachment.FileName, out var extension, out var normalizedContentType))
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentContentTypeNotAllowed);
        }

        if (attachment.Content.LongLength > options.MaxFileSizeBytes)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentFileTooLarge);
        }

        var root = ResolveRootPath();
        Directory.CreateDirectory(root);

        var safeName = $"{Guid.NewGuid():N}{extension}";
        var now = DateTime.UtcNow;
        var year = now.ToString("yyyy");
        var month = now.ToString("MM");
        var relativePath = Path.Combine("support-attachments", year, month, safeName);
        var physicalPath = Path.Combine(root, year, month, safeName);

        Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);

        try
        {
            await File.WriteAllBytesAsync(physicalPath, attachment.Content, cancellationToken);
        }
        catch
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentStorageFailed);
        }

        var normalizedRelativePath = relativePath.Replace("\\", "/");
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        var url = $"{baseUrl}/{normalizedRelativePath}";

        return Result.Success(new StoredSupportAttachmentResponse(
            url,
            normalizedRelativePath,
            attachment.FileName,
            normalizedContentType,
            attachment.Content.LongLength,
            physicalPath));
    }

    public Task<Result> DeleteAsync(string? attachmentUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(attachmentUrl))
        {
            return Task.FromResult(Result.Success());
        }

        var root = ResolveRootPath();
        var relativePath = TryResolveManagedRelativePath(attachmentUrl);
        if (relativePath is null)
        {
            return Task.FromResult(Result.Success());
        }

        try
        {
            var relativeSegments = relativePath
                .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            if (relativeSegments.Length <= 1)
            {
                return Task.FromResult(Result.Success());
            }

            var storageRelativePath = Path.Combine(relativeSegments[1..]);
            var physicalPath = Path.GetFullPath(Path.Combine(root, storageRelativePath));
            var rootWithSeparator = root.EndsWith(Path.DirectorySeparatorChar)
                ? root
                : root + Path.DirectorySeparatorChar;

            if (!physicalPath.StartsWith(rootWithSeparator, StringComparison.OrdinalIgnoreCase)
                && !string.Equals(physicalPath, root, StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(Result.Success());
            }

            if (File.Exists(physicalPath))
            {
                File.Delete(physicalPath);
            }

            return Task.FromResult(Result.Success());
        }
        catch
        {
            return Task.FromResult(Result.Failure(SupportChatErrors.AttachmentStorageFailed));
        }
    }

    private string ResolveRootPath()
    {
        var root = Path.IsPathRooted(options.LocalMediaRootPath)
            ? options.LocalMediaRootPath
            : Path.Combine(hostEnvironment.ContentRootPath, options.LocalMediaRootPath);

        return Path.GetFullPath(root);
    }

    private string? TryResolveManagedRelativePath(string attachmentUrl)
    {
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!attachmentUrl.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = attachmentUrl[baseUrl.Length..].TrimStart('/');
        if (!relativePath.StartsWith("support-attachments/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return relativePath.Replace('\\', '/');
    }

    private static bool TryResolveStoredFileFormat(
        string contentType,
        string fileName,
        out string extension,
        out string normalizedContentType)
    {
        extension = string.Empty;
        normalizedContentType = NormalizeContentType(contentType);
        if (string.IsNullOrWhiteSpace(normalizedContentType))
        {
            return false;
        }

        if (normalizedContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            var subtype = normalizedContentType["image/".Length..];
            if (!ImageSubtypeExtensions.TryGetValue(subtype, out string? mappedImageExtension)
                || string.IsNullOrWhiteSpace(mappedImageExtension))
            {
                return false;
            }

            extension = mappedImageExtension;
            normalizedContentType = string.Equals(subtype, "jpg", StringComparison.OrdinalIgnoreCase)
                ? "image/jpeg"
                : $"image/{subtype}";
            return true;
        }

        if (ExactContentTypeExtensions.TryGetValue(normalizedContentType, out string? mappedExactExtension)
            && !string.IsNullOrWhiteSpace(mappedExactExtension))
        {
            extension = mappedExactExtension;
            return true;
        }

        if (!string.Equals(normalizedContentType, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var fileExtension = Path.GetExtension(fileName).Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(fileExtension)
            || !ExtensionContentTypes.TryGetValue(fileExtension, out string? extensionContentType)
            || string.IsNullOrWhiteSpace(extensionContentType))
        {
            return false;
        }

        extension = fileExtension;
        normalizedContentType = extensionContentType;
        return true;
    }

    private static string NormalizeContentType(string contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return string.Empty;
        }

        var separatorIndex = contentType.IndexOf(';');
        var normalized = separatorIndex >= 0
            ? contentType[..separatorIndex]
            : contentType;

        return normalized.Trim();
    }
}
