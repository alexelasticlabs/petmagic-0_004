using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class PushOutboxPostgresConcurrencyTests
{
    [Fact]
    public async Task ConcurrentProcessors_ShouldNotClaimAnActiveLeaseTwice()
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        var message = CreateWalletMessage();

        await using (var seedContext = new EconomyDbContext(options))
        {
            seedContext.PushOutboxMessages.Add(message);
            await seedContext.SaveChangesAsync();
        }

        var sender = new BlockingDeliverySender();
        try
        {
            await using var firstContext = new EconomyDbContext(options);
            await using var secondContext = new EconomyDbContext(options);
            var firstProcessor = CreateProcessor(firstContext, sender);
            var secondProcessor = CreateProcessor(secondContext, sender);

            var firstRun = firstProcessor.ProcessNextAsync(CancellationToken.None);
            await sender.Entered.Task.WaitAsync(TimeSpan.FromSeconds(10));

            Assert.False(await secondProcessor.ProcessNextAsync(CancellationToken.None));
            Assert.Equal(1, sender.DeliveryCount);

            sender.Release.TrySetResult();
            Assert.True(await firstRun);

            await using var verificationContext = new EconomyDbContext(options);
            var persisted = await verificationContext.PushOutboxMessages
                .AsNoTracking()
                .SingleAsync(x => x.Id == message.Id);
            Assert.Equal(PushOutboxStatus.Sent, persisted.Status);
            Assert.Equal(1, persisted.AttemptCount);
        }
        finally
        {
            sender.Release.TrySetResult();
            await using var cleanupContext = new EconomyDbContext(options);
            await cleanupContext.PushOutboxMessages
                .Where(x => x.Id == message.Id)
                .ExecuteDeleteAsync();
        }
    }

    [Fact]
    public async Task StaleLeaseOwner_ShouldNotOverwriteNewOwnerSettlement()
    {
        var connectionString = Environment.GetEnvironmentVariable("PETMAGIC_POSTGRES_INTEGRATION_CONNECTION_STRING");
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseNpgsql(connectionString)
            .Options;
        var message = CreateWalletMessage();
        message.Status = PushOutboxStatus.Processing;
        message.LockId = Guid.NewGuid();
        message.LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(2);

        await using (var seedContext = new EconomyDbContext(options))
        {
            seedContext.PushOutboxMessages.Add(message);
            await seedContext.SaveChangesAsync();
        }

        try
        {
            await using var staleOwnerContext = new EconomyDbContext(options);
            var staleOwner = await staleOwnerContext.PushOutboxMessages.SingleAsync(x => x.Id == message.Id);
            var newLockId = Guid.NewGuid();

            await using (var newOwnerContext = new EconomyDbContext(options))
            {
                await newOwnerContext.PushOutboxMessages
                    .Where(x => x.Id == message.Id)
                    .ExecuteUpdateAsync(setters => setters
                        .SetProperty(x => x.LockId, newLockId)
                        .SetProperty(x => x.LockExpiresAtUtc, DateTime.UtcNow.AddMinutes(2)));
            }

            staleOwner.Status = PushOutboxStatus.Sent;
            staleOwner.LockId = null;
            staleOwner.LockExpiresAtUtc = null;
            staleOwner.SentAtUtc = DateTime.UtcNow;

            await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => staleOwnerContext.SaveChangesAsync());

            await using var verificationContext = new EconomyDbContext(options);
            var persisted = await verificationContext.PushOutboxMessages
                .AsNoTracking()
                .SingleAsync(x => x.Id == message.Id);
            Assert.Equal(PushOutboxStatus.Processing, persisted.Status);
            Assert.Equal(newLockId, persisted.LockId);
        }
        finally
        {
            await using var cleanupContext = new EconomyDbContext(options);
            await cleanupContext.PushOutboxMessages
                .Where(x => x.Id == message.Id)
                .ExecuteDeleteAsync();
        }
    }

    private static EconomyPushOutboxProcessor CreateProcessor(
        EconomyDbContext dbContext,
        IEconomyPushDeliverySender sender) =>
        new(dbContext, sender, NullLogger<EconomyPushOutboxProcessor>.Instance);

    private static PushOutboxMessage CreateWalletMessage()
    {
        var now = DateTime.UtcNow;
        return new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"wallet:succeeded:{Guid.NewGuid():D}",
            Kind = EconomyPushNotificationOutbox.WalletKind,
            UserId = Guid.NewGuid(),
            PayloadJson = JsonSerializer.Serialize(
                new WalletPushNotification("succeeded", Guid.NewGuid(), 100),
                new JsonSerializerOptions(JsonSerializerDefaults.Web)),
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now.AddSeconds(-1),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };
    }

    private sealed class BlockingDeliverySender : IEconomyPushDeliverySender
    {
        public TaskCompletionSource Entered { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public int DeliveryCount { get; private set; }

        public async Task<PushDeliveryResult> DeliverWalletUpdateAsync(
            Guid userId,
            WalletPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryCount++;
            Entered.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return PushDeliveryResult.Delivered;
        }

        public Task<PushDeliveryResult> DeliverPremiumUpdateAsync(
            Guid userId,
            PremiumPushNotification notification,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}
