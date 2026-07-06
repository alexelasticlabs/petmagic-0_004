using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Webp;
using SixLabors.ImageSharp.Processing;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class ImagePreviewGenerator(
    IMediaStorage mediaStorage,
    IHttpClientFactory httpClientFactory,
    Options.TemplatesOptions options,
    ILogger<ImagePreviewGenerator> logger) : IImagePreviewGenerator
{
    private const int MaxPreviewSize = 1024;

    public async Task<StoredMediaResponse?> CreatePreviewAsync(
        StoredMediaResponse original,
        string outputFileName,
        string? preferredStorageKey,
        CancellationToken cancellationToken)
    {
        string? tempInput = null;
        try
        {
            var inputPath = await ResolveInputPathAsync(original, cancellationToken);
            tempInput = inputPath.TempPath;

            await using var input = File.OpenRead(inputPath.Path);
            using var image = await Image.LoadAsync(input, cancellationToken);
            image.Mutate(context => context.Resize(new ResizeOptions
            {
                Size = new Size(MaxPreviewSize, MaxPreviewSize),
                Mode = ResizeMode.Max
            }));

            await using var output = new MemoryStream();
            await image.SaveAsWebpAsync(output, new WebpEncoder { Quality = 82 }, cancellationToken);
            output.Position = 0;

            var stored = await mediaStorage.StoreAsync(
                new MediaUploadCommand(
                    outputFileName,
                    "image/webp",
                    null,
                    output,
                    output.Length,
                    preferredStorageKey),
                cancellationToken);

            if (stored.IsSuccess)
            {
                return stored.Value;
            }

            var safeErrorCode = SafeStorageErrorCode(stored.Error.Code);
            logger.LogWarning(
                "Image preview storage failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} ErrorCode={ErrorCode} HasLocalPath={HasLocalPath}",
                "store_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                safeErrorCode,
                !string.IsNullOrWhiteSpace(original.LocalPath));
            return null;
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Image preview generation failed. Operation={Operation} FileNameHash={FileNameHash} ContentType={ContentType} HasLocalPath={HasLocalPath} ExceptionType={ExceptionType}",
                "create_preview",
                TemplateLogSanitizer.SafeFileName(original.FileName),
                TemplateLogSanitizer.SafeContentType(original.ContentType),
                !string.IsNullOrWhiteSpace(original.LocalPath),
                SafeLogValues.ExceptionType(exception));
            return null;
        }
        finally
        {
            TryDelete(tempInput, original.FileName);
        }
    }

    private static string SafeStorageErrorCode(string? code)
    {
        var trimmed = code?.Trim();
        var sanitized = AdminFailureMessageSanitizer.SanitizeCode(trimmed);
        return string.Equals(trimmed, sanitized, StringComparison.Ordinal)
            ? sanitized ?? TemplatesErrors.MediaStorageFailed.Code
            : TemplatesErrors.MediaStorageFailed.Code;
    }

    private async Task<(string Path, string? TempPath)> ResolveInputPathAsync(
        StoredMediaResponse original,
        CancellationToken cancellationToken)
    {
        if (!string.IsNullOrWhiteSpace(original.LocalPath) && File.Exists(original.LocalPath))
        {
            return (original.LocalPath, null);
        }

        if (original.FileSizeBytes is > 0 && original.FileSizeBytes > options.PreviewMaxFileSizeBytes)
        {
            throw new InvalidOperationException("Preview input exceeds configured size limit.");
        }

        var signed = await mediaStorage.CreateReadUrlAsync(
            original.Url,
            TimeSpan.FromMinutes(5),
            cancellationToken);
        if (signed.IsFailure)
        {
            throw new InvalidOperationException("Could not create read URL for preview input.");
        }

        var extension = Path.GetExtension(original.FileName);
        if (string.IsNullOrWhiteSpace(extension))
        {
            extension = ".img";
        }

        var tempPath = Path.Combine(
            Path.GetTempPath(),
            $"petmagic-preview-input-{Guid.NewGuid():N}{extension}");
        var client = httpClientFactory.CreateClient(HttpGeneratedMediaImporter.HttpClientName);
        using var response = await client.GetAsync(signed.Value, HttpCompletionOption.ResponseHeadersRead, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException("Could not download preview input.");
        }

        var contentLength = response.Content.Headers.ContentLength;
        if (contentLength is > 0 && contentLength > options.PreviewMaxFileSizeBytes)
        {
            throw new InvalidOperationException("Preview input exceeds configured size limit.");
        }

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        await using var file = File.Create(tempPath);
        await CopyWithLimitAsync(stream, file, options.PreviewMaxFileSizeBytes, cancellationToken);
        return (tempPath, tempPath);
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
                throw new InvalidOperationException("Preview input exceeds configured size limit.");
            }

            await destination.WriteAsync(buffer.AsMemory(0, bytesRead), cancellationToken);
        }
    }

    private void TryDelete(string? path, string? sourceFileName)
    {
        if (string.IsNullOrWhiteSpace(path))
        {
            return;
        }

        try
        {
            if (File.Exists(path))
            {
                File.Delete(path);
            }
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Image preview temp cleanup failed. Operation={Operation} TempFileName={TempFileName} SourceFileNameHash={SourceFileNameHash} ExceptionType={ExceptionType}",
                "delete_temp_preview_input",
                Path.GetFileName(path),
                string.IsNullOrWhiteSpace(sourceFileName) ? "unknown" : TemplateLogSanitizer.SafeFileName(sourceFileName),
                SafeLogValues.ExceptionType(exception));
        }
    }
}
