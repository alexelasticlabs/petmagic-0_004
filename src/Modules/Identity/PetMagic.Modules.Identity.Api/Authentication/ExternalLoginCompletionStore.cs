using Microsoft.Extensions.Caching.Memory;

using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Api.Authentication;

public sealed class ExternalLoginCompletionStore
{
    private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(2);

    private readonly IMemoryCache _cache;

    public ExternalLoginCompletionStore(IMemoryCache cache)
    {
        _cache = cache;
    }

    public string Create(TokenPairResponse session)
    {
        var ticket = Guid.NewGuid().ToString("N");
        _cache.Set(ticket, session, TicketLifetime);
        return ticket;
    }

    public bool TryTake(string ticket, out TokenPairResponse? session)
    {
        if (_cache.TryGetValue<TokenPairResponse>(ticket, out var cachedSession))
        {
            _cache.Remove(ticket);
            session = cachedSession;
            return true;
        }

        session = null;
        return false;
    }
}
