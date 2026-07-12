using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Infrastructure.ExternalAuthentication;

internal static class ExternalAuthTicketCleanup
{
    private static readonly TimeSpan ConsumedTicketRetention = TimeSpan.FromHours(1);

    public static async Task PruneAsync(
        IdentityDbContext dbContext,
        string purpose,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var consumedCutoff = now.Subtract(ConsumedTicketRetention);
        var expiredTickets = await dbContext.ExternalAuthTickets
            .Where(x => x.Purpose == purpose
                && (x.ExpiresAtUtc <= now || x.ConsumedAtUtc < consumedCutoff))
            .OrderBy(x => x.ExpiresAtUtc)
            .ThenBy(x => x.Ticket)
            .Take(100)
            .ToArrayAsync(cancellationToken);

        if (expiredTickets.Length == 0)
        {
            return;
        }

        dbContext.ExternalAuthTickets.RemoveRange(expiredTickets);
    }
}
