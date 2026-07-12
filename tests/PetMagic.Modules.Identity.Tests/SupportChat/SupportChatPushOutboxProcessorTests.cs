using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Infrastructure;
using PetMagic.Modules.SupportChat.Infrastructure.Data;

namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatPushOutboxProcessorTests
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    [Fact]
    public async Task ProcessNextAsync_ShouldRecoverExpiredProcessingLease()
    {
        var databaseRoot = new InMemoryDatabaseRoot();
        var options = CreateOptions(databaseRoot);
        await using var dbContext = new SupportChatDbContext(options);
        var message = CreateMessage(
            PushOutboxStatus.Processing,
            attemptCount: 1,
            lockId: Guid.NewGuid(),
            lockExpiresAtUtc: DateTime.UtcNow.AddMinutes(-1));
        dbContext.PushOutboxMessages.Add(message);
        await dbContext.SaveChangesAsync();
        var sender = new SuccessfulDeliverySender();
        var processor = new SupportChatPushOutboxProcessor(
            dbContext,
            sender,
            NullLogger<SupportChatPushOutboxProcessor>.Instance);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        var persisted = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(PushOutboxStatus.Sent, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.Null(persisted.LockId);
        Assert.Null(persisted.LockExpiresAtUtc);
        Assert.Equal(1, sender.DeliveryCount);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldIgnoreStaleCompletionAfterLeaseIsReclaimed()
    {
        var databaseRoot = new InMemoryDatabaseRoot();
        var options = CreateOptions(databaseRoot);
        await using (var seedContext = new SupportChatDbContext(options))
        {
            seedContext.PushOutboxMessages.Add(CreateMessage(PushOutboxStatus.Queued));
            await seedContext.SaveChangesAsync();
        }

        await using var firstContext = new SupportChatDbContext(options);
        var blockingSender = new BlockingRetryDeliverySender();
        var firstProcessor = new SupportChatPushOutboxProcessor(
            firstContext,
            blockingSender,
            NullLogger<SupportChatPushOutboxProcessor>.Instance);
        var firstProcessing = firstProcessor.ProcessNextAsync(CancellationToken.None);
        await blockingSender.DeliveryStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));

        await using (var expireContext = new SupportChatDbContext(options))
        {
            var claimed = await expireContext.PushOutboxMessages.SingleAsync();
            claimed.LockExpiresAtUtc = DateTime.UtcNow.AddMinutes(-1);
            await expireContext.SaveChangesAsync();
        }

        await using (var secondContext = new SupportChatDbContext(options))
        {
            var secondProcessor = new SupportChatPushOutboxProcessor(
                secondContext,
                new SuccessfulDeliverySender(),
                NullLogger<SupportChatPushOutboxProcessor>.Instance);
            Assert.True(await secondProcessor.ProcessNextAsync(CancellationToken.None));
        }

        blockingSender.Release.TrySetResult();
        Assert.True(await firstProcessing);

        await using var verificationContext = new SupportChatDbContext(options);
        var persisted = await verificationContext.PushOutboxMessages.AsNoTracking().SingleAsync();
        Assert.Equal(PushOutboxStatus.Sent, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.Null(persisted.LockId);
        Assert.Null(persisted.LockExpiresAtUtc);
        Assert.Null(persisted.LastErrorCode);
    }

    private static DbContextOptions<SupportChatDbContext> CreateOptions(InMemoryDatabaseRoot databaseRoot)
    {
        return new DbContextOptionsBuilder<SupportChatDbContext>()
            .UseInMemoryDatabase($"support-push-outbox-tests-{Guid.NewGuid():N}", databaseRoot)
            .Options;
    }

    private static PushOutboxMessage CreateMessage(
        PushOutboxStatus status,
        int attemptCount = 0,
        Guid? lockId = null,
        DateTime? lockExpiresAtUtc = null)
    {
        var now = DateTime.UtcNow;
        var notification = new SupportChatPushNotification(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            HasAttachment: false,
            UserUnreadCount: 1);
        return new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"support_chat:{notification.ConversationId:D}:{notification.MessageId:D}",
            Kind = SupportChatPushNotificationOutbox.UserMessageKind,
            UserId = notification.UserId,
            PayloadJson = JsonSerializer.Serialize(notification, JsonOptions),
            Status = status,
            AttemptCount = attemptCount,
            NextAttemptAtUtc = now.AddMinutes(-1),
            LockId = lockId,
            LockExpiresAtUtc = lockExpiresAtUtc,
            CreatedAtUtc = now.AddMinutes(-2),
            UpdatedAtUtc = now.AddMinutes(-1)
        };
    }

    private sealed class SuccessfulDeliverySender : ISupportChatPushDeliverySender
    {
        public int DeliveryCount { get; private set; }

        public Task<PushDeliveryResult> DeliverUserAsync(
            SupportChatPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryCount++;
            return Task.FromResult(PushDeliveryResult.Delivered);
        }
    }

    private sealed class BlockingRetryDeliverySender : ISupportChatPushDeliverySender
    {
        public TaskCompletionSource DeliveryStarted { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource Release { get; } = new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task<PushDeliveryResult> DeliverUserAsync(
            SupportChatPushNotification notification,
            CancellationToken cancellationToken)
        {
            DeliveryStarted.TrySetResult();
            await Release.Task.WaitAsync(cancellationToken);
            return PushDeliveryResult.Retry("first-worker-stale-result");
        }
    }
}
