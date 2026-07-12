using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class EconomyPushOutboxProcessorTests
{
    [Fact]
    public async Task ProcessNextAsync_ShouldRetryTransientFailureThenMarkSent()
    {
        await using var dbContext = CreateDbContext();
        dbContext.PushOutboxMessages.Add(CreateWalletMessage());
        await dbContext.SaveChangesAsync();
        var sender = new QueueDeliverySender(
            PushDeliveryResult.Retry("fcm.transient_error"),
            PushDeliveryResult.Delivered);
        var processor = new EconomyPushOutboxProcessor(
            dbContext,
            sender,
            NullLogger<EconomyPushOutboxProcessor>.Instance);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        var message = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(PushOutboxStatus.Queued, message.Status);
        Assert.Equal(1, message.AttemptCount);
        Assert.Equal("fcm.transient_error", message.LastErrorCode);
        Assert.Null(message.LockId);
        message.NextAttemptAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.Equal(PushOutboxStatus.Sent, message.Status);
        Assert.Equal(2, message.AttemptCount);
        Assert.NotNull(message.SentAtUtc);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldDeadLetterPermanentFailure()
    {
        await using var dbContext = CreateDbContext();
        dbContext.PushOutboxMessages.Add(CreateWalletMessage());
        await dbContext.SaveChangesAsync();
        var sender = new QueueDeliverySender(PushDeliveryResult.PermanentFailure("fcm.request_rejected"));

        Assert.True(await new EconomyPushOutboxProcessor(
            dbContext,
            sender,
            NullLogger<EconomyPushOutboxProcessor>.Instance).ProcessNextAsync(CancellationToken.None));

        var message = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(PushOutboxStatus.DeadLetter, message.Status);
        Assert.Equal("fcm.request_rejected", message.LastErrorCode);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRecoverExhaustedStaleLeaseToDeadLetter()
    {
        await using var dbContext = CreateDbContext();
        var message = CreateWalletMessage();
        message.Status = PushOutboxStatus.Processing;
        message.AttemptCount = PushOutboxPolicy.MaxAttempts;
        message.LockId = Guid.NewGuid();
        message.LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1);
        dbContext.PushOutboxMessages.Add(message);
        await dbContext.SaveChangesAsync();
        var sender = new QueueDeliverySender(PushDeliveryResult.Delivered);

        Assert.True(await new EconomyPushOutboxProcessor(
            dbContext,
            sender,
            NullLogger<EconomyPushOutboxProcessor>.Instance).ProcessNextAsync(CancellationToken.None));

        Assert.Equal(PushOutboxStatus.DeadLetter, message.Status);
        Assert.Equal("push.attempts_exhausted", message.LastErrorCode);
        Assert.Equal(0, sender.DeliveryCount);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldIgnoreStaleCompletionAfterLeaseIsReclaimed()
    {
        var databaseRoot = new InMemoryDatabaseRoot();
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"economy-push-outbox-stale-{Guid.NewGuid():N}", databaseRoot)
            .Options;
        await using (var seedContext = new EconomyDbContext(options))
        {
            seedContext.PushOutboxMessages.Add(CreateWalletMessage());
            await seedContext.SaveChangesAsync();
        }

        await using var firstContext = new EconomyDbContext(options);
        var blockingSender = new BlockingRetryDeliverySender();
        var firstProcessor = new EconomyPushOutboxProcessor(
            firstContext,
            blockingSender,
            NullLogger<EconomyPushOutboxProcessor>.Instance);
        var firstProcessing = firstProcessor.ProcessNextAsync(CancellationToken.None);
        await blockingSender.DeliveryStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));

        await using (var expireContext = new EconomyDbContext(options))
        {
            var claimed = await expireContext.PushOutboxMessages.SingleAsync();
            claimed.LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1);
            await expireContext.SaveChangesAsync();
        }

        await using (var secondContext = new EconomyDbContext(options))
        {
            var secondProcessor = new EconomyPushOutboxProcessor(
                secondContext,
                new QueueDeliverySender(PushDeliveryResult.Delivered),
                NullLogger<EconomyPushOutboxProcessor>.Instance);
            Assert.True(await secondProcessor.ProcessNextAsync(CancellationToken.None));
        }

        blockingSender.Release.TrySetResult();
        Assert.True(await firstProcessing);

        await using var verificationContext = new EconomyDbContext(options);
        var persisted = await verificationContext.PushOutboxMessages.AsNoTracking().SingleAsync();
        Assert.Equal(PushOutboxStatus.Sent, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.Null(persisted.LockId);
        Assert.Null(persisted.LockExpiresAtUtc);
        Assert.Null(persisted.LastErrorCode);
    }

    [Fact]
    public async Task Enqueue_ShouldDeduplicateByBusinessKey()
    {
        await using var dbContext = CreateDbContext();
        var outbox = new EconomyPushNotificationOutbox(
            dbContext,
            Options.Create(new EconomyOptions
            {
                FirebasePushEnabled = true,
                FirebaseProjectId = "petmagic-test",
                FirebaseServiceAccountJson = "{}"
            }));
        var orderId = Guid.NewGuid();
        var notification = new WalletPushNotification("succeeded", orderId, 100);

        await outbox.NotifyWalletUpdateAsync(Guid.NewGuid(), notification, CancellationToken.None);
        await outbox.NotifyWalletUpdateAsync(Guid.NewGuid(), notification, CancellationToken.None);
        await dbContext.SaveChangesAsync();

        Assert.Single(await dbContext.PushOutboxMessages.ToListAsync());
    }

    [Fact]
    public async Task PremiumEnqueue_ShouldKeepSeparateProviderEvents()
    {
        await using var dbContext = CreateDbContext();
        var outbox = new EconomyPushNotificationOutbox(
            dbContext,
            Options.Create(new EconomyOptions
            {
                FirebasePushEnabled = true,
                FirebaseProjectId = "petmagic-test",
                FirebaseServiceAccountJson = "{}"
            }));
        var userId = Guid.NewGuid();

        await outbox.NotifyPremiumUpdateAsync(
            userId,
            new PremiumPushNotification("active", "google_play", "monthly", "event-a"),
            CancellationToken.None);
        await outbox.NotifyPremiumUpdateAsync(
            userId,
            new PremiumPushNotification("active", "google_play", "monthly", "event-b"),
            CancellationToken.None);
        await dbContext.SaveChangesAsync();

        Assert.Equal(2, await dbContext.PushOutboxMessages.CountAsync());
    }

    private static EconomyDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<EconomyDbContext>()
            .UseInMemoryDatabase($"economy-push-outbox-{Guid.NewGuid():N}")
            .Options;
        return new EconomyDbContext(options);
    }

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

    private sealed class QueueDeliverySender(params PushDeliveryResult[] results) : IEconomyPushDeliverySender
    {
        private readonly Queue<PushDeliveryResult> results = new(results);

        public int DeliveryCount { get; private set; }

        public Task<PushDeliveryResult> DeliverWalletUpdateAsync(
            Guid userId,
            WalletPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryCount++;
            return Task.FromResult(results.Dequeue());
        }

        public Task<PushDeliveryResult> DeliverPremiumUpdateAsync(
            Guid userId,
            PremiumPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryCount++;
            return Task.FromResult(results.Dequeue());
        }
    }

    private sealed class BlockingRetryDeliverySender : IEconomyPushDeliverySender
    {
        public TaskCompletionSource DeliveryStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<PushDeliveryResult> DeliverWalletUpdateAsync(
            Guid userId,
            WalletPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryStarted.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return PushDeliveryResult.Retry("first-worker-stale-result");
        }

        public Task<PushDeliveryResult> DeliverPremiumUpdateAsync(
            Guid userId,
            PremiumPushNotification notification,
            CancellationToken cancellationToken) =>
            throw new NotSupportedException();
    }
}
