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
        if (!Uri.TryCreate(generatedVideoUrl, UriKind.Absolute, out var uri))
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
            if (length is > 0 && length > options.GeneratedVideoMaxFileSizeBytes)
            {
                return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaTooLarge);
            }

            var contentType = response.Content.Headers.ContentType?.MediaType ?? "video/mp4";
            await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
            using var memoryStream = new MemoryStream();
            await CopyWithLimitAsync(stream, memoryStream, options.GeneratedVideoMaxFileSizeBytes, cancellationToken);

            var extension = ResolveVideoExtension(contentType, uri);
            var upload = new MediaUploadCommand($"generated-{generationId:N}{extension}", contentType, memoryStream.ToArray());
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
            logger.LogWarning(exception, "Generated template media import failed for generation {GenerationId}.", generationId);
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.GeneratedMediaImportFailed);
        }
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
}
