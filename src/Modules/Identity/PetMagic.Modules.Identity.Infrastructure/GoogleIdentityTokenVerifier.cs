using Google.Apis.Auth;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class GoogleIdentityTokenVerifier(ExternalAuthOptions options) : IGoogleIdentityTokenVerifier
{
    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(options.Google.ClientId) &&
        !string.IsNullOrWhiteSpace(options.Google.ClientSecret);

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
            var payload = await GoogleJsonWebSignature.ValidateAsync(
                idToken,
                new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = [options.Google.ClientId]
                });

            return Result.Success(new ExternalLoginCallbackCommand(
                "Google",
                payload.Subject,
                payload.Email,
                payload.Name));
        }
        catch (InvalidJwtException)
        {
            return Result.Failure<ExternalLoginCallbackCommand>(IdentityErrors.ExternalTokenInvalid);
        }
    }
}