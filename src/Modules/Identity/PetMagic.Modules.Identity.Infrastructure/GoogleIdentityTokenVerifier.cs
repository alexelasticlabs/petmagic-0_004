using System.IdentityModel.Tokens.Jwt;

using Google.Apis.Auth;

using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class GoogleIdentityTokenVerifier(
    ExternalAuthOptions options,
    ILogger<GoogleIdentityTokenVerifier> logger) : IGoogleIdentityTokenVerifier
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(options.Google.ClientId) &&
        ResolveAudiences().Count > 0;

    public string? ClientId => IsConfigured ? options.Google.ClientId : null;

    public async Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(string idToken, CancellationToken cancellationToken)
    {
        if (!IsConfigured)
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalProviderNotConfigured);
        }

        if (string.IsNullOrWhiteSpace(idToken))
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
        }

        try
        {
            var audiences = ResolveAudiences();
            var payload = await GoogleJsonWebSignature.ValidateAsync(
                idToken,
                new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = [.. audiences]
                });

            if (!payload.EmailVerified)
            {
                return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalEmailNotVerified);
            }

            return Result.Success(new ExternalLoginCallbackCommand(
                "Google",
                payload.Subject,
                payload.Email,
                payload.Name,
                payload.EmailVerified));
        }
        catch (InvalidJwtException)
        {
            var diagnostic = DiagnoseRejectedToken(idToken, ResolveAudiences());
            logger.LogWarning(
                "Google identity token was rejected. TokenReadable={TokenReadable} AudienceMatchesConfigured={AudienceMatchesConfigured} IssuerIsGoogle={IssuerIsGoogle}",
                diagnostic.TokenReadable,
                diagnostic.AudienceMatchesConfigured,
                diagnostic.IssuerIsGoogle);
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
        }
    }

    private IReadOnlyList<string> ResolveAudiences()
    {
        if (options.Google.Audiences.Length > 0)
        {
            return options.Google.Audiences
                .Where(static x => !string.IsNullOrWhiteSpace(x))
                .Select(static x => x.Trim())
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        return string.IsNullOrWhiteSpace(options.Google.ClientId) ? [] : [options.Google.ClientId];
    }

    private static RejectedGoogleTokenDiagnostic DiagnoseRejectedToken(
        string idToken,
        IReadOnlyCollection<string> configuredAudiences)
    {
        const int maximumDiagnosticTokenLength = 16_384;
        if (idToken.Length > maximumDiagnosticTokenLength)
        {
            return default;
        }

        try
        {
            var token = new JwtSecurityTokenHandler().ReadJwtToken(idToken);
            var audienceMatchesConfigured = token.Audiences.Any(audience =>
                configuredAudiences.Contains(audience, StringComparer.Ordinal));
            var issuerIsGoogle = string.Equals(token.Issuer, "accounts.google.com", StringComparison.Ordinal)
                || string.Equals(token.Issuer, "https://accounts.google.com", StringComparison.Ordinal);

            return new RejectedGoogleTokenDiagnostic(
                TokenReadable: true,
                AudienceMatchesConfigured: audienceMatchesConfigured,
                IssuerIsGoogle: issuerIsGoogle);
        }
        catch (ArgumentException)
        {
            return default;
        }
    }

    private readonly record struct RejectedGoogleTokenDiagnostic(
        bool TokenReadable,
        bool AudienceMatchesConfigured,
        bool IssuerIsGoogle);
}
