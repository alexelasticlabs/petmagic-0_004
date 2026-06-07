using System.Security.Claims;

using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class AppleIdentityTokenVerifier(ExternalAuthOptions options) : IAppleIdentityTokenVerifier
{
    private const string AppleIssuer = "https://appleid.apple.com";
    private static readonly ConfigurationManager<OpenIdConnectConfiguration> ConfigurationManager = new(
        "https://appleid.apple.com/.well-known/openid-configuration",
        new OpenIdConnectConfigurationRetriever());

    public bool IsConfigured => ResolveAudiences().Count > 0;

    public async Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(
        string identityToken,
        CancellationToken cancellationToken)
    {
        if (!IsConfigured)
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalProviderNotConfigured);
        }

        if (string.IsNullOrWhiteSpace(identityToken))
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
        }

        try
        {
            var configuration = await ConfigurationManager.GetConfigurationAsync(cancellationToken);
            var handler = new JsonWebTokenHandler();
            var result = await handler.ValidateTokenAsync(identityToken, new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = AppleIssuer,
                ValidateAudience = true,
                ValidAudiences = ResolveAudiences(),
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = configuration.SigningKeys,
                RequireSignedTokens = true,
                RequireExpirationTime = true,
                ClockSkew = TimeSpan.FromMinutes(1)
            });

            if (!result.IsValid || result.ClaimsIdentity is null)
            {
                return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
            }

            var subject = result.ClaimsIdentity.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? result.ClaimsIdentity.FindFirst("sub")?.Value;
            if (string.IsNullOrWhiteSpace(subject))
            {
                return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
            }

            var email = result.ClaimsIdentity.FindFirst(ClaimTypes.Email)?.Value
                ?? result.ClaimsIdentity.FindFirst("email")?.Value;
            var emailVerifiedValue = result.ClaimsIdentity.FindFirst("email_verified")?.Value;
            var emailVerified = string.Equals(emailVerifiedValue, "true", StringComparison.OrdinalIgnoreCase)
                || string.Equals(emailVerifiedValue, "1", StringComparison.Ordinal);

            return Result.Success(new ExternalLoginCallbackCommand(
                "Apple",
                subject,
                string.IsNullOrWhiteSpace(email) ? null : email,
                null,
                emailVerified));
        }
        catch (Exception) when (
            !cancellationToken.IsCancellationRequested)
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
        }
    }

    private IReadOnlyList<string> ResolveAudiences()
    {
        if (options.Apple.Audiences.Length > 0)
        {
            return options.Apple.Audiences
                .Where(static x => !string.IsNullOrWhiteSpace(x))
                .Select(static x => x.Trim())
                .Distinct(StringComparer.Ordinal)
                .ToArray();
        }

        return string.IsNullOrWhiteSpace(options.Apple.ClientId) ? [] : [options.Apple.ClientId];
    }
}
