using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.BuildingBlocks.Security;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class HttpGeneratedMediaImporter(
    IHttpClientFactory httpClientFactory,
    IMediaStorage mediaStorage,
    TemplatesOptions options,
    ILogger<HttpGeneratedMediaImporter> logger) : IGeneratedMediaImporter
{
    public const string HttpClientName = "TemplatesGeneratedMedia";

    public async Task<Result<StoredMediaResponse>> ImportVideoAsync(string generatedVideoUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return await ImportAsync(
            generatedVideoUrl,
            generationId,
            options.GeneratedVideoMaxFileSizeBytes,
            "video/",
            "video/mp4",
            ResolveVideoExtension,
            cancellationToken);
    }

    public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return ImportAsync(
            generatedImageUrl,
            generationId,
            options.GeneratedImageMaxFileSizeBytes,
            "image/",
            "image/png",
            ResolveImageExtension,
            cancellationToken);
    }

    private static async Task CopyWithLimitAsync(Stream source, Stream destination, long maxBytes, CancellationToken cancellationToken)
    {
        var buffer = new byte[81920];
        long totalBytes = 0;
        while (true)
        {
            var bytesRead = await source.ReadAsync(buffer, cancellationToken);
            if (bytesRead == 0)
            {
                return;
            }

            totalBytes += bytesRead;
            if (totalBytes > maxBytes)
            {
                throw new InvalidOperationException("Generated media exceeds configured size limit.");
            }

            await destination.WriteAsync(buffer.AsMemory(0, bytesRead), cancellationToken);
        }
    }

    private static string ResolveVideoExtension(string contentType, Uri uri)
    {
        if (string.Equals(contentType, "video/webm", StringComparison.OrdinalIgnoreCase))
        {
            return ".webm";
        }

        if (string.Equals(contentType, "video/quicktime", StringComparison.OrdinalIgnoreCase))
        {
            return ".mov";
        }

        return ".mp4";
    }

    private static string ResolveImageExtension(string contentType, Uri uri)
    {
        if (string.Equals(contentType, "image/jpeg", StringComparison.OrdinalIgnoreCase))
        {
            return ".jpg";
        }

        if (string.Equals(contentType, "image/webp", StringComparison.OrdinalIgnoreCase))
        {
            return ".webp";
        }

        if (string.Equals(contentType, "image/gif", StringComparison.OrdinalIgnoreCase))
        {
            return ".gif";
        }

        return ".png";
    }

    private async Task<Result<StoredMediaResponse>> ImportAsync(
        string generatedMediaUrl,
        Guid generationId,
        long maxFileSizeBytes,
        string expectedContentTypePrefix,
        string defaultContentType,
        Func<string, Uri, string> resolveExtension,
        CancellationToken cancellationToken)
    {
        var mediaType = ResolveMetricsMediaType(expectedContentTypePrefix);
        if (!Uri.TryCreate(generatedMediaUrl, UriKind.Absolute, out var uri))
        {
            TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "invalid_url");
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }

        if (!IsAllowedGeneratedMediaUri(uri))
        {
            TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "url_not_allowed");
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }

        try
        {
            var client = httpClientFactory.CreateClient(HttpClientName);
            using var response = await client.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, $"http_{(int)response.StatusCode}");
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
            }

            var length = response.Content.Headers.ContentLength;
            if (length is > 0 && length > maxFileSizeBytes)
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "too_large");
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaTooLarge);
            }

            var declaredContentType = response.Content.Headers.ContentType?.MediaType;
            var contentType = declaredContentType ?? defaultContentType;
            if (!contentType.StartsWith(expectedContentTypePrefix, StringComparison.OrdinalIgnoreCase))
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "unexpected_content_type");
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var memoryStream = new MemoryStream();
            await CopyWithLimitAsync(stream, memoryStream, maxFileSizeBytes, cancellationToken);
            memoryStream.Position = 0;

            var detectedContentType = DetectContentType(memoryStream.GetBuffer().AsSpan(0, (int)memoryStream.Length));
            if (detectedContentType is null
                || !detectedContentType.StartsWith(expectedContentTypePrefix, StringComparison.OrdinalIgnoreCase)
                || !MatchesDeclaredContentType(detectedContentType, declaredContentType))
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "content_type_mismatch");
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
            }

            memoryStream.Position = 0;
            var extension = resolveExtension(detectedContentType, uri);
            var upload = new MediaUploadCommand($"generated-{generationId:N}{extension}", detectedContentType, memoryStream, memoryStream.Length);
            var storeResult = await mediaStorage.StoreAsync(upload, cancellationToken);
            if (storeResult.IsFailure)
            {
                var safeErrorCode = SafeStorageErrorCode(storeResult.Error.Code);
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, safeErrorCode);
                return Result.Failure<StoredMediaResponse>(new Error(safeErrorCode, TemplatesErrors.MediaStorageFailed.Message));
            }

            return storeResult;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (InvalidOperationException)
        {
            TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "too_large");
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaTooLarge);
        }
        catch (Exception exception)
        {
            TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "exception");
            logger.LogWarning(
                "Generated template media import failed. GenerationIdHash={GenerationIdHash} ExceptionType={ExceptionType}",
                TemplateLogSanitizer.SafeId(generationId),
                SafeLogValues.ExceptionType(exception));
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }
    }

    private static bool IsAllowedGeneratedMediaUri(Uri uri)
    {
        return uri.IsAbsoluteUri
            && string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase)
            && !uri.IsLoopback
            && !SafeNetworkTargetPolicy.IsPrivateNetworkTarget(uri)
            && string.IsNullOrWhiteSpace(uri.UserInfo);
    }

    private static bool MatchesDeclaredContentType(string detectedContentType, string? declaredContentType)
    {
        if (string.IsNullOrWhiteSpace(declaredContentType))
        {
            return true;
        }

        var normalizedDeclared = NormalizeContentType(declaredContentType);
        if (string.IsNullOrWhiteSpace(normalizedDeclared)
            || string.Equals(normalizedDeclared, "application/octet-stream", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return string.Equals(detectedContentType, normalizedDeclared, StringComparison.OrdinalIgnoreCase)
            || (string.Equals(detectedContentType, "image/jpeg", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "image/jpg", StringComparison.OrdinalIgnoreCase))
            || (string.Equals(detectedContentType, "video/mp4", StringComparison.OrdinalIgnoreCase)
                && string.Equals(normalizedDeclared, "application/mp4", StringComparison.OrdinalIgnoreCase));
    }

    private static string NormalizeContentType(string contentType)
    {
        var semicolonIndex = contentType.IndexOf(';');
        var normalized = semicolonIndex >= 0 ? contentType[..semicolonIndex] : contentType;
        return normalized.Trim().ToLowerInvariant();
    }

    private static string? DetectContentType(ReadOnlySpan<byte> payload)
    {
        var header = payload[..Math.Min(payload.Length, 32)];
        if (header.Length >= 3
            && header[0] == 0xFF
            && header[1] == 0xD8
            && header[2] == 0xFF)
        {
            return "image/jpeg";
        }

        if (header.Length >= 8
            && header[0] == 0x89
            && header[1] == 0x50
            && header[2] == 0x4E
            && header[3] == 0x47
            && header[4] == 0x0D
            && header[5] == 0x0A
            && header[6] == 0x1A
            && header[7] == 0x0A)
        {
            return "image/png";
        }

        if (header.Length >= 12
            && header[0] == 0x52
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x46
            && header[8] == 0x57
            && header[9] == 0x45
            && header[10] == 0x42
            && header[11] == 0x50)
        {
            return "image/webp";
        }

        if (header.Length >= 6
            && header[0] == 0x47
            && header[1] == 0x49
            && header[2] == 0x46
            && header[3] == 0x38
            && (header[4] == 0x37 || header[4] == 0x39)
            && header[5] == 0x61)
        {
            return "image/gif";
        }

        if (TryReadIsoBmffBrand(header, out var brand))
        {
            if (string.Equals(brand, "qt  ", StringComparison.OrdinalIgnoreCase))
            {
                return "video/quicktime";
            }

            if (IsSupportedMp4Brand(brand))
            {
                return "video/mp4";
            }
        }

        if (header.Length >= 4
            && header[0] == 0x1A
            && header[1] == 0x45
            && header[2] == 0xDF
            && header[3] == 0xA3)
        {
            return "video/webm";
        }

        return null;
    }

    private static bool TryReadIsoBmffBrand(ReadOnlySpan<byte> header, out string brand)
    {
        brand = string.Empty;
        if (header.Length < 12
            || header[4] != 0x66
            || header[5] != 0x74
            || header[6] != 0x79
            || header[7] != 0x70)
        {
            return false;
        }

        brand = string.Create(4, header, static (chars, bytes) =>
        {
            for (var i = 0; i < chars.Length; i++)
            {
                chars[i] = (char)bytes[8 + i];
            }
        });
        return true;
    }

    private static bool IsSupportedMp4Brand(string brand)
    {
        return string.Equals(brand, "mp41", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "mp42", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "isom", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "iso2", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "avc1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "m4v ", StringComparison.OrdinalIgnoreCase)
            || string.Equals(brand, "m4a ", StringComparison.OrdinalIgnoreCase);
    }

    private static string ResolveMetricsMediaType(string expectedContentTypePrefix)
    {
        return expectedContentTypePrefix.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
            ? TemplateGenerationQueue.MediaTypeVideo
            : TemplateGenerationQueue.MediaTypeImage;
    }

    private static string SafeStorageErrorCode(string? code)
    {
        var trimmed = code?.Trim();
        var sanitized = AdminFailureMessageSanitizer.SanitizeCode(trimmed);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized ?? TemplatesErrors.MediaStorageFailed.Code
            : TemplatesErrors.MediaStorageFailed.Code;
    }
}
