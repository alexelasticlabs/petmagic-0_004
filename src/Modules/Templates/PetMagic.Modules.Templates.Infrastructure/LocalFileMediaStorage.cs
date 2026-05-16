using Microsoft.Extensions.Hosting;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class LocalFileMediaStorage(TemplatesOptions options, IHostEnvironment hostEnvironment) : IMediaStorage
{
    public async Task<Result<StoredMediaResponse>> StoreAsync(MediaUploadCommand asset, CancellationToken cancellationToken)
    {
        if (asset.Content.Length == 0)
        {
            return Result.Failure<StoredMediaResponse>(TemplatesErrors.InvalidMediaUpload);
        }

        var root = Path.IsPathRooted(options.LocalMediaRootPath)
            ? options.LocalMediaRootPath
            : Path.Combine(hostEnvironment.ContentRootPath, options.LocalMediaRootPath);

        Directory.CreateDirectory(root);

        var extension = Path.GetExtension(asset.FileName);
        var safeName = $"{Guid.NewGuid():N}{extension}";
        var relativePath = Path.Combine("templates-media", DateTime.UtcNow.ToString("yyyy"), DateTime.UtcNow.ToString("MM"), safeName);
        var physicalPath = Path.Combine(root, DateTime.UtcNow.ToString("yyyy"), DateTime.UtcNow.ToString("MM"), safeName);

        Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);
        await File.WriteAllBytesAsync(physicalPath, asset.Content, cancellationToken);

        var normalizedRelativePath = relativePath.Replace("\\", "/");
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        var url = $"{baseUrl}/{normalizedRelativePath}";

        return Result.Success(new StoredMediaResponse(url, normalizedRelativePath, asset.FileName, asset.ContentType, asset.Content.LongLength, physicalPath));
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

    private string? TryResolveManagedRelativePath(string assetUrl)
    {
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!assetUrl.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = assetUrl[baseUrl.Length..].TrimStart('/');
        if (!relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return relativePath.Replace('\\', '/');
    }
}
