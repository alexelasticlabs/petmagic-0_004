using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface IExternalLoginCompletionStore
{
    Task<string> CreateAsync(TokenPairResponse session, CancellationToken cancellationToken);

    Task<TokenPairResponse?> TryTakeAsync(string ticket, CancellationToken cancellationToken);
}

public interface IExternalAccountLinkStore
{
    Task<string> CreateAsync(Guid userId, CancellationToken cancellationToken);

    Task<Guid?> TryTakeAsync(string ticket, CancellationToken cancellationToken);
}
