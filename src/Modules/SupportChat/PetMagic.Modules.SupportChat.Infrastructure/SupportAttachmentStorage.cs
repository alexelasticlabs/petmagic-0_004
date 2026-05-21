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
    public async Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
        SupportAttachmentUploadCommand attachment,
        CancellationToken cancellationToken)
    {
        if (attachment.Content.Length == 0)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        if (!IsAllowedContentType(attachment.ContentType))
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentContentTypeNotAllowed);
        }

        if (attachment.Content.LongLength > options.MaxFileSizeBytes)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentFileTooLarge);
        }

        var root = ResolveRootPath();
        Directory.CreateDirectory(root);

        var extension = Path.GetExtension(attachment.FileName);
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
            attachment.ContentType,
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

    private static bool IsAllowedContentType(string contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return false;
        }

        if (contentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return contentType.Equals("application/octet-stream", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/pdf", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/json", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/zip", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/x-zip-compressed", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("text/plain", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("text/csv", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/msword", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/vnd.ms-excel", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/vnd.ms-powerpoint", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/vnd.openxmlformats-officedocument.wordprocessingml.document", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", StringComparison.OrdinalIgnoreCase)
            || contentType.Equals("application/vnd.openxmlformats-officedocument.presentationml.presentation", StringComparison.OrdinalIgnoreCase);
    }
}
