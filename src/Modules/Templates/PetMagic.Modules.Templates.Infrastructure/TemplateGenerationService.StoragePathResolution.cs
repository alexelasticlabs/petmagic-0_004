using PetMagic.BuildingBlocks.Storage;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private string ResolveManagedStoragePathOrUrl(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        if (TryNormalizeManagedStoragePath(candidate, "templates-media", out var managedPath)
            || (options.R2.IsConfigured
                && TryNormalizeManagedStoragePath(candidate, NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix), out managedPath)))
        {
            return managedPath;
        }

        var localBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(localBaseUrl)
            && candidate.StartsWith(localBaseUrl, StringComparison.OrdinalIgnoreCase)
            && candidate.Length > localBaseUrl.Length
            && candidate[localBaseUrl.Length] == '/')
        {
            var relativePath = candidate[localBaseUrl.Length..].TrimStart('/');
            if (TryNormalizeManagedStoragePath(relativePath, "templates-media", out managedPath))
            {
                return managedPath;
            }
        }

        if (!options.R2.IsConfigured)
        {
            return assetUrl;
        }

        var r2BaseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(r2BaseUrl, StringComparison.OrdinalIgnoreCase)
            || candidate.Length <= r2BaseUrl.Length
            || candidate[r2BaseUrl.Length] != '/')
        {
            return assetUrl;
        }

        var storageKey = candidate[r2BaseUrl.Length..].TrimStart('/');
        var objectKeyPrefix = NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix);
        return TryNormalizeManagedStoragePath(storageKey, objectKeyPrefix, out managedPath)
            ? managedPath
            : assetUrl;
    }

    private static bool TryNormalizeManagedStoragePath(string candidate, string prefix, out string managedPath)
    {
        managedPath = string.Empty;
        var pathOnly = candidate.TrimStart('/');
        var queryIndex = pathOnly.IndexOfAny(['?', '#']);
        if (queryIndex >= 0)
        {
            pathOnly = pathOnly[..queryIndex];
        }

        if (string.IsNullOrWhiteSpace(pathOnly)
            || pathOnly.EndsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var segments = pathOnly
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Any(IsUnsafeManagedStoragePathSegment))
        {
            return false;
        }

        var normalized = string.Join('/', segments);
        if (!normalized.StartsWith($"{prefix}/", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        managedPath = normalized;
        return true;
    }

    private static bool IsUnsafeManagedStoragePathSegment(string segment)
    {
        return ManagedPathSegments.IsUnsafe(segment);
    }

    private static string NormalizeObjectKeyPrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }
}
