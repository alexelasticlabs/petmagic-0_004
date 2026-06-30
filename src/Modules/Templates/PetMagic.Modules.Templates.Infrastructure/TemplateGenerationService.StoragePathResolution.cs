namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationService
{
    private string ResolveManagedStoragePathOrUrl(string assetUrl)
    {
        var candidate = assetUrl.Trim().Replace('\\', '/');
        if (candidate.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
        {
            return candidate;
        }

        var localBaseUrl = options.PublicBaseUrl.TrimEnd('/');
        if (!string.IsNullOrWhiteSpace(localBaseUrl)
            && candidate.StartsWith(localBaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            var relativePath = candidate[localBaseUrl.Length..].TrimStart('/');
            if (relativePath.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase))
            {
                return relativePath;
            }
        }

        if (!options.R2.IsConfigured)
        {
            return assetUrl;
        }

        var r2BaseUrl = options.R2.PublicBaseUrl.TrimEnd('/');
        if (!candidate.StartsWith(r2BaseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return assetUrl;
        }

        var storageKey = candidate[r2BaseUrl.Length..].TrimStart('/');
        var objectKeyPrefix = NormalizeObjectKeyPrefix(options.R2.ObjectKeyPrefix);
        return storageKey.StartsWith($"{objectKeyPrefix}/", StringComparison.OrdinalIgnoreCase)
            ? storageKey
            : assetUrl;
    }

    private static string NormalizeObjectKeyPrefix(string prefix)
    {
        var normalized = prefix.Trim().Trim('/').Replace('\\', '/');
        return string.IsNullOrWhiteSpace(normalized) ? "templates-media" : normalized;
    }
}
