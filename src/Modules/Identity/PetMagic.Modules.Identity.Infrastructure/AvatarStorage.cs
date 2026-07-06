using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Images;
using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.BuildingBlocks.Storage;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed record AvatarUploadCommand(
    string FileName,
    string ContentType,
    byte[]? Content,
    Stream? ContentStream,
    long? ContentLengthBytes)
{
    public AvatarUploadCommand(string fileName, string contentType, byte[] content)
        : this(fileName, contentType, content, null, content.LongLength)
    {
    }

    public AvatarUploadCommand(string fileName, string contentType, Stream contentStream, long? contentLengthBytes = null)
        : this(fileName, contentType, null, contentStream, contentLengthBytes)
    {
    }
}

public sealed record StoredAvatarResponse(
    string Url,
    string StorageKey,
    string FileName,
    string ContentType,
    long FileSizeBytes,
    string? LocalPath);

public interface IAvatarStorage
{
    Task<Result<StoredAvatarResponse>> StoreAsync(AvatarUploadCommand avatar, CancellationToken cancellationToken);

    Task<Result> DeleteAsync(string? avatarUrl, CancellationToken cancellationToken);
}

internal sealed class LocalAvatarStorage(
    AvatarStorageOptions options,
    IHostEnvironment hostEnvironment,
    ILogger<LocalAvatarStorage> logger) : IAvatarStorage
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

    public async Task<Result<StoredAvatarResponse>> StoreAsync(AvatarUploadCommand avatar, CancellationToken cancellationToken)
    {
        var contentLength = avatar.Content?.LongLength ?? avatar.ContentLengthBytes ?? 0;
        if (contentLength <= 0)
        {
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.InvalidAvatarUpload);
        }

        if (contentLength > options.MaxFileSizeBytes)
        {
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.AvatarFileTooLarge);
        }

        if (!TryResolveAvatarFileFormat(avatar.ContentType, out var extension, out var normalizedContentType))
        {
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.AvatarContentTypeNotAllowed);
        }

        var avatarBytes = avatar.Content;
        if (avatarBytes is null)
        {
            var readResult = await ReadAllBytesWithinLimitAsync(
                avatar.ContentStream,
                options.MaxFileSizeBytes,
                cancellationToken);
            if (readResult.ExceededLimit)
            {
                return Result.Failure<StoredAvatarResponse>(IdentityErrors.AvatarFileTooLarge);
            }

            if (readResult.Content is null)
            {
                return Result.Failure<StoredAvatarResponse>(IdentityErrors.InvalidAvatarUpload);
            }

            avatarBytes = readResult.Content;
        }

        var normalizedImage = UploadedImageNormalizer.NormalizeOrKeep(
            avatarBytes,
            normalizedContentType,
            UploadedImageProfile.Avatar);
        normalizedContentType = normalizedImage.ContentType;
        extension = normalizedImage.FileExtension;
        contentLength = normalizedImage.Content.LongLength;
        logger.LogInformation(
            "Avatar upload processed. WasNormalized={WasNormalized} Reason={Reason} OriginalBytes={OriginalBytes} OutputBytes={OutputBytes}",
            normalizedImage.WasNormalized,
            normalizedImage.DecisionReason,
            avatarBytes.LongLength,
            normalizedImage.Content.LongLength);

        var root = ResolveRootPath();
        var safeName = $"{Guid.NewGuid():N}{extension}";
        var year = DateTime.UtcNow.ToString("yyyy");
        var month = DateTime.UtcNow.ToString("MM");
        var relativePath = Path.Combine("user-avatars", year, month, safeName);
        var physicalPath = Path.Combine(root, year, month, safeName);

        try
        {
            Directory.CreateDirectory(root);
            Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);
            await File.WriteAllBytesAsync(physicalPath, normalizedImage.Content, cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Avatar storage write failed. Operation={Operation} ContentType={ContentType} OutputBytes={OutputBytes} WasNormalized={WasNormalized} ExceptionType={ExceptionType}",
                "store",
                normalizedContentType,
                normalizedImage.Content.LongLength,
                normalizedImage.WasNormalized,
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.AvatarStorageFailed);
        }

        var normalizedRelativePath = relativePath.Replace("\\", "/");
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        var url = $"{baseUrl}/{normalizedRelativePath}";

        return Result.Success(new StoredAvatarResponse(
            url,
            normalizedRelativePath,
            avatar.FileName,
            normalizedContentType,
            contentLength,
            physicalPath));
    }

    private static async Task<(byte[]? Content, bool ExceededLimit)> ReadAllBytesWithinLimitAsync(
        Stream? stream,
        long maxFileSizeBytes,
        CancellationToken cancellationToken)
    {
        if (stream is null)
        {
            return (null, ExceededLimit: false);
        }

        if (stream.CanSeek)
        {
            stream.Position = 0;
        }

        using var buffer = new MemoryStream();
        var copyBuffer = new byte[81920];
        while (true)
        {
            var read = await stream.ReadAsync(copyBuffer.AsMemory(0, copyBuffer.Length), cancellationToken);
            if (read == 0)
            {
                break;
            }

            if (buffer.Length + read > maxFileSizeBytes)
            {
                return (null, ExceededLimit: true);
            }

            await buffer.WriteAsync(copyBuffer.AsMemory(0, read), cancellationToken);
        }

        return (buffer.ToArray(), ExceededLimit: false);
    }

    public Task<Result> DeleteAsync(string? avatarUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(avatarUrl))
        {
            return Task.FromResult(Result.Success());
        }

        var root = ResolveRootPath();
        var relativePath = TryResolveManagedRelativePath(avatarUrl);
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
        catch (Exception exception)
        {
            logger.LogWarning(
                "Avatar storage delete failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ExceptionType={ExceptionType}",
                "delete",
                SafeLogValues.StableHash(relativePath),
                SafeLogValues.ExceptionType(exception));
            return Task.FromResult(Result.Failure(IdentityErrors.AvatarStorageFailed));
        }
    }

    private string ResolveRootPath()
    {
        var root = Path.IsPathRooted(options.LocalMediaRootPath)
            ? options.LocalMediaRootPath
            : Path.Combine(hostEnvironment.ContentRootPath, options.LocalMediaRootPath);

        return Path.GetFullPath(root);
    }

    private string? TryResolveManagedRelativePath(string avatarUrl)
    {
        var candidate = avatarUrl.Trim();
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return null;
        }

        if (TryNormalizeManagedRelativePath(candidate, out var managedRelativePath))
        {
            return managedRelativePath;
        }

        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase)
            || candidate.Length <= baseUrl.Length
            || candidate[baseUrl.Length] != '/')
        {
            return null;
        }

        var relativePath = candidate[baseUrl.Length..].TrimStart('/');
        if (!TryNormalizeManagedRelativePath(relativePath, out managedRelativePath))
        {
            return null;
        }

        return managedRelativePath;
    }

    private static bool TryNormalizeManagedRelativePath(string candidate, out string managedRelativePath)
    {
        managedRelativePath = string.Empty;
        var normalized = candidate
            .Replace('\\', '/')
            .TrimStart('/');
        var pathOnly = normalized.Split(['?', '#'])[0];
        if (string.IsNullOrWhiteSpace(pathOnly)
            || pathOnly.EndsWith("/", StringComparison.Ordinal)
            || !pathOnly.StartsWith("user-avatars/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var segments = pathOnly
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Length <= 1
            || segments.Any(IsUnsafeManagedPathSegment))
        {
            return false;
        }

        managedRelativePath = string.Join('/', segments);
        return true;
    }

    private static bool IsUnsafeManagedPathSegment(string segment)
    {
        return ManagedPathSegments.IsUnsafe(segment);
    }

    private static bool TryResolveAvatarFileFormat(string contentType, out string extension, out string normalizedContentType)
    {
        extension = string.Empty;
        normalizedContentType = NormalizeContentType(contentType);
        if (!normalizedContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var subtype = normalizedContentType["image/".Length..];
        if (!ImageSubtypeExtensions.TryGetValue(subtype, out var mappedExtension)
            || string.IsNullOrWhiteSpace(mappedExtension))
        {
            return false;
        }

        extension = mappedExtension;
        normalizedContentType = string.Equals(subtype, "jpg", StringComparison.OrdinalIgnoreCase)
            ? "image/jpeg"
            : $"image/{subtype}";
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
