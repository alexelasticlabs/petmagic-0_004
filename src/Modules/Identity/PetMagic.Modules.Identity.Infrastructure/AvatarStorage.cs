using Microsoft.Extensions.Hosting;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed record AvatarUploadCommand(
    string FileName,
    string ContentType,
    byte[] Content);

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
    public async Task<Result<StoredAvatarResponse>> StoreAsync(AvatarUploadCommand avatar, CancellationToken cancellationToken)
    {
        if (avatar.Content.Length == 0)
        {
            return Result.Failure<StoredAvatarResponse>(IdentityErrors.InvalidAvatarUpload);
        }

        var root = ResolveRootPath();
        Directory.CreateDirectory(root);

        var extension = Path.GetExtension(avatar.FileName);
        var safeName = $"{Guid.NewGuid():N}{extension}";
        var year = DateTime.UtcNow.ToString("yyyy");
        var month = DateTime.UtcNow.ToString("MM");
        var relativePath = Path.Combine("user-avatars", year, month, safeName);
        var physicalPath = Path.Combine(root, year, month, safeName);

        Directory.CreateDirectory(Path.GetDirectoryName(physicalPath)!);
        await File.WriteAllBytesAsync(physicalPath, avatar.Content, cancellationToken);

        var normalizedRelativePath = relativePath.Replace("\\", "/");
        var baseUrl = options.PublicBaseUrl.TrimEnd('/');
        var url = $"{baseUrl}/{normalizedRelativePath}";

        return Result.Success(new StoredAvatarResponse(
            url,
            normalizedRelativePath,
            avatar.FileName,
            avatar.ContentType,
            avatar.Content.LongLength,
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
}
