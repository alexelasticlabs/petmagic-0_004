using Microsoft.Extensions.Hosting;

using PetMagic.BuildingBlocks.Results;
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

internal sealed class LocalAvatarStorage(AvatarStorageOptions options, IHostEnvironment hostEnvironment) : IAvatarStorage
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

        if (!TryResolveAvatarFileFormat(avatar.ContentType, out var extension, out var normalizedContentType))
        {
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.AvatarContentTypeNotAllowed);
        }

        var root = ResolveRootPath();
        Directory.CreateDirectory(root);

        var safeName = $"{Guid.NewGuid():N}{extension}";
        var year = DateTime.UtcNow.ToString("yyyy");
        var month = DateTime.UtcNow.ToString("MM");
        var relativePath = Path.Combine("user-avatars", year, month, safeName);
        var physicalPath = Path.Combine(root, year, month, safeName);

        Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);
        try
        {
            if (avatar.Content is not null)
            {
                await File.WriteAllBytesAsync(physicalPath, avatar.Content, cancellationToken);
            }
            else if (avatar.ContentStream is not null)
            {
                if (avatar.ContentStream.CanSeek)
                {
                    avatar.ContentStream.Position = 0;
                }

                await using var output = new FileStream(physicalPath, FileMode.Create, FileAccess.Write, FileShare.None);
                await avatar.ContentStream.CopyToAsync(output, cancellationToken);
            }
            else
            {
                return Result.Failure<StoredAvatarResponse>(IdentityErrors.InvalidAvatarUpload);
            }
        }
        catch
        {
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
        catch
        {
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
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!avatarUrl.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = avatarUrl[baseUrl.Length..].TrimStart('/');
        if (!relativePath.StartsWith("user-avatars/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return relativePath.Replace('\\', '/');
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
