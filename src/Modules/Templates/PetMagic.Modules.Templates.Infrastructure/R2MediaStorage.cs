using Amazon.S3;
using Amazon.S3.Model;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.BuildingBlocks.Storage;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class R2MediaStorage(
    TemplatesOptions options,
    IAmazonS3 s3Client,
    ILogger<R2MediaStorage>? logger = null) : IMediaStorage
{
    private const string ImmutableCacheControl = "public,max-age=31536000,immutable";
    private const int AmbiguousStoreCleanupTimeoutSeconds = 10;
    private const string AmbiguousStorageKeyMetadataName = "ambiguousStorageKey";

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
        var putAttempted = false;
        var canDeleteAmbiguousStore = IsGuaranteedNewObjectKey(preferredStorageKey);

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
                TemplateMediaTempFiles.TryDeleteIfOwned(tempPath, logger);
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

            if (preferredStorageKey?.StartsWith("template-previews/", StringComparison.Ordinal) == true)
            {
                request.Headers.CacheControl = ImmutableCacheControl;
            }

            putAttempted = true;
            await s3Client.PutObjectAsync(request, cancellationToken);

            return Result.Success(new StoredMediaResponse(
                BuildPublicUrl(storageKey),
                storageKey,
                asset.FileName,
                detectedContentType,
                contentLength,
                tempPath));
        }
        catch (Exception exception)
        {
            TemplateGenerationMetrics.RecordR2UploadFailure("store");
            logger?.LogWarning(
                "R2 media store failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ContentLength={ContentLength} HasPreferredStorageKey={HasPreferredStorageKey} ExceptionType={ExceptionType}",
                "store",
                SafeLogValues.StableHash(storageKey),
                contentLength,
                !string.IsNullOrWhiteSpace(preferredStorageKey),
                SafeLogValues.ExceptionType(exception));
            TemplateMediaTempFiles.TryDeleteIfOwned(tempPath, logger);
            var cleanupSucceeded = !putAttempted
                || !canDeleteAmbiguousStore
                || await TryCleanupAmbiguousStoreAsync(storageKey);
            var error = cleanupSucceeded
                ? TemplatesErrors.MediaStorageFailed
                : TemplatesErrors.MediaStorageFailed with
                {
                    Metadata = new Dictionary<string, object?>
                    {
                        [AmbiguousStorageKeyMetadataName] = storageKey
                    }
                };
            return Result.Failure<StoredMediaResponse>(error);
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
        catch (Exception exception)
        {
            logger?.LogWarning(
                "R2 media delete failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ExceptionType={ExceptionType}",
                "delete",
                SafeLogValues.StableHash(storageKey),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure(TemplatesErrors.MediaStorageFailed);
        }
    }

    public Task<Result<string>> CreateReadUrlAsync(string assetUrl, TimeSpan ttl, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(assetUrl) || !options.R2.IsConfigured)
        {
            return Task.FromResult(Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
        }

        var storageKey = TryResolveManagedKey(assetUrl);
        if (storageKey is null)
        {
            return Task.FromResult(Result.Failure<string>(TemplatesErrors.MediaStorageFailed));
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
        catch (Exception exception)
        {
            logger?.LogWarning(
                "R2 media read-url signing failed. Operation={Operation} StorageKeyHash={StorageKeyHash} TtlMinutes={TtlMinutes} ExceptionType={ExceptionType}",
                "sign_read_url",
                SafeLogValues.StableHash(storageKey),
                ttl.TotalMinutes,
                SafeLogValues.ExceptionType(exception));
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

    private async Task<bool> TryCleanupAmbiguousStoreAsync(string storageKey)
    {
        using var cleanupSource = new CancellationTokenSource(
            TimeSpan.FromSeconds(AmbiguousStoreCleanupTimeoutSeconds));
        try
        {
            await s3Client.DeleteObjectAsync(
                options.R2.BucketName,
                storageKey,
                cleanupSource.Token);
            return true;
        }
        catch (Exception exception)
        {
            logger?.LogWarning(
                "R2 ambiguous media store cleanup failed. Operation={Operation} StorageKeyHash={StorageKeyHash} ExceptionType={ExceptionType}",
                "cleanup_ambiguous_store",
                SafeLogValues.StableHash(storageKey),
                SafeLogValues.ExceptionType(exception));
            return false;
        }
    }

    private static bool IsGuaranteedNewObjectKey(string? preferredStorageKey)
    {
        if (string.IsNullOrWhiteSpace(preferredStorageKey))
        {
            return true;
        }

        var segments = preferredStorageKey.Split('/', StringSplitOptions.RemoveEmptyEntries);
        return segments.Length == 3
            && string.Equals(segments[0], "template-previews", StringComparison.Ordinal)
            && Guid.TryParseExact(segments[1], "N", out _);
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
        var queryIndex = candidate.IndexOfAny(['?', '#']);
        if (queryIndex >= 0)
        {
            candidate = candidate[..queryIndex];
        }

        var prefix = NormalizePrefix(options.R2.ObjectKeyPrefix);
        if (TryNormalizeManagedKey(candidate, prefix, out var managedKey))
        {
            return managedKey;
        }

        var baseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase)
            || candidate.Length <= baseUrl.Length
            || candidate[baseUrl.Length] != '/')
        {
            return null;
        }

        var storageKey = candidate[baseUrl.Length..].TrimStart('/');
        return TryNormalizeManagedKey(storageKey, prefix, out managedKey)
            ? managedKey
            : null;
    }

    private static bool TryNormalizeManagedKey(string candidate, string prefix, out string managedKey)
    {
        managedKey = string.Empty;
        var keyOnly = candidate.TrimStart('/');
        if (string.IsNullOrWhiteSpace(keyOnly)
            || keyOnly.EndsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var segments = keyOnly
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Any(IsUnsafeManagedKeySegment))
        {
            return false;
        }

        var normalizedKey = string.Join('/', segments);
        if (!normalizedKey.StartsWith($"{prefix}/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        managedKey = normalizedKey;
        return true;
    }

    private static bool IsUnsafeManagedKeySegment(string segment)
    {
        return ManagedPathSegments.IsUnsafe(segment);
    }

    private static bool ContentTypesMatch(string detectedContentType, string declaredContentType)
    {
        var normalizedDeclared = NormalizeContentType(declaredContentType);
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

    private static string NormalizeContentType(string contentType)
    {
        if (string.IsNullOrWhiteSpace(contentType))
        {
            return string.Empty;
        }

        var semicolonIndex = contentType.IndexOf(';');
        var normalized = semicolonIndex >= 0 ? contentType[..semicolonIndex] : contentType;
        return normalized.Trim().ToLowerInvariant();
    }

    private static string NormalizePrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }
}
