using Amazon.S3;
using Amazon.S3.Model;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class R2MediaStorage(TemplatesOptions options, IAmazonS3 s3Client) : IMediaStorage
{
    public async Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
    {
        var contentLength = asset.Content?.LongLength ?? asset.ContentLengthBytes ?? 0;
        if (contentLength <= 0)
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        if (!options.R2.IsConfigured)
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed);
        }

        string? tempPath = null;
        var extension = Path.GetExtension(asset.PreferredStorageKey ?? asset.FileName);
        if (!TryResolvePreferredStorageKey(asset.PreferredStorageKey, extension, out var preferredStorageKey))
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        var storageKey = BuildObjectKey(extension, preferredStorageKey);

        try
        {
            if (asset.Content is not null)
            {
                tempPath = await TemplateMediaTempFiles.WriteAsync(asset.Content, extension, cancellationToken);
            }
            else if (asset.ContentStream is not null)
            {
                if (asset.ContentStream.CanSeek)
                {
                    asset.ContentStream.Position = 0;
                }

                tempPath = await TemplateMediaTempFiles.WriteAsync(asset.ContentStream, extension, cancellationToken);
            }
            else
            {
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
            }

            var detectedContentType = MediaMagicBytes.DetectContentType(tempPath);
            if (detectedContentType is null || !ContentTypesMatch(detectedContentType, asset.ContentType))
            {
                TemplateMediaTempFiles.TryDeleteIfOwned(tempPath);
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
            }

            await using var stream = File.OpenRead(tempPath);
            var request = new PutObjectRequest
            {
                BucketName = options.R2.BucketName,
                Key = storageKey,
                InputStream = stream,
                ContentType = detectedContentType,
                DisablePayloadSigning = true,
                DisableDefaultChecksumValidation = true
            };

            await s3Client.PutObjectAsync(request, cancellationToken);

            return Result.Success(new StoredMediaResponse(
                BuildPublicUrl(storageKey),
                storageKey,
                asset.FileName,
                detectedContentType,
                contentLength,
                tempPath));
        }
        catch
        {
            TemplateMediaTempFiles.TryDeleteIfOwned(tempPath);
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.MediaStorageFailed);
        }
    }

    public async Task<Result> DeleteAsync(string assetUrl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl) || !options.R2.IsConfigured)
        {
            return Result.Success();
        }

        var storageKey = TryResolveManagedKey(assetUrl);
        if (storageKey is null)
        {
            return Result.Success();
        }

        try
        {
            await s3Client.DeleteObjectAsync(options.R2.BucketName, storageKey, cancellationToken);
            return Result.Success();
        }
        catch
        {
            return Result.Failure(TemplatesErrors.MediaStorageFailed);
        }
    }

    public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl) || !options.R2.IsConfigured)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }

        var storageKey = TryResolveManagedKey(assetUrl);
        if (storageKey is null)
        {
            return Task.FromResult(Result.Success(assetUrl));
        }

        try
        {
            var request = new GetPreSignedUrlRequest
            {
                BucketName = options.R2.BucketName,
                Key = storageKey,
                Verb = HttpVerb.GET,
                Expires = DateTime.UtcNow.Add(ttl)
            };

            return Task.FromResult(Result.Success(s3Client.GetPreSignedURL(request)));
        }
        catch
        {
            return Task.FromResult(Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
        }
    }

    private string BuildObjectKey(string extension, string? preferredStorageKey)
    {
        var now = DateTime.UtcNow;
        var prefix = NormalizePrefix(options.R2.ObjectKeyPrefix);
        if (!string.IsNullOrWhiteSpace(preferredStorageKey))
        {
            return $"{prefix}/{preferredStorageKey}";
        }

        var safeExtension = string.IsNullOrWhiteSpace(extension) || extension.Length > 16
            ? string.Empty
            : extension;

        return $"{prefix}/{now:yyyy}/{now:MM}/{Guid.NewGuid():N}{safeExtension}";
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

    private string BuildPublicUrl(string storageKey)
    {
        return $"{options.R2.PublicBaseUrl.TrimEnd('/')}/{storageKey}";
    }

    private string? TryResolveManagedKey(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        var prefix = NormalizePrefix(options.R2.ObjectKeyPrefix);
        if (candidate.StartsWith($"{prefix}/", StringComparison.OrdinalIgnoreCase))
        {
            return candidate;
        }

        var baseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var storageKey = candidate[baseUrl.Length..].TrimStart('/');
        return storageKey.StartsWith($"{prefix}/", StringComparison.OrdinalIgnoreCase)
            ? storageKey
            : null;
    }

    private static bool ContentTypesMatch(string detectedContentType, string declaredContentType)
    {
        var normalizedDeclared = declaredContentType.Trim().ToLowerInvariant();
        if (string.Equals(normalizedDeclared, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(detectedContentType, normalizedDeclared, StringComparison.OrdinalIgnoreCase)
            || (string.Equals(detectedContentType, "video/mp4", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "application/mp4", StringComparison.OrdinalIgnoreCase))
            || (string.Equals(detectedContentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "image/jpg", StringComparison.OrdinalIgnoreCase));
    }

    private static string NormalizePrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }
}
