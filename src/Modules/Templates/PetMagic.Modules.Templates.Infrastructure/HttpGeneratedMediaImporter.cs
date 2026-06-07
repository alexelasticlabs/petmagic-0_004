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
        return await ImportAsync(generatedVideoUrl, generationId, options.GeneratedVideoMaxFileSizeBytes, "video/mp4", ResolveVideoExtension, cancellationToken);
    }

    public Task<Result<StoredMediaResponse>> ImportImageAsync(string generatedImageUrl, Guid generationId, CancellationToken cancellationToken)
    {
        return ImportAsync(generatedImageUrl, generationId, options.GeneratedImageMaxFileSizeBytes, "image/png", ResolveImageExtension, cancellationToken);
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
        string defaultContentType,
        Func<string, Uri, string> resolveExtension,
        CancellationToken cancellationToken)
    {
        if (!Uri.TryCreate(generatedMediaUrl, UriKind.Absolute, out var uri))
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }

        try
        {
            var client = httpClientFactory.CreateClient(HttpClientName);
            using var response = await client.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
            }

            var length = response.Content.Headers.ContentLength;
            if (length is > 0 && length > maxFileSizeBytes)
            {
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaTooLarge);
            }

            var contentType = response.Content.Headers.ContentType?.MediaType ?? defaultContentType;
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var memoryStream = new MemoryStream();
            await CopyWithLimitAsync(stream, memoryStream, maxFileSizeBytes, cancellationToken);
            memoryStream.Position = 0;

            var extension = resolveExtension(contentType, uri);
            var upload = new MediaUploadCommand($"generated-{generationId:N}{extension}", contentType, memoryStream, memoryStream.Length);
            return await mediaStorage.StoreAsync(upload, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (InvalidOperationException)
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaTooLarge);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                exception,
                "Generated template media import failed. GenerationId={GenerationId}",
                generationId);
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }
    }
}
