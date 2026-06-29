using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Images;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.SupportChat.Application.Abstractions;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed class SupportAttachmentStorageOptions
{
    public string PublicBaseUrl { get; init; } = "http://localhost:5000";

    public string LocalMediaRootPath { get; init; } = Path.Combine("wwwroot", "support-attachments");

    public long MaxImageFileSizeBytes { get; init; } = UploadedMediaPolicies.SupportImage.MaxFileSizeBytes;

    public long MaxVideoFileSizeBytes { get; init; } = UploadedMediaPolicies.SupportVideoMaxFileSizeBytes;

    public int RetentionDays { get; init; } = 30;

    public bool CleanupWorkerEnabled { get; init; } = true;

    public int CleanupPollIntervalMilliseconds { get; init; } = 86_400_000;

    public int CleanupBatchSize { get; init; } = 100;

    public int CleanupRetryDelayMilliseconds { get; init; } = 30_000;
}

internal sealed class LocalSupportAttachmentStorage(
    SupportAttachmentStorageOptions options,
    IHostEnvironment hostEnvironment,
    ILogger<LocalSupportAttachmentStorage> logger) : ISupportAttachmentStorage
{
    private static readonly Dictionary<string, string> AllowedContentTypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["image/jpeg"] = ".jpg",
        ["image/jpg"] = ".jpg",
        ["image/png"] = ".png",
        ["image/webp"] = ".webp",
        ["video/mp4"] = ".mp4",
        ["video/quicktime"] = ".mov"
    };

    private static readonly Dictionary<string, string> ExtensionContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
        [".mp4"] = "video/mp4",
        [".m4v"] = "video/mp4",
        [".mov"] = "video/quicktime",
        [".qt"] = "video/quicktime"
    };

    public async Task<Result<StoredSupportAttachmentResponse>> StoreAsync(
        SupportAttachmentUploadCommand attachment,
        CancellationToken cancellationToken)
    {
        var contentLength = attachment.Content?.LongLength ?? attachment.ContentLengthBytes ?? 0;
        if (contentLength <= 0)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        var headerBytes = new byte[32];
        int headerLength;

        if (attachment.Content is not null)
        {
            headerLength = Math.Min(headerBytes.Length, attachment.Content.Length);
            Array.Copy(attachment.Content, headerBytes, headerLength);
        }
        else if (attachment.ContentStream is not null)
        {
            if (attachment.ContentStream.CanSeek)
            {
                attachment.ContentStream.Position = 0;
            }

            headerLength = await attachment.ContentStream.ReadAsync(headerBytes.AsMemory(0, headerBytes.Length), cancellationToken);
            if (attachment.ContentStream.CanSeek)
            {
                attachment.ContentStream.Position = 0;
            }
        }
        else
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
        }

        var signatureBytes = headerBytes.AsSpan(0, headerLength).ToArray();
        if (!TryResolveStoredFileFormat(attachment.ContentType, attachment.FileName, signatureBytes, out var extension, out var normalizedContentType, out var signatureMismatch))
        {
            if (signatureMismatch)
            {
                return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentMimeMismatch);
            }

            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentContentTypeNotAllowed);
        }

        var maxFileSizeBytes = ResolveMaxFileSizeBytes(normalizedContentType);
        if (contentLength > maxFileSizeBytes)
        {
            return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.AttachmentFileTooLarge);
        }

        byte[]? normalizedAttachmentBytes = null;
        if (normalizedContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            var attachmentBytes = attachment.Content;
            if (attachmentBytes is null)
            {
                attachmentBytes = await ReadAllBytesAsync(attachment.ContentStream, cancellationToken);
                if (attachmentBytes is null)
                {
                    return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
                }
            }

            var normalizedImage = UploadedImageNormalizer.NormalizeOrKeep(
                attachmentBytes,
                normalizedContentType,
                UploadedImageProfile.SupportImage);
            normalizedAttachmentBytes = normalizedImage.Content;
            normalizedContentType = normalizedImage.ContentType;
            extension = normalizedImage.FileExtension;
            contentLength = normalizedImage.Content.LongLength;
            logger.LogInformation(
                "Support attachment processed. WasNormalized={WasNormalized} Reason={Reason} OriginalBytes={OriginalBytes} OutputBytes={OutputBytes} ContentType={ContentType}",
                normalizedImage.WasNormalized,
                normalizedImage.DecisionReason,
                attachmentBytes.LongLength,
                normalizedImage.Content.LongLength,
                normalizedContentType);
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
            if (normalizedAttachmentBytes is not null)
            {
                await File.WriteAllBytesAsync(physicalPath, normalizedAttachmentBytes, cancellationToken);
            }
            else if (attachment.Content is not null)
            {
                await File.WriteAllBytesAsync(physicalPath, attachment.Content, cancellationToken);
            }
            else if (attachment.ContentStream is not null)
            {
                if (attachment.ContentStream.CanSeek)
                {
                    attachment.ContentStream.Position = 0;
                }

                await using var output = new FileStream(physicalPath, FileMode.Create, FileAccess.Write, FileShare.None);
                await attachment.ContentStream.CopyToAsync(output, cancellationToken);
            }
            else
            {
                return Result.Failure<StoredSupportAttachmentResponse>(SupportChatErrors.InvalidAttachmentUpload);
            }
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
            contentLength,
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

    private static async Task<byte[]?> ReadAllBytesAsync(Stream? stream, CancellationToken cancellationToken)
    {
        if (stream is null)
        {
            return null;
        }

        if (stream.CanSeek)
        {
            stream.Position = 0;
        }

        using var buffer = new MemoryStream();
        await stream.CopyToAsync(buffer, cancellationToken);
        return buffer.ToArray();
    }

    private static bool TryResolveStoredFileFormat(
        string contentType,
        string fileName,
        byte[] attachmentContent,
        out string extension,
        out string normalizedContentType,
        out bool signatureMismatch)
    {
        extension = string.Empty;
        signatureMismatch = false;
        normalizedContentType = NormalizeContentType(contentType);
        if (string.IsNullOrWhiteSpace(normalizedContentType))
        {
            return false;
        }

        if (string.Equals(normalizedContentType, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            var fileExtension = Path.GetExtension(fileName).Trim().ToLowerInvariant();
            if (string.IsNullOrWhiteSpace(fileExtension)
                || !ExtensionContentTypes.TryGetValue(fileExtension, out var extensionContentType)
                || string.IsNullOrWhiteSpace(extensionContentType))
            {
                return false;
            }

            extension = fileExtension;
            normalizedContentType = extensionContentType;
        }
        else
        {
            if (!AllowedContentTypeExtensions.TryGetValue(normalizedContentType, out var mappedExtension)
                || string.IsNullOrWhiteSpace(mappedExtension))
            {
                return false;
            }

            extension = mappedExtension;
            if (string.Equals(normalizedContentType, "image/jpg", StringComparison.OrdinalIgnoreCase))
            {
                normalizedContentType = "image/jpeg";
            }
        }

        if (!MatchesFileSignature(normalizedContentType, attachmentContent))
        {
            signatureMismatch = true;
            return false;
        }

        return true;
    }

    private static bool MatchesFileSignature(string normalizedContentType, byte[]? attachmentContent)
    {
        if (attachmentContent is null || attachmentContent.Length < 4)
        {
            return false;
        }

        return normalizedContentType switch
        {
            "image/jpeg" => attachmentContent.Length >= 3
                && attachmentContent[0] == 0xFF
                && attachmentContent[1] == 0xD8
                && attachmentContent[2] == 0xFF,
            "image/png" => attachmentContent.Length >= 8
                && attachmentContent[0] == 0x89
                && attachmentContent[1] == 0x50
                && attachmentContent[2] == 0x4E
                && attachmentContent[3] == 0x47
                && attachmentContent[4] == 0x0D
                && attachmentContent[5] == 0x0A
                && attachmentContent[6] == 0x1A
                && attachmentContent[7] == 0x0A,
            "image/webp" => attachmentContent.Length >= 12
                && attachmentContent[0] == 0x52
                && attachmentContent[1] == 0x49
                && attachmentContent[2] == 0x46
                && attachmentContent[3] == 0x46
                && attachmentContent[8] == 0x57
                && attachmentContent[9] == 0x45
                && attachmentContent[10] == 0x42
                && attachmentContent[11] == 0x50,
            "video/mp4" or "video/quicktime" => attachmentContent.Length >= 12
                && attachmentContent[4] == 0x66
                && attachmentContent[5] == 0x74
                && attachmentContent[6] == 0x79
                && attachmentContent[7] == 0x70,
            _ => false,
        };
    }

    private long ResolveMaxFileSizeBytes(string normalizedContentType)
    {
        return normalizedContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
            ? options.MaxVideoFileSizeBytes
            : options.MaxImageFileSizeBytes;
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
