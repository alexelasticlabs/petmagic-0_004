using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IAppleIdentityTokenVerifier
{
    bool IsConfigured { get; }

    Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(string identityToken, CancellationToken cancellationToken);
}
