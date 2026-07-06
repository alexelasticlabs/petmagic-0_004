using System.Security.Cryptography;
using System.Text;

using PetMagic.BuildingBlocks.Storage;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

public sealed class TemplateMediaReadUrlSigningOptions
{
    public string SigningKey { get; init; } = string.Empty;
}

public interface ITemplateMediaReadUrlSigner
{
    string CreateReadUrl(string assetUrl, TimeSpan ttl);

    bool IsAuthorizedRequest(string requestPath, IReadOnlyDictionary<string, string?> query);
}

public sealed class TemplateMediaReadUrlSigner(
    TemplatesOptions options,
    TemplateMediaReadUrlSigningOptions signingOptions) : ITemplateMediaReadUrlSigner
{
    private const string ExpiresQueryKey = "pmexp";
    private const string ManagedPathSegment = "/templates-media/";
    private const string SignatureQueryKey = "pmsig";

    public string CreateReadUrl(string assetUrl, TimeSpan ttl)
    {
        if (string.IsNullOrWhiteSpace(assetUrl)
            || string.IsNullOrWhiteSpace(signingOptions.SigningKey)
            || !TryBuildManagedPath(assetUrl, out var managedPath))
        {
            return string.Empty;
        }

        var expiresAtUnixSeconds = DateTimeOffset.UtcNow
            .AddSeconds(Math.Max(1, ttl.TotalSeconds))
            .ToUnixTimeSeconds();
        var signature = ComputeSignature(managedPath, expiresAtUnixSeconds);

        var builder = new UriBuilder($"{options.PublicBaseUrl.TrimEnd('/')}{managedPath}")
        {
            Query =
                $"{ExpiresQueryKey}={Uri.EscapeDataString(expiresAtUnixSeconds.ToString())}&{SignatureQueryKey}={Uri.EscapeDataString(signature)}",
            Fragment = string.Empty
        };
        return builder.Uri.ToString();
    }

    public bool IsAuthorizedRequest(string requestPath, IReadOnlyDictionary<string, string?> query)
    {
        if (!TryResolveManagedRequestPath(requestPath, out var managedPath)
            || string.IsNullOrWhiteSpace(signingOptions.SigningKey))
        {
            return false;
        }

        query.TryGetValue(ExpiresQueryKey, out var expiresRaw);
        query.TryGetValue(SignatureQueryKey, out var signatureRaw);
        if (!long.TryParse(expiresRaw, out var expiresAtUnixSeconds)
            || expiresAtUnixSeconds <= DateTimeOffset.UtcNow.ToUnixTimeSeconds()
            || string.IsNullOrWhiteSpace(signatureRaw))
        {
            return false;
        }

        var expectedSignature = ComputeSignature(managedPath, expiresAtUnixSeconds);
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expectedSignature),
            Encoding.UTF8.GetBytes(signatureRaw));
    }

    private bool TryBuildManagedPath(string assetUrl, out string managedPath)
    {
        managedPath = string.Empty;
        var candidate = assetUrl.Trim().Replace('\\', '/');
        var queryIndex = candidate.IndexOfAny(['?', '#']);
        if (queryIndex >= 0)
        {
            candidate = candidate[..queryIndex];
        }

        if (ContainsUnsafePathSegments(candidate))
        {
            return false;
        }

        if (TryNormalizeManagedPath(candidate, out managedPath))
        {
            return true;
        }

        if (!Uri.TryCreate(candidate, UriKind.Absolute, out var uri)
            || !Uri.TryCreate(options.PublicBaseUrl, UriKind.Absolute, out var baseUri)
            || !UriHasSameOrigin(uri, baseUri))
        {
            return false;
        }

        return TryExtractCanonicalManagedPath(uri.AbsolutePath, baseUri.AbsolutePath, out managedPath);
    }

    private bool TryResolveManagedRequestPath(string requestPath, out string managedPath)
    {
        managedPath = string.Empty;
        if (string.IsNullOrWhiteSpace(requestPath) || requestPath.Contains('\\'))
        {
            return false;
        }

        var basePath = Uri.TryCreate(options.PublicBaseUrl, UriKind.Absolute, out var baseUri)
            ? baseUri.AbsolutePath
            : string.Empty;
        return TryExtractCanonicalManagedPath(requestPath.Replace('\\', '/'), basePath, out managedPath);
    }

    private string ComputeSignature(string managedPath, long expiresAtUnixSeconds)
    {
        var payload = $"{managedPath}\n{expiresAtUnixSeconds}";
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(signingOptions.SigningKey));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(payload));
        return Convert.ToHexString(hash);
    }

    private static bool TryExtractCanonicalManagedPath(
        string normalizedPath,
        string? publicBasePath,
        out string managedPath)
    {
        managedPath = string.Empty;
        if (normalizedPath.StartsWith(ManagedPathSegment, StringComparison.OrdinalIgnoreCase))
        {
            return TryNormalizeManagedPath(normalizedPath, out managedPath);
        }

        var normalizedBasePath = NormalizePublicBasePath(publicBasePath);
        if (string.IsNullOrWhiteSpace(normalizedBasePath))
        {
            return false;
        }

        var prefixedManagedPath = $"{normalizedBasePath}{ManagedPathSegment}";
        if (!normalizedPath.StartsWith(prefixedManagedPath, StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        return TryNormalizeManagedPath(normalizedPath[normalizedBasePath.Length..], out managedPath);
    }

    private static bool TryNormalizeManagedPath(string candidate, out string managedPath)
    {
        managedPath = string.Empty;
        var pathOnly = candidate.TrimStart('/');
        if (!pathOnly.StartsWith("templates-media/", StringComparison.OrdinalIgnoreCase)
            || pathOnly.Length <= "templates-media/".Length
            || pathOnly.EndsWith("/", StringComparison.Ordinal))
        {
            return false;
        }

        var segments = pathOnly
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (segments.Length <= 1
            || !string.Equals(segments[0], "templates-media", StringComparison.OrdinalIgnoreCase)
            || segments.Any(IsUnsafePathSegment))
        {
            return false;
        }

        managedPath = $"/{string.Join('/', segments)}";
        return true;
    }

    private static bool IsUnsafePathSegment(string segment)
    {
        return ManagedPathSegments.IsUnsafe(segment);
    }

    private static bool ContainsUnsafePathSegments(string value)
    {
        return value
            .Split('/', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Any(IsUnsafePathSegment);
    }

    private static bool UriHasSameOrigin(Uri uri, Uri baseUri)
    {
        return string.Equals(uri.Scheme, baseUri.Scheme, StringComparison.OrdinalIgnoreCase)
            && string.Equals(uri.Host, baseUri.Host, StringComparison.OrdinalIgnoreCase)
            && uri.Port == baseUri.Port;
    }

    private static string NormalizePublicBasePath(string? publicBasePath)
    {
        if (string.IsNullOrWhiteSpace(publicBasePath) || publicBasePath == "/")
        {
            return string.Empty;
        }

        return publicBasePath.TrimEnd('/');
    }
}
