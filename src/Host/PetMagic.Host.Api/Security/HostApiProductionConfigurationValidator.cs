using System.Net;

using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace PetMagic.Host.Api.Security;

public static class HostApiProductionConfigurationValidator
{
    private const int MinimumJwtSigningKeyLength = 64;
    private static readonly string[] ServerOnlyEnvironmentKeys =
    [
        "STRIPE_SECRET_KEY",
        "STRIPE_WEBHOOK_SECRET",
        "STRIPE_TEST_SECRET_KEY",
        "STRIPE_LIVE_SECRET_KEY",
        "STRIPE_TEST_WEBHOOK_SECRET",
        "STRIPE_LIVE_WEBHOOK_SECRET",
        "FAL_AI_API_KEY",
        "R2_ACCESS_KEY",
        "R2_ACCESS_KEY_ID",
        "R2_SECRET_KEY",
        "GOOGLE_CLIENT_SECRET",
        "APPLE_CLIENT_SECRET",
        "JWT_SIGNING_KEY",
        "BOOTSTRAP_ADMIN_PASSWORD",
        "GOOGLE_PLAY_PRIVATE_KEY_PEM",
        "APP_STORE_SHARED_SECRET",
        "FIREBASE_SERVICE_ACCOUNT_JSON",
        "FIREBASE_SERVICE_ACCOUNT_JSON_PATH",
        "SUPPORT_FIREBASE_SERVICE_ACCOUNT_JSON",
        "SUPPORT_FIREBASE_SERVICE_ACCOUNT_JSON_PATH",
        "ECONOMY_FIREBASE_SERVICE_ACCOUNT_JSON",
        "ECONOMY_FIREBASE_SERVICE_ACCOUNT_JSON_PATH"
    ];

    public static void ValidateDefaultConnectionString(IConfiguration configuration, IHostEnvironment environment)
    {
        if (environment.IsDevelopment())
        {
            return;
        }

        var connectionString = configuration.GetConnectionString("DefaultConnection");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:DefaultConnection must be configured for non-development environments.");
        }

        if (ContainsPlaceholder(connectionString))
        {
            throw new InvalidOperationException(
                "ConnectionStrings:DefaultConnection contains a placeholder value and must be replaced outside development.");
        }
    }

    public static void ValidateJwtSigningKey(IConfiguration configuration, IHostEnvironment environment)
    {
        if (environment.IsDevelopment())
        {
            return;
        }

        var signingKey = configuration["Jwt:SigningKey"];
        if (string.IsNullOrWhiteSpace(signingKey))
        {
            throw new InvalidOperationException(
                "Jwt:SigningKey must be configured for non-development environments.");
        }

        if (ContainsPlaceholder(signingKey))
        {
            throw new InvalidOperationException(
                "Jwt:SigningKey contains a placeholder value and must be replaced outside development.");
        }

        if (signingKey.Length < MinimumJwtSigningKeyLength)
        {
            throw new InvalidOperationException(
                $"Jwt:SigningKey must be at least {MinimumJwtSigningKeyLength} characters outside development.");
        }
    }

    public static void ValidateCorsAllowedOrigins(IReadOnlyCollection<string> allowedOrigins, IHostEnvironment environment)
    {
        if (environment.IsDevelopment())
        {
            return;
        }

        if (allowedOrigins.Count == 0)
        {
            throw new InvalidOperationException(
                "Cors:AllowedOrigins must be configured for non-development environments.");
        }

        foreach (var origin in allowedOrigins)
        {
            ValidateProductionOrigin(origin);
        }
    }

    public static void ValidatePublicMediaBaseUrls(IConfiguration configuration, IHostEnvironment environment)
    {
        if (environment.IsDevelopment())
        {
            return;
        }

        ValidatePublicBaseUrl(
            configuration["Identity:AvatarStorage:PublicBaseUrl"],
            "Identity:AvatarStorage:PublicBaseUrl");
        ValidatePublicBaseUrl(
            configuration["SupportChat:AttachmentStorage:PublicBaseUrl"],
            "SupportChat:AttachmentStorage:PublicBaseUrl");
        ValidatePublicBaseUrl(
            configuration["Templates:PublicBaseUrl"],
            "Templates:PublicBaseUrl");

        var r2PublicBaseUrl = configuration["Templates:R2:PublicBaseUrl"];
        if (!string.IsNullOrWhiteSpace(r2PublicBaseUrl))
        {
            ValidatePublicBaseUrl(r2PublicBaseUrl, "Templates:R2:PublicBaseUrl");
        }
    }

    public static void ValidateNoPublicServerSecrets(IConfiguration configuration, IHostEnvironment environment)
    {
        if (environment.IsDevelopment())
        {
            return;
        }

        var publicServerSecretKeys = configuration
            .AsEnumerable()
            .Select(entry => entry.Key)
            .Where(key => IsPublicServerSecretKey(key))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .Order(StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (publicServerSecretKeys.Length == 0)
        {
            return;
        }

        throw new InvalidOperationException(
            $"Public client configuration must not expose server-only secrets: {string.Join(", ", publicServerSecretKeys)}.");
    }

    private static void ValidateProductionOrigin(string origin)
    {
        if (string.IsNullOrWhiteSpace(origin))
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must not contain empty values outside development.");
        }

        if (origin.Trim() == "*")
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must not contain wildcard origins outside development.");
        }

        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must contain absolute origins outside development.");
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must use HTTPS origins outside development.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo)
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment)
            || uri.AbsolutePath != "/")
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must contain origins only, without paths, query strings, fragments, or credentials outside development.");
        }

        if (IsLocalDevelopmentHost(uri.Host))
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must not contain local development origins outside development.");
        }
    }

    private static void ValidatePublicBaseUrl(string? baseUrl, string settingName)
    {
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            throw new InvalidOperationException($"{settingName} must be configured for non-development environments.");
        }

        if (ContainsPlaceholder(baseUrl))
        {
            throw new InvalidOperationException($"{settingName} contains a placeholder value and must be replaced outside development.");
        }

        if (!Uri.TryCreate(baseUrl, UriKind.Absolute, out var uri))
        {
            throw new InvalidOperationException($"{settingName} must be an absolute URL outside development.");
        }

        if (!string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"{settingName} must use HTTPS outside development.");
        }

        if (!string.IsNullOrEmpty(uri.UserInfo)
            || !string.IsNullOrEmpty(uri.Query)
            || !string.IsNullOrEmpty(uri.Fragment))
        {
            throw new InvalidOperationException($"{settingName} must not contain credentials, query strings, or fragments outside development.");
        }

        if (IsLocalDevelopmentHost(uri.Host))
        {
            throw new InvalidOperationException($"{settingName} must not point to a local development host outside development.");
        }
    }

    private static bool IsLocalDevelopmentHost(string host)
    {
        if (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "0.0.0.0", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "[::]", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "::", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        var normalizedHost = host.Trim('[', ']');
        return IPAddress.TryParse(normalizedHost, out var address) && IPAddress.IsLoopback(address);
    }

    private static bool ContainsPlaceholder(string value) =>
        value.Contains("CHANGE_ME", StringComparison.OrdinalIgnoreCase)
        || value.Contains("REPLACE_WITH", StringComparison.OrdinalIgnoreCase)
        || value.Contains("YOUR_", StringComparison.OrdinalIgnoreCase)
        || value.Contains("<", StringComparison.Ordinal)
        || value.Contains(">", StringComparison.Ordinal);

    private static bool IsPublicServerSecretKey(string key)
    {
        if (!key.StartsWith("NEXT_PUBLIC_", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var serverKeyCandidate = key["NEXT_PUBLIC_".Length..];
        return ServerOnlyEnvironmentKeys.Contains(serverKeyCandidate, StringComparer.OrdinalIgnoreCase);
    }
}
