using System.Text.Json;

using Microsoft.AspNetCore.DataProtection;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure.ExternalAuthentication;

internal sealed class ExternalLoginCompletionStore(
    IServiceScopeFactory serviceScopeFactory,
    IDataProtectionProvider dataProtectionProvider) : IExternalLoginCompletionStore
{
    private const string Purpose = "external_login_completion";
    private static readonly TimeSpan TicketLifetime = TimeSpan.FromMinutes(2);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private readonly IDataProtector _payloadProtector = ExternalAuthTicketPayloadProtection.CreateProtector(
        dataProtectionProvider,
        Purpose);

    public async Task<string> CreateAsync(TokenPairResponse session, CancellationToken cancellationToken)
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
                JsonSerializer.Serialize(session, JsonOptions)),
            CreatedAtUtc = now,
            ExpiresAtUtc = now.Add(TicketLifetime)
        });
        await dbContext.SaveChangesAsync(cancellationToken);
        return ticket;
    }

    public async Task<TokenPairResponse?> TryTakeAsync(string ticket, CancellationToken cancellationToken)
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
        TokenPairResponse? session;
        try
        {
            session = JsonSerializer.Deserialize<TokenPairResponse>(payloadJson, JsonOptions);
        }
        catch (JsonException)
        {
            await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken);
            return null;
        }

        if (session is null)
        {
            await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken);
            return null;
        }

        return await TryConsumeAndClearAsync(dbContext, persisted, now, cancellationToken)
            ? session
            : null;
    }

    private static async Task<bool> TryConsumeAndClearAsync(
        IdentityDbContext dbContext,
        ExternalAuthTicket ticket,
        DateTime consumedAtUtc,
        CancellationToken cancellationToken)
    {
        ticket.ConsumedAtUtc = consumedAtUtc;
        ticket.PayloadJson = "{}";
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
