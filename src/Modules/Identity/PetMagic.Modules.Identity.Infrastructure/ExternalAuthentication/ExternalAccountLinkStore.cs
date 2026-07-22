using System.Text.Json;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure.ExternalAuthentication;

internal sealed class ExternalAccountLinkStore(
    IServiceScopeFactory serviceScopeFactory,
    IDataProtectionProvider dataProtectionProvider) : IExternalAccountLinkStore
{
    private const string Purpose = "external_account_link";
    private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(5);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly IDataProtector _payloadProtector = ExternalAuthTicketPayloadProtection.CreateProtector(
        dataProtectionProvider,
        Purpose);

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
            PayloadJson = ExternalAuthTicketPayloadProtection.ProtectJson(
                _payloadProtector,
                JsonSerializer.Serialize(userId, JsonOptions)),
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

        var payloadJson = ExternalAuthTicketPayloadProtection.UnprotectJsonOrLegacy(
            _payloadProtector,
            persisted.PayloadJson);
        Guid userId;
        try
        {
            userId = JsonSerializer.Deserialize<Guid>(payloadJson, JsonOptions);
        }
        catch (JsonException)
        {
            await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken);
            return null;
        }

        if (userId == Guid.Empty)
        {
            await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken);
            return null;
        }

        return await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken)
            ? userId
            : null;
    }

    private static async Task<bool> TryConsumeAndClearAsync(
        IdentityDbContext dbContext,
        ExternalAuthTicket ticket,
        DateTime consumedAtUtc,
        CancellationToken cancellationToken)
    {
        ticket.ConsumedAtUtc = consumedAtUtc;
        ticket.PayloadJson = "\"\"";
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return true;
        }
        catch (DbUpdateConcurrencyException)
        {
            return false;
        }
    }
}
