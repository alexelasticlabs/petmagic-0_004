using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Api.Authentication;

public sealed class ExternalAccountLinkStore(IServiceScopeFactory serviceScopeFactory)
{
    private const string Purpose = "external_account_link";
    private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(5);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task<string> CreateAsync(Guid userId, CancellationToken cancellationToken)
    {
        var ticket = Guid.NewGuid().ToString("N");
        var now = DateTime.UtcNow;
        using var scope = serviceScopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
        await ExternalAuthTicketCleanup.PruneAsync(dbContext, Purpose, now, cancellationToken);
        dbContext.ExternalAuthTickets.Add(new ExternalAuthTicket
        {
            Ticket = ticket,
            Purpose = Purpose,
            PayloadJson = JsonSerializer.Serialize(userId, JsonOptions),
            CreatedAtUtc = now,
            ExpiresAtUtc = now.Add(TicketLifetime)
        });
        await dbContext.SaveChangesAsync(cancellationToken);
        return ticket;
    }

    public async Task<Guid?> TryTakeAsync(string ticket, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(ticket))
        {
            return null;
        }

        var now = DateTime.UtcNow;
        using var scope = serviceScopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
        var persisted = await dbContext.ExternalAuthTickets
            .SingleOrDefaultAsync(
                x => x.Ticket == ticket
                    && x.Purpose == Purpose
                    && x.ConsumedAtUtc == null
                    && x.ExpiresAtUtc > now,
                cancellationToken);

        if (persisted is null)
        {
            return null;
        }

        persisted.ConsumedAtUtc = now;
        await dbContext.SaveChangesAsync(cancellationToken);
        return JsonSerializer.Deserialize<Guid>(persisted.PayloadJson, JsonOptions);
    }
}
