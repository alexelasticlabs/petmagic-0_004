using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class TemplateGenerationSchedulerV2FoundationTests
{
    [Fact]
    public async Task UpdatePolicyAsync_ShouldReplayIdenticalCommandWithoutDuplicateAudit()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var actorUserId = Guid.NewGuid();
        var command = CreatePolicyCommand(actorUserId, "policy-update-1", expectedRevision: 1);

        var first = await service.UpdatePolicyAsync(command, CancellationToken.None);
        var replay = await service.UpdatePolicyAsync(command, CancellationToken.None);

        Assert.True(first.IsSuccess, first.Error.Code);
        Assert.True(replay.IsSuccess, replay.Error.Code);
        Assert.Equal(2, first.Value.Revision);
        Assert.Equal(first.Value.Revision, replay.Value.Revision);
        Assert.Equal(first.Value.AdmissionEnabled, replay.Value.AdmissionEnabled);
        Assert.Equal(first.Value.EffectiveProfile, replay.Value.EffectiveProfile);
        Assert.Equal(first.Value.GeneratedAtUtc, replay.Value.GeneratedAtUtc);
        Assert.Equal(first.Value.Alerts, replay.Value.Alerts);
        Assert.Equal(2, await dbContext.TemplateGenerationControlPolicies
            .Select(policy => policy.Revision)
            .SingleAsync());
        Assert.Single(await dbContext.TemplateGenerationControlPolicyCommandReceipts.ToListAsync());
        var audit = Assert.Single(await dbContext.PushOutboxMessages.ToListAsync());
        Assert.Equal(TemplateAdminAuditOutbox.Kind, audit.Kind);
        Assert.Contains("templates.generation_control.policy_updated", audit.PayloadJson, StringComparison.Ordinal);
        Assert.Contains("falConcurrencyExplicitlyConfirmed", audit.PayloadJson, StringComparison.Ordinal);
    }

    [Fact]
    public async Task UpdatePolicyAsync_ShouldRejectReusedKeyWithDifferentPayload()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var actorUserId = Guid.NewGuid();
        var first = CreatePolicyCommand(actorUserId, "policy-update-conflict", expectedRevision: 1);
        var conflictingReplay = first with { ApplicationHardCeiling = 24 };

        var accepted = await service.UpdatePolicyAsync(first, CancellationToken.None);
        var conflict = await service.UpdatePolicyAsync(conflictingReplay, CancellationToken.None);

        Assert.True(accepted.IsSuccess, accepted.Error.Code);
        Assert.True(conflict.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationControlIdempotencyConflict.Code, conflict.Error.Code);
        Assert.Equal(2, await dbContext.TemplateGenerationControlPolicies
            .Select(policy => policy.Revision)
            .SingleAsync());
        Assert.Single(await dbContext.TemplateGenerationControlPolicyCommandReceipts.ToListAsync());
        Assert.Single(await dbContext.PushOutboxMessages.ToListAsync());
    }

    [Fact]
    public async Task UpdatePolicyAsync_ShouldRejectStaleRevisionWithoutAuditOrReceipt()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var actorUserId = Guid.NewGuid();

        var accepted = await service.UpdatePolicyAsync(
            CreatePolicyCommand(actorUserId, "policy-update-current", expectedRevision: 1),
            CancellationToken.None);
        var stale = await service.UpdatePolicyAsync(
            CreatePolicyCommand(actorUserId, "policy-update-stale", expectedRevision: 1),
            CancellationToken.None);

        Assert.True(accepted.IsSuccess, accepted.Error.Code);
        Assert.True(stale.IsFailure);
        Assert.Equal(TemplatesErrors.GenerationControlPolicyConflict.Code, stale.Error.Code);
        Assert.Equal(2, await dbContext.TemplateGenerationControlPolicies
            .Select(policy => policy.Revision)
            .SingleAsync());
        Assert.Single(await dbContext.TemplateGenerationControlPolicyCommandReceipts.ToListAsync());
        Assert.Single(await dbContext.PushOutboxMessages.ToListAsync());
    }

    [Fact]
    public async Task UpdatePolicyAsync_ShouldPreserveConfirmationTimestampForUnrelatedPolicyChange()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var initial = await service.GetAsync(CancellationToken.None);
        var command = CreatePolicyCommand(Guid.NewGuid(), "policy-pause-without-confirmation", 1) with
        {
            AdmissionEnabled = false,
            ReservedHeadroom = 1,
            ConfirmFalConcurrencyLimit = false
        };

        var updated = await service.UpdatePolicyAsync(command, CancellationToken.None);

        Assert.True(initial.IsSuccess, initial.Error.Code);
        Assert.True(updated.IsSuccess, updated.Error.Code);
        Assert.Equal(initial.Value.ConfirmedAtUtc, updated.Value.ConfirmedAtUtc);
        var stored = await dbContext.TemplateGenerationControlPolicies.SingleAsync();
        Assert.Equal(initial.Value.ConfirmedAtUtc, stored.ConfirmedAtUtc);
    }

    [Fact]
    public async Task UpdatePolicyAsync_ShouldRequireAndAuditExplicitConcurrencyConfirmation()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var actorUserId = Guid.NewGuid();
        var initial = await service.GetAsync(CancellationToken.None);
        var unconfirmed = CreatePolicyCommand(actorUserId, "policy-limit-unconfirmed", 1) with
        {
            ConfirmedFalConcurrencyLimit = 40,
            ConfirmFalConcurrencyLimit = false
        };

        var rejected = await service.UpdatePolicyAsync(unconfirmed, CancellationToken.None);
        await Task.Delay(5);
        var confirmed = await service.UpdatePolicyAsync(
            unconfirmed with
            {
                IdempotencyKey = "policy-limit-confirmed",
                ConfirmFalConcurrencyLimit = true
            },
            CancellationToken.None);

        Assert.True(initial.IsSuccess, initial.Error.Code);
        Assert.True(rejected.IsFailure);
        Assert.Equal(
            TemplatesErrors.GenerationControlConcurrencyConfirmationRequired.Code,
            rejected.Error.Code);
        Assert.True(confirmed.IsSuccess, confirmed.Error.Code);
        Assert.Equal(40, confirmed.Value.ConfirmedFalConcurrencyLimit);
        Assert.True(confirmed.Value.ConfirmedAtUtc > initial.Value.ConfirmedAtUtc);
        Assert.Single(await dbContext.TemplateGenerationControlPolicyCommandReceipts.ToListAsync());
        var audit = Assert.Single(await dbContext.PushOutboxMessages.ToListAsync());
        Assert.Contains("falConcurrencyExplicitlyConfirmed", audit.PayloadJson, StringComparison.Ordinal);
        Assert.Contains("true", audit.PayloadJson, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task UpdatePolicyAsync_ShouldIncludeConfirmationFlagInIdempotencyHash()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var command = CreatePolicyCommand(Guid.NewGuid(), "policy-confirmation-hash", 1);

        var accepted = await service.UpdatePolicyAsync(command, CancellationToken.None);
        var conflictingReplay = await service.UpdatePolicyAsync(
            command with { ConfirmFalConcurrencyLimit = true },
            CancellationToken.None);

        Assert.True(accepted.IsSuccess, accepted.Error.Code);
        Assert.True(conflictingReplay.IsFailure);
        Assert.Equal(
            TemplatesErrors.GenerationControlIdempotencyConflict.Code,
            conflictingReplay.Error.Code);
    }

    [Fact]
    public async Task ListProviderAttemptRecoveryAsync_ShouldReturnOnlyManualSubmissionUnknownSafelyAndPage()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);
        var now = DateTime.UtcNow;
        var oldestManual = CreateRecoveryAttempt(
            now.AddMinutes(-10),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: null,
            providerRequestId: null,
            ordinal: 1);
        var newestManual = CreateRecoveryAttempt(
            now.AddMinutes(-5),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: null,
            providerRequestId: "fal_request_safe_2",
            ordinal: 2);
        var scheduledRecovery = CreateRecoveryAttempt(
            now.AddMinutes(-20),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            now.AddSeconds(30),
            providerRequestId: null,
            ordinal: 3);
        var providerQueued = CreateRecoveryAttempt(
            now.AddMinutes(-30),
            TemplateGenerationProviderAttemptState.ProviderQueued,
            nextPollAtUtc: null,
            providerRequestId: "fal_request_queued",
            ordinal: 4);
        var otherProviderManual = CreateRecoveryAttempt(
            now.AddMinutes(-40),
            TemplateGenerationProviderAttemptState.SubmissionUnknown,
            nextPollAtUtc: null,
            providerRequestId: null,
            ordinal: 5);
        otherProviderManual.Provider = "other-provider";
        oldestManual.SubmissionTokenHash = new string('A', 64);
        oldestManual.ProviderStatusUrl = "https://provider.invalid/status?secret=never-return-this";
        oldestManual.LastErrorCode = "templates.provider_submission_reconciliation_required";
        dbContext.TemplateGenerationProviderAttempts.AddRange(
            oldestManual,
            newestManual,
            scheduledRecovery,
            providerQueued,
            otherProviderManual);
        await dbContext.SaveChangesAsync();

        var firstPage = await service.ListProviderAttemptRecoveryAsync(
            new AdminTemplateProviderAttemptRecoveryQuery(Skip: 0, Take: 1),
            CancellationToken.None);
        var secondPage = await service.ListProviderAttemptRecoveryAsync(
            new AdminTemplateProviderAttemptRecoveryQuery(Skip: 1, Take: 100),
            CancellationToken.None);

        Assert.True(firstPage.IsSuccess, firstPage.Error.Code);
        Assert.True(secondPage.IsSuccess, secondPage.Error.Code);
        Assert.Equal(2, firstPage.Value.TotalCount);
        Assert.True(firstPage.Value.HasMore);
        var firstItem = Assert.Single(firstPage.Value.Items);
        Assert.Equal(oldestManual.Id, firstItem.AttemptId);
        Assert.Equal(oldestManual.GenerationJobId, firstItem.GenerationId);
        Assert.Equal("image_generation", firstItem.Stage);
        Assert.Equal("submission_unknown", firstItem.State);
        Assert.Equal(oldestManual.Version, firstItem.AttemptVersion);
        Assert.Equal(
            "correlated_accepted_or_confirmed_not_found",
            firstItem.EvidenceNeeded);
        Assert.Equal(oldestManual.LastErrorCode, firstItem.ErrorCode);
        Assert.False(secondPage.Value.HasMore);
        Assert.Equal(newestManual.Id, Assert.Single(secondPage.Value.Items).AttemptId);

        var serialized = JsonSerializer.Serialize(firstPage.Value);
        Assert.DoesNotContain(oldestManual.SubmissionTokenHash, serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("never-return-this", serialized, StringComparison.Ordinal);
        Assert.DoesNotContain("providerStatusUrl", serialized, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(-1, 50)]
    [InlineData(0, 0)]
    [InlineData(0, 101)]
    public async Task ListProviderAttemptRecoveryAsync_ShouldRejectInvalidPaging(int skip, int take)
    {
        await using var dbContext = CreateDbContext();
        var service = CreateControlService(dbContext);

        var result = await service.ListProviderAttemptRecoveryAsync(
            new AdminTemplateProviderAttemptRecoveryQuery(skip, take),
            CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(TemplatesErrors.ProviderAttemptRecoveryQueryInvalid.Code, result.Error.Code);
    }

    [Fact]
    public async Task ProviderCallback_ShouldDeduplicateCanonicalDeliveryIndependentOfReceivedAt()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var callback = new TemplateGenerationProviderCallbackService(
            CreateOptions(schedulerV2Enabled: true),
            store);
        using var document = JsonDocument.Parse("""
            {
              "images": [
                { "url": "https://fal.example.test/generated.png" }
              ]
            }
            """);
        var firstCommand = new FalProviderWebhookCommand(
            "request-dedupe-1",
            "OK",
            document.RootElement.Clone(),
            null,
            DateTime.UtcNow.AddMinutes(-1),
            "callback-token-1");
        var secondCommand = firstCommand with { ReceivedAtUtc = DateTime.UtcNow };

        var first = await callback.ProcessFalWebhookAsync(firstCommand, CancellationToken.None);
        var duplicate = await callback.ProcessFalWebhookAsync(secondCommand, CancellationToken.None);

        Assert.True(first.IsSuccess, first.Error.Code);
        Assert.True(duplicate.IsSuccess, duplicate.Error.Code);
        Assert.Equal("queued", first.Value.Result);
        Assert.Equal("queued", duplicate.Value.Result);
        Assert.Single(await dbContext.TemplateProviderWebhookInbox.ToListAsync());
    }

    [Fact]
    public async Task ProviderCallback_ShouldRemainResolvableAndIgnoreLegacyDelivery_WhenSchedulerV2Disabled()
    {
        var callback = new TemplateGenerationProviderCallbackService(
            CreateOptions(schedulerV2Enabled: false));
        using var document = JsonDocument.Parse("""{"images":[]}""");

        var result = await callback.ProcessFalWebhookAsync(
            new FalProviderWebhookCommand(
                "legacy-request-1",
                "OK",
                document.RootElement.Clone(),
                null,
                DateTime.UtcNow,
                null),
            CancellationToken.None);

        Assert.True(result.IsSuccess, result.Error.Code);
        Assert.Equal("scheduler_disabled", result.Value.Result);
    }

    [Fact]
    public async Task EnqueueWebhookAsync_ShouldAcceptExactPayloadLimitAndRejectOneCharacterMore()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        const int payloadLimit = 64 * 1024;

        var acceptedId = await store.EnqueueWebhookAsync(
            "fal",
            "payload-at-limit",
            null,
            "request-at-limit",
            "OK",
            new string('x', payloadLimit),
            DateTime.UtcNow,
            CancellationToken.None);
        var exception = await Assert.ThrowsAsync<ArgumentException>(() => store.EnqueueWebhookAsync(
            "fal",
            "payload-over-limit",
            null,
            "request-over-limit",
            "OK",
            new string('x', payloadLimit + 1),
            DateTime.UtcNow,
            CancellationToken.None));

        Assert.NotEqual(Guid.Empty, acceptedId);
        Assert.Equal("payloadJson", exception.ParamName);
        Assert.Single(await dbContext.TemplateProviderWebhookInbox.ToListAsync());
    }

    [Fact]
    public async Task EnqueueWebhookAsync_ShouldUseValidCallbackTokenExclusivelyWhenRequestIdConflicts()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var jobs = await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 2);
        var now = DateTime.UtcNow;
        var tokenMatchedAttempt = CreatePersistedAttempt(
            jobs[0].Id,
            new string('A', 64),
            providerRequestId: null,
            createdAtUtc: now.AddSeconds(-2));
        var requestIdMatchedAttempt = CreatePersistedAttempt(
            jobs[1].Id,
            new string('B', 64),
            "request-conflicting-with-token",
            now.AddSeconds(-1));
        dbContext.TemplateGenerationProviderAttempts.AddRange(
            tokenMatchedAttempt,
            requestIdMatchedAttempt);
        await dbContext.SaveChangesAsync();

        var inboxId = await store.EnqueueWebhookAsync(
            "fal",
            "token-exclusive-correlation",
            tokenMatchedAttempt.SubmissionTokenHash,
            requestIdMatchedAttempt.ProviderRequestId,
            "OK",
            "{}",
            now,
            CancellationToken.None);

        var inbox = await dbContext.TemplateProviderWebhookInbox.SingleAsync(x => x.Id == inboxId);
        Assert.Equal(tokenMatchedAttempt.Id, inbox.ProviderAttemptId);
        Assert.Equal(tokenMatchedAttempt.GenerationJobId, inbox.GenerationJobId);
        Assert.NotEqual(requestIdMatchedAttempt.Id, inbox.ProviderAttemptId);
    }

    [Fact]
    public async Task TryReserveAsync_ShouldDrainNaturallyAfterPolicyLimitIsReducedBelowInflight()
    {
        await using var dbContext = CreateDbContext();
        var policyProvider = new MutableRuntimePolicyProvider(CreateRuntimePolicy(confirmedFalLimit: 4));
        var store = CreateAttemptStore(dbContext, policyProvider: policyProvider);
        var jobs = await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 3);

        var first = await store.TryReserveAsync(CreateReservation(jobs[0].Id, 1), CancellationToken.None);
        var second = await store.TryReserveAsync(CreateReservation(jobs[1].Id, 2), CancellationToken.None);
        policyProvider.Current = CreateRuntimePolicy(confirmedFalLimit: 3);
        var whileAboveReducedLimit = await store.TryReserveAsync(
            CreateReservation(jobs[2].Id, 3),
            CancellationToken.None);

        Assert.NotNull(first);
        Assert.NotNull(second);
        Assert.Null(whileAboveReducedLimit);
        Assert.Equal(2, await dbContext.TemplateGenerationProviderAttempts.CountAsync());

        await store.MarkSubmissionFailedAsync(first!.Id, "confirmed_not_submitted", CancellationToken.None);
        var whileAtReducedLimit = await store.TryReserveAsync(
            CreateReservation(jobs[2].Id, 4),
            CancellationToken.None);
        Assert.Null(whileAtReducedLimit);

        await store.MarkSubmissionFailedAsync(second!.Id, "confirmed_not_submitted", CancellationToken.None);
        var afterDrain = await store.TryReserveAsync(
            CreateReservation(jobs[2].Id, 5),
            CancellationToken.None);

        Assert.NotNull(afterDrain);
        Assert.Equal(3, await dbContext.TemplateGenerationProviderAttempts.CountAsync());
    }

    [Theory]
    [InlineData(TemplateProviderBalanceState.Critical)]
    [InlineData(TemplateProviderBalanceState.Unknown)]
    public async Task TryReserveAsync_ShouldFailClosedWhenFalBalanceIsNotUsable(
        TemplateProviderBalanceState balanceState)
    {
        await using var dbContext = CreateDbContext();
        var snapshotService = new StaticRuntimeSnapshotService(CreateBalanceSnapshot(balanceState));
        var store = CreateAttemptStore(dbContext, snapshotService: snapshotService);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));

        var reserved = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);

        Assert.Null(reserved);
        Assert.Empty(await dbContext.TemplateGenerationProviderAttempts.ToListAsync());
    }

    [Fact]
    public async Task GetRuntimeSnapshotAsync_ShouldFailClosedWhenLastKnownGoodIsOlderThanFiveMinutes()
    {
        await using var dbContext = CreateDbContext();
        var lastSuccessfulAtUtc = DateTime.UtcNow.AddMinutes(-6);
        dbContext.TemplateProviderRuntimeSnapshots.Add(new TemplateProviderRuntimeSnapshot
        {
            Id = TemplateGenerationControlPolicyDefaults.FalSnapshotId,
            Provider = "fal",
            BalanceState = TemplateProviderBalanceState.Fresh,
            StatusChangedAtUtc = lastSuccessfulAtUtc,
            CurrentBalanceUsd = 20m,
            LastSuccessfulAtUtc = lastSuccessfulAtUtc,
            CheckedAtUtc = lastSuccessfulAtUtc,
            UpdatedAtUtc = lastSuccessfulAtUtc
        });
        await dbContext.SaveChangesAsync();
        var service = new FalProviderRuntimeSnapshotService(
            dbContext,
            new ThrowingHttpClientFactory(),
            CreateOptions(),
            NullLogger<FalProviderRuntimeSnapshotService>.Instance);

        var snapshot = await service.GetSnapshotAsync(CancellationToken.None);

        Assert.Equal(TemplateProviderBalanceState.Unknown, snapshot.BalanceState);
        Assert.Equal(lastSuccessfulAtUtc.AddMinutes(5), snapshot.StatusChangedAtUtc);
        var persisted = await dbContext.TemplateProviderRuntimeSnapshots.SingleAsync();
        Assert.Equal(TemplateProviderBalanceState.Unknown, persisted.BalanceState);
        Assert.True(persisted.UpdatedAtUtc > lastSuccessfulAtUtc);
    }

    [Fact]
    public async Task TryReserveAsync_ShouldProtectVideoCapacityWhenVideoBacklogExists()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var imageJobs = await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 7);
        var videoJob = Assert.Single(await AddJobsAsync(
            dbContext,
            TemplateGenerationQueue.MediaTypeVideo,
            count: 1,
            TemplateGenerationStatus.Queued));

        for (var index = 0; index < 6; index++)
        {
            var imageAttempt = await store.TryReserveAsync(
                CreateReservation(imageJobs[index].Id, index + 1),
                CancellationToken.None);
            Assert.NotNull(imageAttempt);
        }

        var imageUsingReservedVideoSlot = await store.TryReserveAsync(
            CreateReservation(imageJobs[6].Id, 7),
            CancellationToken.None);
        var videoAttempt = await store.TryReserveAsync(
            CreateReservation(
                videoJob.Id,
                8,
                TemplateGenerationProviderAttemptStage.VideoPreprocessing),
            CancellationToken.None);

        Assert.Null(imageUsingReservedVideoSlot);
        Assert.NotNull(videoAttempt);
        Assert.Equal(7, await dbContext.TemplateGenerationProviderAttempts.CountAsync());
    }

    [Fact]
    public async Task TryReserveAsync_ShouldProtectVideoCapacityForMotionReadyInterstageBacklog()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var imageJobs = await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 7);
        var videoJob = Assert.Single(await AddJobsAsync(
            dbContext,
            TemplateGenerationQueue.MediaTypeVideo,
            count: 1,
            TemplateGenerationStatus.ProviderQueued));
        var now = DateTime.UtcNow;
        videoJob.CurrentProviderStage = "video_preprocessing";
        videoJob.ProviderCompletedAtUtc = now.AddSeconds(-1);
        videoJob.PreprocessingCompletedAtUtc = now.AddSeconds(-1);
        videoJob.NormalizedImageUrl = "https://cdn.example.test/normalized-motion-ready.jpg";
        videoJob.MotionProviderRequestId = null;
        await dbContext.SaveChangesAsync();

        for (var index = 0; index < 6; index++)
        {
            Assert.NotNull(await store.TryReserveAsync(
                CreateReservation(imageJobs[index].Id, index + 1),
                CancellationToken.None));
        }

        var imageUsingReservedVideoSlot = await store.TryReserveAsync(
            CreateReservation(imageJobs[6].Id, 7),
            CancellationToken.None);
        var motionAttempt = await store.TryReserveAsync(
            CreateReservation(
                videoJob.Id,
                8,
                TemplateGenerationProviderAttemptStage.VideoGeneration),
            CancellationToken.None);

        Assert.Null(imageUsingReservedVideoSlot);
        Assert.NotNull(motionAttempt);
        Assert.Equal(7, await dbContext.TemplateGenerationProviderAttempts.CountAsync());
    }

    [Fact]
    public async Task SubmissionUnknown_ShouldRemainActiveAndPreventBlindSecondReservation()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));
        var first = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);
        Assert.NotNull(first);

        await store.MarkSubmittingAsync(first!.Id, CancellationToken.None);
        await store.MarkSubmissionUnknownAsync(
            first.Id,
            "submit_response_lost",
            DateTime.UtcNow.AddMinutes(-1),
            CancellationToken.None);
        var replayReservation = await store.TryReserveAsync(
            CreateReservation(job.Id, 2),
            CancellationToken.None);

        Assert.NotNull(replayReservation);
        Assert.Equal(first.Id, replayReservation!.Id);
        Assert.Equal(first.SubmissionTokenHash, replayReservation.SubmissionTokenHash);
        Assert.Equal(TemplateGenerationProviderAttemptState.SubmissionUnknown, replayReservation.State);
        Assert.Single(await dbContext.TemplateGenerationProviderAttempts.ToListAsync());
    }

    [Fact]
    public async Task ProviderAttemptLifecycle_ShouldPersistStateVersionAndPollCounters()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));
        var attempt = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);
        Assert.NotNull(attempt);
        Assert.Equal(TemplateGenerationProviderAttemptState.SubmitReserved, attempt!.State);
        Assert.Equal(1, attempt.SubmitAttemptCount);
        Assert.Equal(0, attempt.PollAttemptCount);
        Assert.Equal(0, attempt.Version);

        await store.MarkSubmittingAsync(attempt.Id, CancellationToken.None);
        await store.MarkSubmissionAcceptedAsync(
            attempt.Id,
            "provider-request-lifecycle",
            "https://queue.fal.test/status/provider-request-lifecycle",
            "https://queue.fal.test/response/provider-request-lifecycle",
            "https://queue.fal.test/cancel/provider-request-lifecycle",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);
        var firstClaim = await store.ClaimDueAsync(
            "worker-lifecycle",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);

        Assert.NotNull(firstClaim);
        Assert.Equal(TemplateGenerationProviderAttemptState.ProviderQueued, firstClaim!.State);
        Assert.Equal(0, firstClaim.PollAttemptCount);
        Assert.True(await store.TryBeginPollAsync(
            attempt.Id,
            firstClaim.ClaimToken,
            maxAttempts: 2,
            CancellationToken.None));
        await store.UpdateClaimedStateAsync(
            attempt.Id,
            firstClaim.ClaimToken,
            TemplateGenerationProviderAttemptState.ProviderProcessing,
            DateTime.UtcNow.AddSeconds(-1),
            null,
            providerCompleted: false,
            CancellationToken.None);

        var secondClaim = await store.ClaimDueAsync(
            "worker-lifecycle",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(secondClaim);
        Assert.Equal(TemplateGenerationProviderAttemptState.ProviderProcessing, secondClaim!.State);
        Assert.Equal(1, secondClaim.PollAttemptCount);
        Assert.True(await store.TryBeginPollAsync(
            attempt.Id,
            secondClaim.ClaimToken,
            maxAttempts: 2,
            CancellationToken.None));
        Assert.False(await store.TryBeginPollAsync(
            attempt.Id,
            secondClaim.ClaimToken,
            maxAttempts: 2,
            CancellationToken.None));
        await store.UpdateClaimedStateAsync(
            attempt.Id,
            secondClaim.ClaimToken,
            TemplateGenerationProviderAttemptState.Completed,
            null,
            null,
            providerCompleted: true,
            CancellationToken.None);

        var persisted = await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == attempt.Id);
        Assert.Equal(TemplateGenerationProviderAttemptState.Completed, persisted.State);
        Assert.Equal(1, persisted.SubmitAttemptCount);
        Assert.Equal(2, persisted.PollAttemptCount);
        Assert.Equal(8, persisted.Version);
        Assert.NotNull(persisted.SubmittedAtUtc);
        Assert.NotNull(persisted.ProviderCompletedAtUtc);
        Assert.NotNull(persisted.CompletedAtUtc);
        Assert.Null(persisted.NextPollAtUtc);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
    }

    [Fact]
    public async Task ReleaseClaimAsync_ShouldMakeYieldedAttemptImmediatelyClaimable()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));
        var attempt = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);
        Assert.NotNull(attempt);
        await store.MarkSubmissionAcceptedAsync(
            attempt!.Id,
            "provider-request-yield-release",
            "https://queue.fal.test/status/provider-request-yield-release",
            "https://queue.fal.test/response/provider-request-yield-release",
            "https://queue.fal.test/cancel/provider-request-yield-release",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        var firstClaim = await store.ClaimDueAsync(
            "yielded-worker",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(firstClaim);

        await store.ReleaseClaimAsync(
            attempt.Id,
            firstClaim!.ClaimToken,
            CancellationToken.None);
        var secondClaim = await store.ClaimDueAsync(
            "next-worker",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);

        Assert.NotNull(secondClaim);
        Assert.NotEqual(firstClaim.ClaimToken, secondClaim!.ClaimToken);
        Assert.Equal(attempt.Id, secondClaim.AttemptId);
    }

    [Fact]
    public async Task ProviderAttemptLease_ShouldFencePreviousClaimAfterReclaim()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));
        var attempt = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);
        Assert.NotNull(attempt);
        await store.MarkSubmissionAcceptedAsync(
            attempt!.Id,
            "provider-request-fencing",
            "https://queue.fal.test/status/provider-request-fencing",
            "https://queue.fal.test/response/provider-request-fencing",
            "https://queue.fal.test/cancel/provider-request-fencing",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        var firstClaim = await store.ClaimDueAsync("same-process", TimeSpan.FromMinutes(1), CancellationToken.None);
        Assert.NotNull(firstClaim);
        var persisted = await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == attempt.Id);
        persisted.LockedAtUtc = DateTime.UtcNow.AddMinutes(-2);
        await dbContext.SaveChangesAsync();

        var secondClaim = await store.ClaimDueAsync("same-process", TimeSpan.FromMinutes(1), CancellationToken.None);
        Assert.NotNull(secondClaim);
        Assert.NotEqual(firstClaim!.ClaimToken, secondClaim!.ClaimToken);
        Assert.Equal(0, secondClaim.PollAttemptCount);
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => store.UpdateClaimedStateAsync(
            attempt.Id,
            firstClaim.ClaimToken,
            TemplateGenerationProviderAttemptState.Completed,
            null,
            null,
            providerCompleted: true,
            CancellationToken.None));

        await store.UpdateClaimedStateAsync(
            attempt.Id,
            secondClaim.ClaimToken,
            TemplateGenerationProviderAttemptState.Completed,
            null,
            null,
            providerCompleted: true,
            CancellationToken.None);
    }

    [Fact]
    public async Task ProviderAttemptCancellationBudget_ShouldIncrementBeforeCallAndStopAtMaximum()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var job = Assert.Single(await AddJobsAsync(dbContext, TemplateGenerationQueue.MediaTypeImage, count: 1));
        var attempt = await store.TryReserveAsync(CreateReservation(job.Id, 1), CancellationToken.None);
        Assert.NotNull(attempt);
        await store.MarkSubmissionAcceptedAsync(
            attempt!.Id,
            "provider-request-cancel-budget",
            "https://queue.fal.test/status/provider-request-cancel-budget",
            "https://queue.fal.test/response/provider-request-cancel-budget",
            "https://queue.fal.test/cancel/provider-request-cancel-budget",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);
        var claim = await store.ClaimDueAsync("cancel-budget", TimeSpan.FromMinutes(1), CancellationToken.None);
        Assert.NotNull(claim);

        Assert.True(await store.TryBeginCancellationAsync(attempt.Id, claim!.ClaimToken, 2, CancellationToken.None));
        Assert.True(await store.TryBeginCancellationAsync(attempt.Id, claim.ClaimToken, 2, CancellationToken.None));
        Assert.False(await store.TryBeginCancellationAsync(attempt.Id, claim.ClaimToken, 2, CancellationToken.None));
        Assert.Equal(
            2,
            (await dbContext.TemplateGenerationProviderAttempts.SingleAsync(x => x.Id == attempt.Id)).CancelAttemptCount);
    }

    [Fact]
    public async Task WebhookInboxRetry_ShouldIncrementAttemptCountAndBecomeTerminalWhenProcessed()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var inboxId = await store.EnqueueWebhookAsync(
            "fal",
            "webhook-retry-counter",
            null,
            "provider-request-webhook-retry",
            "IN_PROGRESS",
            "{}",
            DateTime.UtcNow,
            CancellationToken.None);

        var first = await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(first);
        Assert.Equal(inboxId, first!.InboxId);
        Assert.Equal(1, first.AttemptCount);
        await store.MarkWebhookFailedAsync(
            inboxId,
            first.ClaimToken,
            "transient_reconciliation_failure",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        var second = await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(second);
        Assert.Equal(2, second!.AttemptCount);
        await store.MarkWebhookProcessedAsync(
            inboxId,
            second.ClaimToken,
            CancellationToken.None);

        var persisted = await dbContext.TemplateProviderWebhookInbox.SingleAsync(x => x.Id == inboxId);
        Assert.Equal(TemplateProviderWebhookInboxStatus.Processed, persisted.Status);
        Assert.Equal(2, persisted.AttemptCount);
        Assert.NotNull(persisted.ProcessedAtUtc);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
    }

    [Fact]
    public async Task WebhookInbox_ShouldReclaimStaleProcessingLeaseAndFencePreviousOwner()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var inboxId = await store.EnqueueWebhookAsync(
            "fal",
            "webhook-stale-processing",
            null,
            "provider-request-stale-processing",
            "IN_PROGRESS",
            "{}",
            DateTime.UtcNow,
            CancellationToken.None);
        var first = await store.ClaimNextWebhookAsync(
            "same-process",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(first);
        var persisted = await dbContext.TemplateProviderWebhookInbox.SingleAsync(x => x.Id == inboxId);
        persisted.LockedAtUtc = DateTime.UtcNow.AddMinutes(-2);
        await dbContext.SaveChangesAsync();

        var second = await store.ClaimNextWebhookAsync(
            "same-process",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(second);
        Assert.NotEqual(first!.ClaimToken, second!.ClaimToken);
        await Assert.ThrowsAsync<DbUpdateConcurrencyException>(() => store.MarkWebhookProcessedAsync(
            inboxId,
            first.ClaimToken,
            CancellationToken.None));
        await store.MarkWebhookProcessedAsync(inboxId, second.ClaimToken, CancellationToken.None);
        Assert.Equal(
            TemplateProviderWebhookInboxStatus.Processed,
            (await dbContext.TemplateProviderWebhookInbox.SingleAsync(x => x.Id == inboxId)).Status);
    }

    [Fact]
    public async Task WebhookInboxFailureBudget_ShouldDeadLetterActualFailuresWithoutChargingLockDeferrals()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(
            dbContext,
            options: CreateOptions(providerWebhookInboxMaxFailureCount: 2));
        var inboxId = await store.EnqueueWebhookAsync(
            "fal",
            "webhook-dead-letter-budget",
            null,
            "provider-request-dead-letter-budget",
            "IN_PROGRESS",
            "{}",
            DateTime.UtcNow,
            CancellationToken.None);

        var lockDeferred = await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(lockDeferred);
        await store.DeferWebhookAsync(
            inboxId,
            lockDeferred.ClaimToken,
            "templates.provider_attempt_locked",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        var firstFailure = await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(firstFailure);
        Assert.Equal(0, firstFailure!.FailureCount);
        var firstDeadLettered = await store.MarkWebhookFailedAsync(
            inboxId,
            firstFailure.ClaimToken,
            "templates.provider_webhook_reconciliation_failed",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        var secondFailure = await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None);
        Assert.NotNull(secondFailure);
        Assert.Equal(1, secondFailure!.FailureCount);
        var secondDeadLettered = await store.MarkWebhookFailedAsync(
            inboxId,
            secondFailure.ClaimToken,
            "templates.provider_webhook_reconciliation_failed",
            DateTime.UtcNow.AddSeconds(-1),
            CancellationToken.None);

        Assert.False(firstDeadLettered);
        Assert.True(secondDeadLettered);
        Assert.Null(await store.ClaimNextWebhookAsync(
            "worker-webhook",
            TimeSpan.FromMinutes(1),
            CancellationToken.None));
        var persisted = await dbContext.TemplateProviderWebhookInbox.SingleAsync(x => x.Id == inboxId);
        Assert.Equal(TemplateProviderWebhookInboxStatus.DeadLettered, persisted.Status);
        Assert.Equal(3, persisted.AttemptCount);
        Assert.Equal(2, persisted.FailureCount);
        Assert.NotNull(persisted.DeadLetteredAtUtc);
        Assert.Null(persisted.LockedBy);
        Assert.Null(persisted.LockedAtUtc);
    }

    [Fact]
    public async Task CleanupTerminalWebhooksAsync_ShouldDeleteOnlyExpiredTerminalRowsInBoundedBatches()
    {
        await using var dbContext = CreateDbContext();
        var store = CreateAttemptStore(dbContext);
        var now = DateTime.UtcNow;
        var oldProcessed = CreateWebhookInbox(
            "old-processed",
            TemplateProviderWebhookInboxStatus.Processed,
            now.AddDays(-8));
        var oldDeadLetter = CreateWebhookInbox(
            "old-dead-letter",
            TemplateProviderWebhookInboxStatus.DeadLettered,
            now.AddDays(-9));
        var recentProcessed = CreateWebhookInbox(
            "recent-processed",
            TemplateProviderWebhookInboxStatus.Processed,
            now.AddDays(-1));
        var oldRetryable = CreateWebhookInbox(
            "old-retryable",
            TemplateProviderWebhookInboxStatus.Failed,
            now.AddDays(-30));
        dbContext.TemplateProviderWebhookInbox.AddRange(
            oldProcessed,
            oldDeadLetter,
            recentProcessed,
            oldRetryable);
        await dbContext.SaveChangesAsync();

        var firstDeleted = await store.CleanupTerminalWebhooksAsync(
            now.AddDays(-7),
            batchSize: 1,
            CancellationToken.None);
        var secondDeleted = await store.CleanupTerminalWebhooksAsync(
            now.AddDays(-7),
            batchSize: 1,
            CancellationToken.None);
        var noMoreDeleted = await store.CleanupTerminalWebhooksAsync(
            now.AddDays(-7),
            batchSize: 1,
            CancellationToken.None);

        Assert.Equal(1, firstDeleted);
        Assert.Equal(1, secondDeleted);
        Assert.Equal(0, noMoreDeleted);
        var remainingIds = await dbContext.TemplateProviderWebhookInbox
            .Select(x => x.Id)
            .ToArrayAsync();
        Assert.DoesNotContain(oldProcessed.Id, remainingIds);
        Assert.DoesNotContain(oldDeadLetter.Id, remainingIds);
        Assert.Contains(recentProcessed.Id, remainingIds);
        Assert.Contains(oldRetryable.Id, remainingIds);
    }

    [Fact]
    public async Task GetAsync_ShouldExposeCriticalAlertForWebhookDeadLetters()
    {
        await using var dbContext = CreateDbContext();
        var deadLetteredAtUtc = DateTime.UtcNow.AddMinutes(-2);
        dbContext.TemplateProviderWebhookInbox.Add(CreateWebhookInbox(
            "dead-letter-alert",
            TemplateProviderWebhookInboxStatus.DeadLettered,
            deadLetteredAtUtc));
        await dbContext.SaveChangesAsync();
        var service = CreateControlService(dbContext);

        var response = await service.GetAsync(CancellationToken.None);

        Assert.True(response.IsSuccess, response.Error.Code);
        var alert = Assert.Single(
            response.Value.Alerts,
            candidate => candidate.AlertId == "generation-provider-webhook-dead-letter");
        Assert.Equal("critical", alert.Severity);
        Assert.Equal(deadLetteredAtUtc, alert.StatusChangedAtUtc);
    }

    private static TemplatesDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<TemplatesDbContext>()
            .UseInMemoryDatabase($"template-generation-scheduler-v2-{Guid.NewGuid():N}")
            .Options;
        return new TemplatesDbContext(options);
    }

    private static TemplateGenerationControlService CreateControlService(TemplatesDbContext dbContext) =>
        new(
            dbContext,
            new StaticRuntimeSnapshotService(CreateBalanceSnapshot(TemplateProviderBalanceState.Fresh)),
            CreateOptions(),
            new NoopTemplateGenerationBilling());

    private static TemplatesOptions CreateOptions(
        bool schedulerV2Enabled = true,
        int providerWebhookInboxMaxFailureCount = 8) => new()
        {
            AiProvider = TemplateAiProviders.Fal,
            GenerationSchedulerV2Enabled = schedulerV2Enabled,
            PublicBaseUrl = "http://localhost:5000",
            LocalMediaRootPath = "wwwroot/templates-media",
            DefaultImagePrompt = "Create a themed pet portrait.",
            DefaultPreprocessingPrompt = "Keep the same pet.",
            DefaultKlingPrompt = "Funny dance.",
            AllowedImageModels = ["openai/gpt-image-2/edit"],
            AllowedPreprocessingModels = ["openai/gpt-image-2/edit"],
            AllowedKlingModels = ["fal-ai/kling-video/v3/pro/motion-control"],
            SupportedLocalizationLocales = ["ru"],
            ProviderWebhookInboxMaxFailureCount = providerWebhookInboxMaxFailureCount
        };

    private static TemplateGenerationProviderAttemptStore CreateAttemptStore(
        TemplatesDbContext dbContext,
        MutableRuntimePolicyProvider? policyProvider = null,
        StaticRuntimeSnapshotService? snapshotService = null,
        TemplatesOptions? options = null) =>
        new(
            dbContext,
            policyProvider ?? new MutableRuntimePolicyProvider(CreateRuntimePolicy(confirmedFalLimit: 10)),
            snapshotService ?? new StaticRuntimeSnapshotService(
                CreateBalanceSnapshot(TemplateProviderBalanceState.Fresh)),
            options ?? CreateOptions());

    private static UpdateAdminTemplateGenerationControlPolicyCommand CreatePolicyCommand(
        Guid actorUserId,
        string idempotencyKey,
        long expectedRevision) =>
        new(
            actorUserId,
            idempotencyKey,
            expectedRevision,
            "Capacity policy verification",
            AdmissionEnabled: true,
            ConfirmedFalConcurrencyLimit: 10,
            ReservedHeadroom: 2,
            ApplicationHardCeiling: 38,
            ConfirmFalConcurrencyLimit: false);

    private static TemplateGenerationRuntimePolicySnapshot CreateRuntimePolicy(int confirmedFalLimit)
    {
        var policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);
        policy.AdmissionEnabled = true;
        policy.ConfirmedFalConcurrencyLimit = confirmedFalLimit;
        return TemplateGenerationRuntimePolicyCalculator.Calculate(policy);
    }

    private static TemplateProviderRuntimeSnapshot CreateBalanceSnapshot(
        TemplateProviderBalanceState balanceState)
    {
        var now = DateTime.UtcNow;
        return new TemplateProviderRuntimeSnapshot
        {
            Id = TemplateGenerationControlPolicyDefaults.FalSnapshotId,
            Provider = "fal",
            BalanceState = balanceState,
            StatusChangedAtUtc = now,
            CurrentBalanceUsd = balanceState == TemplateProviderBalanceState.Unknown ? null : 20m,
            LastSuccessfulAtUtc = balanceState == TemplateProviderBalanceState.Unknown ? null : now,
            CheckedAtUtc = now,
            UpdatedAtUtc = now
        };
    }

    private static async Task<IReadOnlyList<TemplateGenerationJob>> AddJobsAsync(
        TemplatesDbContext dbContext,
        string mediaType,
        int count,
        TemplateGenerationStatus status = TemplateGenerationStatus.Processing)
    {
        var now = DateTime.UtcNow;
        var jobs = Enumerable.Range(0, count)
            .Select(_ => new TemplateGenerationJob
            {
                Id = Guid.NewGuid(),
                UserId = Guid.NewGuid(),
                TemplateId = Guid.NewGuid(),
                Status = status,
                QueueMediaType = mediaType,
                QueueTier = TemplateGenerationQueue.TierFree,
                SourceImageUrl = "https://cdn.example.test/source.jpg",
                SourceImageFileName = "source.jpg",
                SourceImageContentType = "image/jpeg",
                CreatedAtUtc = now,
                QueuedAtUtc = now,
                UpdatedAtUtc = now
            })
            .ToArray();
        dbContext.TemplateGenerationJobs.AddRange(jobs);
        await dbContext.SaveChangesAsync();
        return jobs;
    }

    private static TemplateGenerationProviderAttemptReservation CreateReservation(
        Guid generationJobId,
        int tokenSeed,
        TemplateGenerationProviderAttemptStage stage = TemplateGenerationProviderAttemptStage.ImageGeneration)
    {
        var now = DateTime.UtcNow;
        return new TemplateGenerationProviderAttemptReservation(
            generationJobId,
            stage,
            "fal",
            tokenSeed.ToString("X64"),
            now.AddMinutes(3),
            now.AddMinutes(30),
            now.AddMinutes(40));
    }

    private static TemplateGenerationProviderAttempt CreatePersistedAttempt(
        Guid generationJobId,
        string submissionTokenHash,
        string? providerRequestId,
        DateTime createdAtUtc) => new()
        {
            Id = Guid.NewGuid(),
            GenerationJobId = generationJobId,
            Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
            Ordinal = 1,
            State = TemplateGenerationProviderAttemptState.ProviderQueued,
            Provider = "fal",
            SubmissionTokenHash = submissionTokenHash,
            ProviderRequestId = providerRequestId,
            SubmissionDeadlineAtUtc = createdAtUtc.AddMinutes(3),
            ProcessingDeadlineAtUtc = createdAtUtc.AddMinutes(30),
            ReconciliationDeadlineAtUtc = createdAtUtc.AddMinutes(40),
            NextPollAtUtc = createdAtUtc.AddSeconds(5),
            CreatedAtUtc = createdAtUtc,
            UpdatedAtUtc = createdAtUtc
        };

    private static TemplateGenerationProviderAttempt CreateRecoveryAttempt(
        DateTime createdAtUtc,
        TemplateGenerationProviderAttemptState state,
        DateTime? nextPollAtUtc,
        string? providerRequestId,
        int ordinal) => new()
        {
            Id = Guid.NewGuid(),
            GenerationJobId = Guid.NewGuid(),
            Stage = TemplateGenerationProviderAttemptStage.ImageGeneration,
            Ordinal = ordinal,
            State = state,
            Provider = "fal",
            SubmissionTokenHash = ordinal.ToString("X64"),
            ProviderRequestId = providerRequestId,
            NextPollAtUtc = nextPollAtUtc,
            SubmissionDeadlineAtUtc = createdAtUtc.AddMinutes(3),
            ProcessingDeadlineAtUtc = createdAtUtc.AddMinutes(30),
            ReconciliationDeadlineAtUtc = createdAtUtc.AddMinutes(40),
            Version = ordinal,
            CreatedAtUtc = createdAtUtc,
            UpdatedAtUtc = createdAtUtc.AddMinutes(1)
        };

    private static TemplateProviderWebhookInbox CreateWebhookInbox(
        string deduplicationKey,
        TemplateProviderWebhookInboxStatus status,
        DateTime statusChangedAtUtc) => new()
        {
            Id = Guid.NewGuid(),
            Provider = "fal",
            DeduplicationKey = deduplicationKey,
            EventType = "IN_PROGRESS",
            PayloadJson = "{}",
            Status = status,
            SignatureVerifiedAtUtc = statusChangedAtUtc,
            ReceivedAtUtc = statusChangedAtUtc,
            NextAttemptAtUtc = statusChangedAtUtc,
            AttemptCount = status == TemplateProviderWebhookInboxStatus.Queued ? 0 : 1,
            FailureCount = status is TemplateProviderWebhookInboxStatus.Failed
            or TemplateProviderWebhookInboxStatus.DeadLettered
                ? 1
                : 0,
            ProcessedAtUtc = status == TemplateProviderWebhookInboxStatus.Processed
            ? statusChangedAtUtc
            : null,
            DeadLetteredAtUtc = status == TemplateProviderWebhookInboxStatus.DeadLettered
            ? statusChangedAtUtc
            : null,
            LastErrorCode = status is TemplateProviderWebhookInboxStatus.Failed
            or TemplateProviderWebhookInboxStatus.DeadLettered
                ? "templates.provider_webhook_reconciliation_failed"
                : null,
            CreatedAtUtc = statusChangedAtUtc,
            UpdatedAtUtc = statusChangedAtUtc
        };

    private sealed class MutableRuntimePolicyProvider(TemplateGenerationRuntimePolicySnapshot current)
        : ITemplateGenerationRuntimePolicyProvider
    {
        public TemplateGenerationRuntimePolicySnapshot Current { get; set; } = current;

        public Task<TemplateGenerationRuntimePolicySnapshot> GetRuntimePolicyAsync(
            CancellationToken cancellationToken) => Task.FromResult(Current);
    }

    private sealed class StaticRuntimeSnapshotService(TemplateProviderRuntimeSnapshot snapshot)
        : IFalProviderRuntimeSnapshotService
    {
        public Task<TemplateProviderRuntimeSnapshot> GetSnapshotAsync(CancellationToken cancellationToken) =>
            Task.FromResult(snapshot);

        public Task<TemplateProviderRuntimeSnapshot> RefreshAsync(
            bool force,
            CancellationToken cancellationToken) => Task.FromResult(snapshot);
    }

    private sealed class ThrowingHttpClientFactory : IHttpClientFactory
    {
        public HttpClient CreateClient(string name) =>
            throw new InvalidOperationException("GetSnapshotAsync must not call the fal billing endpoint.");
    }
}
