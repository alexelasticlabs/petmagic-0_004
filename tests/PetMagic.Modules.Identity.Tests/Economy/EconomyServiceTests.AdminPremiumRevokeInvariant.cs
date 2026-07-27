using Microsoft.EntityFrameworkCore;

using System.Text.Json;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed partial class EconomyServiceTests
{
    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldFailClosedWithoutSubscription()
    {
        await using var dbContext = CreateDbContext();
        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };

        var result = await CreateService(
                dbContext,
                identityService: identityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    Guid.NewGuid(),
                    "stripe",
                    "Verified administrative cancellation."),
                CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumSubscriptionNotCancellable.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Empty(dbContext.SubscriptionEventLogs);
    }

    [Theory]
    [InlineData("Expired", 20)]
    [InlineData("Canceled", 20)]
    [InlineData("GracePeriod", 20)]
    [InlineData("PastDue", 20)]
    [InlineData("Active", -1)]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldFailClosedForNonCancellableStatus(
        string status,
        int periodEndOffsetDays)
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(
            userId,
            status: status,
            currentPeriodEndUtc: DateTime.UtcNow.AddDays(periodEndOffsetDays));
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var result = await CreateService(
                dbContext,
                identityService: identityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Verified administrative cancellation."),
                CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumSubscriptionNotCancellable.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Equal(status, subscription.Status);
        Assert.Empty(await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldNotRevokeStoreManagedPremium()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var stripeSubscription = CreateAdminRevokeTestSubscription(
            userId,
            currentPeriodEndUtc: now.AddDays(20));
        var storeSubscription = CreateAdminRevokeTestSubscription(
            userId,
            provider: "app_store",
            currentPeriodEndUtc: now.AddDays(40));
        dbContext.UserSubscriptions.AddRange(stripeSubscription, storeSubscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var result = await CreateService(dbContext, identityService: identityService)
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Verified administrative cancellation."),
                CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumSubscriptionNotCancellable.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.Equal("Active", stripeSubscription.Status);
        Assert.Equal("Active", storeSubscription.Status);
        Assert.Empty(await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldRecheckCancellationStateAfterSummaryRead()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var service = CreateService(dbContext, identityService: identityService);
        var initialSummary = await service.GetSubscriptionSummaryAsync(userId, CancellationToken.None);

        Assert.True(initialSummary.IsSuccess);
        Assert.True(initialSummary.Value.IsPremium);
        Assert.False(initialSummary.Value.CancelAtPeriodEnd);
        Assert.Empty(identityService.SetPremiumStatusCalls);

        subscription.CancelAtPeriodEnd = true;
        subscription.UpdatedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync();

        var result = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(
                userId,
                "stripe",
                "Verified administrative cancellation."),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.PremiumSubscriptionNotCancellable.Code, result.Error.Code);
        Assert.Empty(identityService.SetPremiumStatusCalls);
        Assert.True(subscription.CancelAtPeriodEnd);
        Assert.Equal("Active", subscription.Status);
        Assert.Empty(await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldAllowTrialingStripeSubscription()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId, status: "Trialing");
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var result = await CreateService(
                dbContext,
                identityService: identityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Verified administrative cancellation."),
                CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure");
        Assert.Single(identityService.SetPremiumStatusCalls);
        Assert.False(identityService.SetPremiumStatusCalls[0].IsPremium);
        Assert.Equal("Expired", subscription.Status);
        Assert.Single(await dbContext.SubscriptionEventLogs.Where(x => x.UserId == userId).ToListAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldPreserveRemainingStoreEntitlement()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        var stripeSubscription = CreateAdminRevokeTestSubscription(
            userId,
            currentPeriodEndUtc: now.AddDays(40));
        var storeSubscription = CreateAdminRevokeTestSubscription(
            userId,
            provider: "google_play",
            currentPeriodEndUtc: now.AddDays(20));
        dbContext.UserSubscriptions.AddRange(stripeSubscription, storeSubscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true
        };
        var result = await CreateService(
                dbContext,
                identityService: identityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Verified administrative cancellation."),
                CancellationToken.None);

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure");
        Assert.True(result.Value.IsPremium);
        Assert.Equal("google_play", result.Value.Provider);
        Assert.DoesNotContain(identityService.SetPremiumStatusCalls, call => !call.IsPremium);
        Assert.Equal("Expired", stripeSubscription.Status);
        Assert.Equal("Active", storeSubscription.Status);
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldRequireAuditReason()
    {
        await using var dbContext = CreateDbContext();
        var subscription = CreateAdminRevokeTestSubscription(Guid.NewGuid());
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var result = await CreateService(
                dbContext,
                identityService: new FakeIdentityService(),
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    subscription.UserId,
                    "stripe",
                    "   "),
                CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.AdminPremiumRevokeReasonRequired.Code, result.Error.Code);
        Assert.Equal("Active", subscription.Status);
        Assert.Empty(await dbContext.SubscriptionEventLogs.ToListAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldBeIdempotentAndPersistAuditAndExpiry()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var reason = new string('r', 500);
        var identityService = new FakeIdentityService { CurrentUserIsPremium = true };
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(
            dbContext,
            identityService: identityService,
            adminAuditLog: auditLog);
        var before = DateTime.UtcNow;

        var first = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(userId, "stripe", reason),
            CancellationToken.None);
        var second = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(userId, "stripe", reason),
            CancellationToken.None);

        Assert.True(first.IsSuccess);
        Assert.True(second.IsSuccess);
        Assert.Equal("Expired", subscription.Status);
        Assert.NotNull(subscription.ExpiredAtUtc);
        Assert.NotNull(subscription.CancelledAtUtc);
        Assert.InRange(subscription.ExpiredAtUtc.Value, before, DateTime.UtcNow);
        Assert.InRange(subscription.CancelledAtUtc.Value, before, DateTime.UtcNow);
        Assert.Single(identityService.SetPremiumStatusCalls);

        var operation = Assert.Single(
            await dbContext.SubscriptionEventLogs
                .Where(x => x.UserId == userId && x.EventType == "AdminImmediateCancelRequested")
                .ToListAsync());
        Assert.Equal("Completed", operation.Status);
        Assert.NotNull(operation.ProcessedAtUtc);
        Assert.Contains(reason, operation.PayloadJson ?? string.Empty);

        Assert.Equal(2, auditLog.Entries.Count);
        Assert.All(auditLog.Entries, entry =>
        {
            using var details = JsonDocument.Parse(entry.Details ?? "{}");
            Assert.Equal(reason, details.RootElement.GetProperty("reason").GetString());
            Assert.Equal("stripe", details.RootElement.GetProperty("provider").GetString());
            Assert.False(string.IsNullOrWhiteSpace(
                details.RootElement.GetProperty("operation").GetString()));
            Assert.NotNull(entry.EventId);
        });
        Assert.Equal(2, auditLog.Entries.Select(x => x.EventId).Distinct().Count());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldCreateNewOperationAfterSameRowReactivation()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService { CurrentUserIsPremium = true };
        var auditLog = new RecordingAdminAuditLog();
        var service = CreateService(
            dbContext,
            identityService: identityService,
            adminAuditLog: auditLog);
        var first = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(
                userId,
                "stripe",
                "First verified revocation."),
            CancellationToken.None);
        Assert.True(first.IsSuccess);

        dbContext.ChangeTracker.Clear();
        var reactivated = await dbContext.UserSubscriptions.SingleAsync(x => x.Id == subscription.Id);
        reactivated.Status = "Active";
        reactivated.ExpiredAtUtc = null;
        reactivated.CancelledAtUtc = null;
        reactivated.CurrentPeriodEndUtc = DateTime.UtcNow.AddDays(30);
        reactivated.UpdatedAtUtc = DateTime.UtcNow.AddSeconds(1);
        await dbContext.SaveChangesAsync();
        identityService.CurrentUserIsPremium = true;

        var second = await service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(
                userId,
                "stripe",
                "Second verified revocation after reactivation."),
            CancellationToken.None);

        Assert.True(second.IsSuccess);
        var operations = await dbContext.SubscriptionEventLogs
            .Where(x => x.UserId == userId && x.EventType == "AdminImmediateCancelRequested")
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync();
        Assert.Equal(2, operations.Count);
        Assert.All(operations, operation => Assert.Equal("Completed", operation.Status));
        Assert.Equal(2, operations.Select(x => x.Id).Distinct().Count());
        Assert.Equal(4, auditLog.Entries.Select(x => x.EventId).Distinct().Count());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldResumePendingBeforeNewerCompletedOperation()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId, status: "Expired");
        subscription.ExpiredAtUtc = DateTime.UtcNow;
        subscription.CurrentPeriodEndUtc = DateTime.UtcNow;
        var pendingOperation = new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscription.Id,
            Provider = "stripe",
            EventType = "AdminImmediateCancelRequested",
            Status = "EconomyApplied",
            ExternalEventId = $"admin-premium-revoke:{subscription.Id:D}:attempt:1",
            PayloadJson = JsonSerializer.Serialize(new
            {
                reason = "Original pending reason.",
                previousStatus = "Active",
                stage = "EconomyApplied"
            }),
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-2)
        };
        var completedOperation = new SubscriptionEventLog
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            UserSubscriptionId = subscription.Id,
            Provider = "stripe",
            EventType = "AdminImmediateCancelRequested",
            Status = "Completed",
            ExternalEventId = $"admin-premium-revoke:{subscription.Id:D}:attempt:2",
            PayloadJson = JsonSerializer.Serialize(new
            {
                reason = "Newer completed reason.",
                previousStatus = "Active",
                stage = "Completed"
            }),
            CreatedAtUtc = DateTime.UtcNow.AddMinutes(-1),
            ProcessedAtUtc = DateTime.UtcNow.AddMinutes(-1)
        };
        dbContext.AddRange(subscription, pendingOperation, completedOperation);
        await dbContext.SaveChangesAsync();

        var result = await CreateService(
                dbContext,
                identityService: new FakeIdentityService { CurrentUserIsPremium = true },
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Retry pending operation."),
                CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(
            "Completed",
            await dbContext.SubscriptionEventLogs
                .Where(x => x.Id == pendingOperation.Id)
                .Select(x => x.Status)
                .SingleAsync());
        Assert.NotNull(
            await dbContext.SubscriptionEventLogs
                .Where(x => x.Id == pendingOperation.Id)
                .Select(x => x.ProcessedAtUtc)
                .SingleAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldResumeAfterIdentityFinalizationFailure()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var identityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true,
            SetPremiumStatusError = EconomyErrors.PremiumBillingUnavailable
        };
        var service = CreateService(
            dbContext,
            identityService: identityService,
            adminAuditLog: new RecordingAdminAuditLog());
        var command = new AdminRevokePremiumSubscriptionCommand(
            userId,
            "stripe",
            "Verified support request PM-4822.");

        var first = await service.AdminRevokePremiumSubscriptionAsync(
            command,
            CancellationToken.None);

        Assert.True(first.IsFailure);
        Assert.Equal("Expired", subscription.Status);
        var pendingOperation = await dbContext.SubscriptionEventLogs.SingleAsync(
            x => x.UserId == userId && x.EventType == "AdminImmediateCancelRequested");
        Assert.Equal("EconomyApplied", pendingOperation.Status);

        var summary = await service.GetSubscriptionSummaryAsync(userId, CancellationToken.None);
        Assert.True(summary.IsSuccess);
        Assert.True(summary.Value.HasPendingAdminRevocation);

        identityService.SetPremiumStatusError = null;
        var retry = await service.AdminRevokePremiumSubscriptionAsync(
            command,
            CancellationToken.None);

        Assert.True(retry.IsSuccess);
        Assert.False(retry.Value.HasPendingAdminRevocation);
        Assert.Equal(
            "Completed",
            await dbContext.SubscriptionEventLogs
                .Where(x => x.Id == pendingOperation.Id)
                .Select(x => x.Status)
                .SingleAsync());
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldReturnRetryableFailureWhenAuditTimesOutWithoutRequestCancellation()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var result = await CreateService(
                dbContext,
                identityService: new FakeIdentityService { CurrentUserIsPremium = true },
                adminAuditLog: new TimeoutAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(
                new AdminRevokePremiumSubscriptionCommand(
                    userId,
                    "stripe",
                    "Verified support request PM-4824."),
                CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.AdminPremiumRevokeFinalizationFailed.Code, result.Error.Code);
        var operation = Assert.Single(await dbContext.SubscriptionEventLogs.ToListAsync());
        Assert.Equal("Pending", operation.Status);
        Assert.Equal("Active", subscription.Status);
    }

    [Fact]
    public async Task RunEconomyReconciliationAsync_ShouldRecoverPendingAdminPremiumRevocation()
    {
        await using var dbContext = CreateDbContext();
        var userId = Guid.NewGuid();
        var subscription = CreateAdminRevokeTestSubscription(userId);
        dbContext.UserSubscriptions.Add(subscription);
        await dbContext.SaveChangesAsync();

        var failingIdentityService = new FakeIdentityService
        {
            CurrentUserIsPremium = true,
            SetPremiumStatusError = EconomyErrors.PremiumBillingUnavailable
        };
        var command = new AdminRevokePremiumSubscriptionCommand(
            userId,
            "stripe",
            "Verified support request PM-4822.");
        var initial = await CreateService(
                dbContext,
                identityService: failingIdentityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .AdminRevokePremiumSubscriptionAsync(command, CancellationToken.None);

        Assert.True(initial.IsFailure);
        var pendingOperation = await dbContext.SubscriptionEventLogs.SingleAsync(
            x => x.UserId == userId && x.EventType == "AdminImmediateCancelRequested");
        Assert.Equal("EconomyApplied", pendingOperation.Status);

        var recoveryIdentityService = new FakeIdentityService { CurrentUserIsPremium = true };
        var recovery = await CreateService(
                dbContext,
                identityService: recoveryIdentityService,
                adminAuditLog: new RecordingAdminAuditLog())
            .RunEconomyReconciliationAsync(CancellationToken.None);

        Assert.True(
            recovery.IsSuccess,
            recovery.IsFailure ? $"{recovery.Error.Code}:{recovery.Error.Message}" : "unexpected failure");
        Assert.True(recovery.Value.ChecksRun >= 1);
        Assert.True(recovery.Value.AutoFixesApplied >= 1);
        Assert.Contains(recoveryIdentityService.SetPremiumStatusCalls, call => !call.IsPremium);
        Assert.Equal(
            "Completed",
            await dbContext.SubscriptionEventLogs
                .Where(x => x.Id == pendingOperation.Id)
                .Select(x => x.Status)
                .SingleAsync());
    }

    [Fact]
    public async Task UserSubscriptionConcurrencyToken_ShouldRejectStaleAdminWriteAfterWebhookUpdate()
    {
        await using var database = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();
        var subscriptionId = Guid.NewGuid();
        await using (var seed = CreateSqliteDbContext(database.ConnectionString))
        {
            var subscription = CreateAdminRevokeTestSubscription(userId);
            subscription.Id = subscriptionId;
            seed.UserSubscriptions.Add(subscription);
            await seed.SaveChangesAsync();
        }

        await using var adminContext = CreateSqliteDbContext(database.ConnectionString);
        await using var webhookContext = CreateSqliteDbContext(database.ConnectionString);
        var adminSubscription = await adminContext.UserSubscriptions.SingleAsync(
            x => x.Id == subscriptionId);
        var webhookSubscription = await webhookContext.UserSubscriptions.SingleAsync(
            x => x.Id == subscriptionId);

        webhookSubscription.Status = "Canceled";
        webhookSubscription.CancelAtPeriodEnd = true;
        webhookSubscription.UpdatedAtUtc = webhookSubscription.UpdatedAtUtc.AddSeconds(1);
        await webhookContext.SaveChangesAsync();

        adminSubscription.Status = "Expired";
        adminSubscription.ExpiredAtUtc = DateTime.UtcNow;
        adminSubscription.UpdatedAtUtc = adminSubscription.UpdatedAtUtc.AddSeconds(2);

        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(
            () => adminContext.SaveChangesAsync());
    }

    [Fact]
    public async Task SubscriptionEventLogStatusConcurrencyToken_ShouldRejectCompletedStatusRegression()
    {
        await using var database = await CreateSharedSqliteEconomyDatabaseAsync();
        var operationId = Guid.NewGuid();
        await using (var seed = CreateSqliteDbContext(database.ConnectionString))
        {
            seed.SubscriptionEventLogs.Add(new SubscriptionEventLog
            {
                Id = operationId,
                UserId = Guid.NewGuid(),
                Provider = "stripe",
                EventType = "AdminImmediateCancelRequested",
                Status = "EconomyApplied",
                ExternalEventId = $"admin-premium-revoke:{Guid.NewGuid():D}:attempt:1",
                CreatedAtUtc = DateTime.UtcNow
            });
            await seed.SaveChangesAsync();
        }

        await using var completionContext = CreateSqliteDbContext(database.ConnectionString);
        await using var staleFailureContext = CreateSqliteDbContext(database.ConnectionString);
        var completed = await completionContext.SubscriptionEventLogs.SingleAsync(
            x => x.Id == operationId);
        var staleFailure = await staleFailureContext.SubscriptionEventLogs.SingleAsync(
            x => x.Id == operationId);

        completed.Status = "Completed";
        completed.ProcessedAtUtc = DateTime.UtcNow;
        await completionContext.SaveChangesAsync();

        staleFailure.Status = "GatewayFailed";
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(
            () => staleFailureContext.SaveChangesAsync());
    }

    [Theory]
    [InlineData("canceled", true)]
    [InlineData("CANCELED", true)]
    [InlineData("incomplete_expired", true)]
    [InlineData("active", false)]
    [InlineData("trialing", false)]
    public void IsStripeSubscriptionTerminated_ShouldRecognizeOnlyTerminalProviderStates(
        string status,
        bool expected)
    {
        Assert.Equal(
            expected,
            EconomyService.IsStripeSubscriptionTerminated(new Stripe.Subscription
            {
                Status = status
            }));
    }

    [Fact]
    public async Task AdminRevokePremiumSubscriptionAsync_ShouldConvergeWhenWebhookUpdatesSubscriptionDuringRevoke()
    {
        await using var database = await CreateSharedSqliteEconomyDatabaseAsync();
        var userId = Guid.NewGuid();
        var subscriptionId = Guid.NewGuid();
        await using (var seed = CreateSqliteDbContext(database.ConnectionString))
        {
            var subscription = CreateAdminRevokeTestSubscription(userId);
            subscription.Id = subscriptionId;
            seed.UserSubscriptions.Add(subscription);
            await seed.SaveChangesAsync();
        }

        await using var adminContext = CreateSqliteDbContext(database.ConnectionString);
        await using var webhookContext = CreateSqliteDbContext(database.ConnectionString);
        var auditLog = new CoordinatingAdminPremiumRevokeAuditLog();
        var service = CreateService(
            adminContext,
            identityService: new FakeIdentityService { CurrentUserIsPremium = true },
            adminAuditLog: auditLog);
        var revokeTask = service.AdminRevokePremiumSubscriptionAsync(
            new AdminRevokePremiumSubscriptionCommand(
                userId,
                "stripe",
                "Verified support request PM-4823."),
            CancellationToken.None);

        await auditLog.RequestedAuditStarted.Task.WaitAsync(TimeSpan.FromSeconds(5));
        var webhookSubscription = await webhookContext.UserSubscriptions.SingleAsync(
            x => x.Id == subscriptionId);
        webhookSubscription.Status = "Canceled";
        webhookSubscription.CancelAtPeriodEnd = true;
        webhookSubscription.CancelledAtUtc = DateTime.UtcNow;
        webhookSubscription.UpdatedAtUtc = webhookSubscription.UpdatedAtUtc.AddSeconds(1);
        await webhookContext.SaveChangesAsync();
        auditLog.AllowRevokeToContinue.TrySetResult();

        var result = await revokeTask;

        Assert.True(
            result.IsSuccess,
            result.IsFailure ? $"{result.Error.Code}:{result.Error.Message}" : "unexpected failure");
        await using var verificationContext = CreateSqliteDbContext(database.ConnectionString);
        var finalSubscription = await verificationContext.UserSubscriptions.SingleAsync(
            x => x.Id == subscriptionId);
        Assert.Equal("Expired", finalSubscription.Status);
        Assert.NotNull(finalSubscription.ExpiredAtUtc);
        Assert.False(finalSubscription.CancelAtPeriodEnd);
        var operation = Assert.Single(
            await verificationContext.SubscriptionEventLogs
                .Where(x => x.UserId == userId && x.EventType == "AdminImmediateCancelRequested")
                .ToListAsync());
        Assert.Equal("Completed", operation.Status);
        Assert.NotNull(operation.ProcessedAtUtc);
    }

    private static UserSubscription CreateAdminRevokeTestSubscription(
        Guid userId,
        string provider = "stripe",
        string status = "Active",
        DateTime? currentPeriodEndUtc = null)
    {
        var now = DateTime.UtcNow;
        return new UserSubscription
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Provider = provider,
            PurchaseChannel = provider == "stripe" ? "web" : "ios",
            Region = "US",
            PlanId = "yearly",
            ProductId = provider == "stripe" ? "price_yearly" : "petmagic.premium.yearly",
            Status = status,
            ExternalCustomerId = provider == "stripe" ? "cus_test" : null,
            ExternalSubscriptionId = null,
            CurrentPeriodStartUtc = now.AddDays(-5),
            CurrentPeriodEndUtc = currentPeriodEndUtc ?? now.AddDays(25),
            CancelAtPeriodEnd = false,
            MonthlyTokenLimit = 700,
            MonthlyTokensGranted = 40,
            CreatedAtUtc = now.AddDays(-5),
            UpdatedAtUtc = now
        };
    }

    private sealed class CoordinatingAdminPremiumRevokeAuditLog : IAdminAuditLog
    {
        private int writeCount;

        public TaskCompletionSource RequestedAuditStarted { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public TaskCompletionSource AllowRevokeToContinue { get; } =
            new(TaskCreationOptions.RunContinuationsAsynchronously);

        public async Task WriteAsync(
            AdminAuditEntry entry,
            CancellationToken cancellationToken)
        {
            if (Interlocked.Increment(ref writeCount) != 1)
            {
                return;
            }

            RequestedAuditStarted.TrySetResult();
            await AllowRevokeToContinue.Task.WaitAsync(cancellationToken);
        }
    }

    private sealed class TimeoutAdminAuditLog : IAdminAuditLog
    {
        public Task WriteAsync(AdminAuditEntry entry, CancellationToken cancellationToken)
        {
            return Task.FromException(new OperationCanceledException("audit transport timed out"));
        }
    }
}
