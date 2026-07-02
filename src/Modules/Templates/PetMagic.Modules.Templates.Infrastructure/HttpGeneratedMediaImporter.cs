using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
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

        var extension = Path.GetExtension(uri.AbsolutePath);
        return string.IsNullOrWhiteSpace(extension) ? ".mp4" : extension;
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

        var extension = Path.GetExtension(uri.AbsolutePath);
        return string.IsNullOrWhiteSpace(extension) ? ".png" : extension;
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

            var contentType = response.Content.Headers.ContentType?.MediaType ?? defaultContentType;
            if (!contentType.StartsWith(expectedContentTypePrefix, StringComparison.OrdinalIgnoreCase))
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, "unexpected_content_type");
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
            }

            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var memoryStream = new MemoryStream();
            await CopyWithLimitAsync(stream, memoryStream, maxFileSizeBytes, cancellationToken);
            memoryStream.Position = 0;

            var extension = resolveExtension(contentType, uri);
            var upload = new MediaUploadCommand($"generated-{generationId:N}{extension}", contentType, memoryStream, memoryStream.Length);
            var storeResult = await mediaStorage.StoreAsync(upload, cancellationToken);
            if (storeResult.IsFailure)
            {
                TemplateGenerationMetrics.RecordMediaImportFailure(mediaType, storeResult.Error.Code);
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
                exception,
                "Generated template media import failed. GenerationId={GenerationId}",
                generationId);
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

    private static string ResolveMetricsMediaType(string expectedContentTypePrefix)
    {
        return expectedContentTypePrefix.StartsWith("video/", StringComparison.OrdinalIgnoreCase)
            ? TemplateGenerationQueue.MediaTypeVideo
            : TemplateGenerationQueue.MediaTypeImage;
    }
}
