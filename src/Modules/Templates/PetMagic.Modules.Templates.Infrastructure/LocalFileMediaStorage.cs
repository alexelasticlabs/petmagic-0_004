using Microsoft.Extensions.Hosting;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class LocalFileMediaStorage(TemplatesOptions options, IHostEnvironment hostEnvironment) : IMediaStorage
{
    private static readonly Dictionary<string, string> ImageSubtypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["jpeg"] = ".jpg",
        ["jpg"] = ".jpg",
        ["png"] = ".png",
        ["webp"] = ".webp",
        ["heic"] = ".heic",
        ["heif"] = ".heif",
        ["gif"] = ".gif"
    };

    private static readonly Dictionary<string, string> VideoSubtypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["mp4"] = ".mp4",
        ["quicktime"] = ".mov",
        ["webm"] = ".webm"
    };

    private static readonly Dictionary<string, string> ExactContentTypeExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ["application/mp4"] = ".mp4"
    };

    private static readonly Dictionary<string, string> ExtensionContentTypes = new(StringComparer.OrdinalIgnoreCase)
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
        [".heic"] = "image/heic",
        [".heif"] = "image/heif",
        [".gif"] = "image/gif",
        [".mp4"] = "video/mp4",
        [".mov"] = "video/quicktime",
        [".webm"] = "video/webm"
    };

    public async Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
    {
        var contentLength = asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0;
        if (contentLength <= 0)
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        if (!TryResolveStoredFileFormat(asset.ContentType, asset.FileName, out var extension, out var normalizedContentType))
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        var root = Path.IsPathRooted(options.LocalMediaRootPath)
            ? options.LocalMediaRootPath
            : Path.Combine(hostEnvironment.ContentRootPath, options.LocalMediaRootPath);

        Directory.CreateDirectory(root);

        var now = DateTime.UtcNow;
        var safeName = $"{Guid.NewGuid():N}{extension}";
        if (!TryResolvePreferredStorageKey(asset.PreferredStorageKey, extension, out var preferredStorageKey))
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        var storageRelativePath = preferredStorageKey
            ?? Path.Combine(now.ToString("yyyy"), now.ToString("MM"), safeName);
        var relativePath = Path.Combine("templates-media", storageRelativePath);
        var physicalPath = Path.Combine(root, storageRelativePath);

        Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);
        try
        {
            if (asset.Content is not null)
            {
                await File.WriteAllBytesAsync(physicalPath, asset.Content, cancellationToken);
            }
            else if (asset.ContentStream is not null)
            {
                if (asset.ContentStream.CanSeek)
                {
                    asset.ContentStream.Position = 0;
                }

                await using var output = new FileStream(physicalPath, FileMode.Create, FileAccess.Write, FileShare.None);
                await asset.ContentStream.CopyToAsync(output, cancellationToken);
            }
            else
            {
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
            }

            var detectedContentType = MediaMagicBytes.DetectContentType(physicalPath);
            if (detectedContentType is null
                || !string.Equals(detectedContentType, normalizedContentType, StringComparison.OrdinalIgnoreCase))
            {
                File.Delete(physicalPath);
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
            }
        }
        catch
        {
            if (File.Exists(physicalPath))
            {
                File.Delete(physicalPath);
            }

            return Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed);
        }

        var normalizedRelativePath = relativePath.Replace("\\", "/");
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        var url = $"{baseUrl}/{normalizedRelativePath}";

        return Result.Success(new StoredMediaResponse(url, normalizedRelativePath, asset.FileName, normalizedContentType, contentLength, physicalPath));
    }

    private static bool TryResolvePreferredStorageKey(string? preferredStorageKey, string extension, out string? normalized)
    {
        normalized = null;
        if (string.IsNullOrWhiteSpace(preferredStorageKey))
        {
            return true;
        }

        var candidate = preferredStorageKey.Trim().Replace('\\', '/').Trim('/');
        if (candidate.Length == 0
            || candidate.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase)
            || Path.IsPathRooted(candidate))
        {
            return false;
        }

        var segments = candidate.Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Length == 0)
        {
            return false;
        }

        foreach (var segment in segments)
        {
            if (segment is "." or ".." || segment.Any(IsUnsafePathCharacter))
            {
                return false;
            }
        }

        var fileExtension = Path.GetExtension(segments[^1]);
        if (!string.Equals(fileExtension, extension, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        normalized = string.Join('/', segments);
        return true;
    }

    private static bool IsUnsafePathCharacter(char value)
    {
        return !(char.IsAsciiLetterOrDigit(value) || value is '-' or '_' or '.');
    }

    public Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return Task.FromResult(Result.Success());
        }

        var root = ResolveRootPath();
        var relativePath = TryResolveManagedRelativePath(assetUrl);
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
            return Task.FromResult(Result.Failure(TemplatesErrors.MediaStorageFailed));
        }
    }

    private string ResolveRootPath()
    {
        var root = Path.IsPathRooted(options.LocalMediaRootPath)
            ? options.LocalMediaRootPath
            : Path.Combine(hostEnvironment.ContentRootPath, options.LocalMediaRootPath);

        return Path.GetFullPath(root);
    }

    public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl))
        {
            return Task.FromResult(Result.Success(assetUrl));
        }

        var relativePath = TryResolveManagedRelativePath(assetUrl);
        if (relativePath is null)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }

        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        return Task.FromResult(Result.Success($"{baseUrl}/{relativePath}"));
    }

    private string? TryResolveManagedRelativePath(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        if (candidate.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return candidate;
        }

        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = candidate[baseUrl.Length..].TrimStart('/');
        if (!relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return relativePath;
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
            if (!ImageSubtypeExtensions.TryGetValue(subtype, out var mappedImageExtension)
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

        if (normalizedContentType.StartsWith("video/", StringComparison.OrdinalIgnoreCase))
        {
            var subtype = normalizedContentType["video/".Length..];
            if (!VideoSubtypeExtensions.TryGetValue(subtype, out var mappedVideoExtension)
                || string.IsNullOrWhiteSpace(mappedVideoExtension))
            {
                return false;
            }

            extension = mappedVideoExtension;
            normalizedContentType = $"video/{subtype}";
            return true;
        }

        if (ExactContentTypeExtensions.TryGetValue(normalizedContentType, out var mappedExactExtension)
            && !string.IsNullOrWhiteSpace(mappedExactExtension))
        {
            extension = mappedExactExtension;
            normalizedContentType = extension == ".mp4"
                ? "video/mp4"
                : normalizedContentType;
            return true;
        }

        if (!string.Equals(normalizedContentType, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var fileExtension = Path.GetExtension(fileName).Trim().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(fileExtension)
            || !ExtensionContentTypes.TryGetValue(fileExtension, out var extensionContentType)
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
