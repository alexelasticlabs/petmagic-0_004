using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IGoogleIdentityTokenVerifier
{
    bool IsConfigured { get; }

    string? ClientId { get; }

    Task<Result<ExternalLoginCallbackCommand>> VerifyIdTokenAsync(string idToken, CancellationToken cancellationToken);
}
