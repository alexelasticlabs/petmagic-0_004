using System.Net;
using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.BuildingBlocks.Observability;
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

    [Fact]
    public async Task ProcessNextAsync_ShouldDeliverAdminAuditIdempotentlyWithCapturedContext()
    {
        await using var dbContext = CreateDbContext();
        var eventId = Guid.NewGuid();
        var actorUserId = Guid.NewGuid();
        var occurredAtUtc = DateTime.UtcNow.AddMinutes(-1);
        var auditEntry = new AdminAuditEntry(
            "admin.economy.redeem_code.updated",
            "redeem_code",
            Guid.NewGuid().ToString("D"),
            null,
            "{\"rewardValue\":50}",
            "Redeem code updated.",
            EventId: eventId,
            ActorUserId: actorUserId,
            CorrelationId: "audit-correlation-1")
        {
            ActorRole = "admin",
            IpAddress = "203.0.113.20",
            UserAgent = "PetMagic audit test",
            OccurredAtUtc = occurredAtUtc
        };
        dbContext.PushOutboxMessages.AddRange(
            CreateAdminAuditMessage(auditEntry, "first"),
            CreateAdminAuditMessage(auditEntry, "replay"));
        await dbContext.SaveChangesAsync();

        var auditLog = new IdempotentRecordingAdminAuditLog();
        var pushSender = new QueueDeliverySender();
        var processor = new EconomyPushOutboxProcessor(
            dbContext,
            pushSender,
            NullLogger<EconomyPushOutboxProcessor>.Instance,
            auditLog);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        var delivered = Assert.Single(auditLog.Entries);
        Assert.Equal(eventId, delivered.EventId);
        Assert.Equal(actorUserId, delivered.ActorUserId);
        Assert.Equal("admin", delivered.ActorRole);
        Assert.Equal("203.0.113.20", delivered.IpAddress);
        Assert.Equal("PetMagic audit test", delivered.UserAgent);
        Assert.Equal("audit-correlation-1", delivered.CorrelationId);
        Assert.Equal(occurredAtUtc, delivered.OccurredAtUtc);
        Assert.Equal(0, pushSender.DeliveryCount);
        Assert.All(
            await dbContext.PushOutboxMessages.ToListAsync(),
            message => Assert.Equal(PushOutboxStatus.Sent, message.Status));
    }

    [Fact]
    public async Task EnqueueAdminAudit_ShouldCaptureRequestContextBeforeMutationSave()
    {
        await using var dbContext = CreateDbContext();
        var actorUserId = Guid.NewGuid();
        var httpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity(
            [
                new Claim("sub", actorUserId.ToString("D")),
                new Claim(ClaimTypes.Role, "support"),
                new Claim(ClaimTypes.Role, "admin")
            ],
            "test"))
        };
        httpContext.Connection.RemoteIpAddress = IPAddress.Parse("203.0.113.21");
        httpContext.Request.Headers.UserAgent = "PetMagicAdmin/2.0";
        var requestStartedAtUtc = DateTime.UtcNow;

        EconomyAdminAuditOutbox.PendingAdminAudit pending;
        using (CorrelationContext.Push("economy-audit-context"))
        {
            pending = new EconomyAdminAuditOutbox(
                dbContext,
                httpContextAccessor: new HttpContextAccessor { HttpContext = httpContext })
                .Enqueue(new AdminAuditEntry(
                    "admin.economy.currency_pack.updated",
                    "currency_pack",
                    Guid.NewGuid().ToString("D")));
        }

        Assert.Equal(actorUserId, pending.Entry.ActorUserId);
        Assert.Equal("admin,support", pending.Entry.ActorRole);
        Assert.Equal("203.0.113.21", pending.Entry.IpAddress);
        Assert.Equal("PetMagicAdmin/2.0", pending.Entry.UserAgent);
        Assert.Equal("economy-audit-context", pending.Entry.CorrelationId);
        Assert.NotNull(pending.Entry.EventId);
        Assert.NotEqual(Guid.Empty, pending.Entry.EventId!.Value);
        Assert.NotNull(pending.Entry.OccurredAtUtc);
        Assert.InRange(pending.Entry.OccurredAtUtc!.Value, requestStartedAtUtc, DateTime.UtcNow);
        Assert.Equal($"admin-audit:{pending.Entry.EventId.Value:D}", pending.Message.DeduplicationKey);
        Assert.Equal(PushOutboxStatus.Queued, pending.Message.Status);

        await dbContext.SaveChangesAsync();
        Assert.Single(await dbContext.PushOutboxMessages.AsNoTracking().ToListAsync());
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldRetryAuditDeliveryFailureWithoutChangingEventId()
    {
        await using var dbContext = CreateDbContext();
        var eventId = Guid.NewGuid();
        dbContext.PushOutboxMessages.Add(CreateAdminAuditMessage(
            new AdminAuditEntry(
                "admin.economy.currency_pack.updated",
                "currency_pack",
                Guid.NewGuid().ToString("D"),
                EventId: eventId),
            "retry"));
        await dbContext.SaveChangesAsync();
        var auditLog = new FailingOnceAdminAuditLog();
        var processor = new EconomyPushOutboxProcessor(
            dbContext,
            new QueueDeliverySender(),
            NullLogger<EconomyPushOutboxProcessor>.Instance,
            auditLog);

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        var message = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(PushOutboxStatus.Queued, message.Status);
        Assert.Equal("audit.delivery_failed", message.LastErrorCode);
        Assert.Equal(1, message.AttemptCount);

        message.NextAttemptAtUtc = DateTime.UtcNow.AddSeconds(-1);
        await dbContext.SaveChangesAsync();
        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));

        Assert.Equal(PushOutboxStatus.Sent, message.Status);
        Assert.Equal(eventId, Assert.Single(auditLog.Entries).EventId);
    }

    [Fact]
    public async Task ProcessNextAsync_ShouldDeadLetterMalformedAdminAuditPayload()
    {
        await using var dbContext = CreateDbContext();
        var now = DateTime.UtcNow;
        dbContext.PushOutboxMessages.Add(new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"admin-audit:malformed:{Guid.NewGuid():N}",
            Kind = EconomyAdminAuditOutbox.Kind,
            UserId = Guid.Empty,
            PayloadJson = "{not-json",
            Status = PushOutboxStatus.Queued,
            NextAttemptAtUtc = now.AddSeconds(-1),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        });
        await dbContext.SaveChangesAsync();

        Assert.True(await new EconomyPushOutboxProcessor(
            dbContext,
            new QueueDeliverySender(),
            NullLogger<EconomyPushOutboxProcessor>.Instance,
            new IdempotentRecordingAdminAuditLog()).ProcessNextAsync(CancellationToken.None));

        var message = await dbContext.PushOutboxMessages.SingleAsync();
        Assert.Equal(PushOutboxStatus.DeadLetter, message.Status);
        Assert.Equal("audit.payload_invalid", message.LastErrorCode);
    }

    [Fact]
    public async Task ProcessNextAsync_WithoutFirebase_ShouldProcessAuditAndLeavePushQueued()
    {
        await using var dbContext = CreateDbContext();
        var walletMessage = CreateWalletMessage();
        walletMessage.CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2);
        dbContext.PushOutboxMessages.Add(walletMessage);
        dbContext.PushOutboxMessages.Add(CreateAdminAuditMessage(
            new AdminAuditEntry(
                "admin.economy.subscription_plan.updated",
                "subscription_plan",
                "premium-monthly",
                EventId: Guid.NewGuid()),
            "no-firebase"));
        await dbContext.SaveChangesAsync();
        var auditLog = new IdempotentRecordingAdminAuditLog();
        var pushSender = new QueueDeliverySender(PushDeliveryResult.Delivered);
        var processor = new EconomyPushOutboxProcessor(
            dbContext,
            pushSender,
            NullLogger<EconomyPushOutboxProcessor>.Instance,
            auditLog,
            Options.Create(new EconomyOptions()));

        Assert.True(await processor.ProcessNextAsync(CancellationToken.None));
        Assert.False(await processor.ProcessNextAsync(CancellationToken.None));

        Assert.Single(auditLog.Entries);
        Assert.Equal(0, pushSender.DeliveryCount);
        Assert.Equal(PushOutboxStatus.Queued, walletMessage.Status);
        Assert.Equal(0, walletMessage.AttemptCount);
    }

    [Fact]
    public async Task ProcessNextAsync_WithoutAuditSink_ShouldLeaveAuditQueuedForCapableHost()
    {
        await using var dbContext = CreateDbContext();
        var auditMessage = CreateAdminAuditMessage(
            new AdminAuditEntry(
                "admin.economy.currency_pack.updated",
                "currency_pack",
                Guid.NewGuid().ToString("D"),
                EventId: Guid.NewGuid()),
            "sink-unavailable");
        dbContext.PushOutboxMessages.Add(auditMessage);
        await dbContext.SaveChangesAsync();
        var processor = new EconomyPushOutboxProcessor(
            dbContext,
            new QueueDeliverySender(),
            NullLogger<EconomyPushOutboxProcessor>.Instance,
            adminAuditLog: null,
            economyOptions: Options.Create(new EconomyOptions()));

        Assert.False(await processor.ProcessNextAsync(CancellationToken.None));

        Assert.Equal(PushOutboxStatus.Queued, auditMessage.Status);
        Assert.Equal(0, auditMessage.AttemptCount);
        Assert.Null(auditMessage.LastErrorCode);
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

    private static PushOutboxMessage CreateAdminAuditMessage(AdminAuditEntry entry, string uniqueSuffix)
    {
        var now = DateTime.UtcNow;
        return new PushOutboxMessage
        {
            Id = Guid.NewGuid(),
            DeduplicationKey = $"admin-audit:{entry.EventId:D}:{uniqueSuffix}",
            Kind = EconomyAdminAuditOutbox.Kind,
            UserId = entry.ActorUserId ?? entry.SubjectUserId ?? Guid.Empty,
            PayloadJson = JsonSerializer.Serialize(
                entry,
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

    private sealed class IdempotentRecordingAdminAuditLog : IAdminAuditLog
    {
        private readonly HashSet<Guid> deliveredEventIds = [];

        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            if (entry.EventId.HasValue && deliveredEventIds.Add(entry.EventId.Value))
            {
                Entries.Add(entry);
            }

            return Task.CompletedTask;
        }
    }

    private sealed class FailingOnceAdminAuditLog : IAdminAuditLog
    {
        private bool shouldFail = true;

        public List<AdminAuditEntry> Entries { get; } = [];

        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            if (shouldFail)
            {
                shouldFail = false;
                throw new InvalidOperationException("Simulated central audit outage.");
            }

            Entries.Add(entry);
            return Task.CompletedTask;
        }
    }
}
