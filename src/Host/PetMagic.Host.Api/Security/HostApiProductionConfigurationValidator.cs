using Microsoft.Extensions.Hosting;

namespace PetMagic.Host.Api.Security;

public static class HostApiProductionConfigurationValidator
{
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

        var host = uri.Host;
        if (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "127.0.0.1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "::1", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "0.0.0.0", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException("Cors:AllowedOrigins must not contain local development origins outside development.");
        }
    }
}
