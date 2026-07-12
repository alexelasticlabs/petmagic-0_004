using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyPushNotificationOutbox(
    EconomyDbContext dbContext,
    IOptions<EconomyOptions> options) : IEconomyPushNotificationSender
{
    internal const string WalletKind = "wallet";
    internal const string PremiumKind = "premium";
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public Task NotifyWalletUpdateAsync(Guid userId, WalletPushNotification notification, CancellationToken cancellationToken)
    {
        var key = notification.OrderId.HasValue
            ? $"wallet:{notification.Status}:{notification.OrderId.Value:D}"
            : $"wallet:{notification.Status}:{userId:D}";
        return EnqueueAsync(key, WalletKind, userId, notification, cancellationToken);
    }

    public Task NotifyPremiumUpdateAsync(Guid userId, PremiumPushNotification notification, CancellationToken cancellationToken)
    {
        var key = $"premium:{notification.Status}:{notification.Provider ?? "unknown"}:{notification.PlanCode ?? "unknown"}:{userId:D}:{notification.EventKey ?? "state"}";
        return EnqueueAsync(key, PremiumKind, userId, notification, cancellationToken);
    }

    private async Task EnqueueAsync<T>(
        string deduplicationKey,
        string kind,
        Guid userId,
        T payload,
        CancellationToken cancellationToken)
    {
        if (!options.Value.IsFirebasePushConfigured)
        {
            return;
        }

        if (dbContext.PushOutboxMessages.Local.Any(x => x.DeduplicationKey == deduplicationKey)
            || await dbContext.PushOutboxMessages.AsNoTracking().AnyAsync(
                x => x.DeduplicationKey == deduplicationKey,
                cancellationToken))
        {
            return;
        }

        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = deduplicationKey,
            Kind = kind,
            UserId = userId,
            PayloadJson = JsonSerializer.Serialize(payload, JsonOptions),
            Status = PushOutboxStatus.Queued,
            AttemptCount = 0,
            NextAttemptAtUtc = now,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
    }
}
