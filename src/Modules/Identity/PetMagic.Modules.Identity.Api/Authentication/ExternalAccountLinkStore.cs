using Microsoft.Extensions.Caching.Memory;

namespace PetMagic.Modules.Identity.Api.Authentication;

public sealed class ExternalAccountLinkStore(IMemoryCache cache)
{
    private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(5);

    private readonly IMemoryCache _cache = cache;

    public string Create(Guid userId)
    {
        var ticket = Guid.NewGuid().ToString("N");
        _cache.Set(ticket, userId, TicketLifetime);
        return ticket;
    }

    public bool TryTake(string ticket, out Guid userId)
    {
        if (_cache.TryGetValue<Guid>(ticket, out var cachedUserId))
        {
            _cache.Remove(ticket);
            userId = cachedUserId;
            return true;
        }

        userId = Guid.Empty;
        return false;
    }
}
