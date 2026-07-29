using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplateGenerationControlService(
    TemplatesDbContext dbContext,
    IFalProviderRuntimeSnapshotService providerRuntimeSnapshotService,
    TemplatesOptions options,
    ITemplateGenerationBilling generationBilling,
    IAdminAuditLog? adminAuditLog = null,
    IHttpContextAccessor? httpContextAccessor = null,
    ILogger<TemplateGenerationControlService>? logger = null)
    : ITemplateGenerationControlService, ITemplateGenerationRuntimePolicyProvider
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private const string AuditAction = "templates.generation_control.policy_updated";
    private const string ReceiptScope = "templates:generation-control-policy";
    private const int IdempotencyKeyMaxLength = 256;
    private const int ReasonMinLength = 3;
    private const int ReasonMaxLength = 500;
    private const int CapacityLimitMax = 10_000;
    private static readonly TimeSpan WorkerHeartbeatMaxAge = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan ConfirmationMaxAge = TimeSpan.FromDays(7);
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TemplateGenerationProviderAttemptState[] ActiveAttemptStates =
    [
        TemplateGenerationProviderAttemptState.SubmitReserved,
        TemplateGenerationProviderAttemptState.Submitting,
        TemplateGenerationProviderAttemptState.ProviderQueued,
        TemplateGenerationProviderAttemptState.ProviderProcessing,
        TemplateGenerationProviderAttemptState.SubmissionUnknown
    ];
    private static readonly TemplateGenerationStatus[] ActiveGenerationStatuses =
    [
        TemplateGenerationStatus.Queued,
        TemplateGenerationStatus.Processing,
        TemplateGenerationStatus.Retrying,
        TemplateGenerationStatus.SubmittingToProvider,
        TemplateGenerationStatus.ProviderQueued,
        TemplateGenerationStatus.ProviderProcessing,
        TemplateGenerationStatus.ImportingMedia,
        TemplateGenerationStatus.CancellationRequested
    ];

    public async Task<Result<AdminTemplateGenerationControlResponse>> GetAsync(
        CancellationToken cancellationToken)
    {
        var policy = await EnsurePolicyAsync(cancellationToken);
        return Result.Success(await BuildResponseAsync(policy, cancellationToken));
    }

    public async Task<TemplateGenerationRuntimePolicySnapshot> GetRuntimePolicyAsync(
        CancellationToken cancellationToken)
    {
        var policy = await dbContext.TemplateGenerationControlPolicies
            .AsNoTracking()
            .SingleOrDefaultAsync(
                x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId,
                cancellationToken)
            ?? await EnsurePolicyAsync(cancellationToken);
        return TemplateGenerationRuntimePolicyCalculator.Calculate(policy);
    }

    public async Task<Result<AdminTemplateGenerationControlResponse>> RefreshProviderAsync(
        CancellationToken cancellationToken)
    {
        await providerRuntimeSnapshotService.RefreshAsync(force: true, cancellationToken);
        return await GetAsync(cancellationToken);
    }

    public async Task<Result<AdminTemplateGenerationControlResponse>> UpdatePolicyAsync(
        UpdateAdminTemplateGenerationControlPolicyCommand command,
        CancellationToken cancellationToken)
    {
        var normalizedIdempotencyKey = Normalize(command.IdempotencyKey);
        if (normalizedIdempotencyKey is null || normalizedIdempotencyKey.Length > IdempotencyKeyMaxLength)
        {
            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlIdempotencyKeyInvalid);
        }

        var normalizedReason = Normalize(command.Reason);
        if (normalizedReason is null
            || normalizedReason.Length < ReasonMinLength
            || normalizedReason.Length > ReasonMaxLength)
        {
            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlReasonInvalid);
        }

        if (!IsValidPolicy(command))
        {
            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlPolicyInvalid);
        }

        var requestHash = CreateRequestHash(command, normalizedReason);
        var existingReceipt = await FindReceiptAsync(
            command.ActorUserId,
            normalizedIdempotencyKey,
            cancellationToken);
        if (existingReceipt is not null)
        {
            return await ResolveReplayAsync(existingReceipt, requestHash, cancellationToken);
        }

        await EnsurePolicyAsync(cancellationToken);
        await using var transaction = await BeginTransactionAsync(cancellationToken);
        if (transaction is not null)
        {
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock({0})",
                [TemplateGenerationAdmissionLockKeys.Global],
                cancellationToken);
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext('templates:generation-control-policy'))",
                cancellationToken);
            await dbContext.Database.ExecuteSqlRawAsync(
                "SELECT pg_advisory_xact_lock(hashtext('templates:provider-capacity'))",
                cancellationToken);
        }

        existingReceipt = await FindReceiptAsync(
            command.ActorUserId,
            normalizedIdempotencyKey,
            cancellationToken);
        if (existingReceipt is not null)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return await ResolveReplayAsync(existingReceipt, requestHash, cancellationToken);
        }

        dbContext.ChangeTracker.Clear();
        var policy = transaction is null
            ? await dbContext.TemplateGenerationControlPolicies
                .SingleAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId, cancellationToken)
            : await dbContext.TemplateGenerationControlPolicies
                .FromSqlRaw(
                    "SELECT * FROM templates_generation_control_policy WHERE \"Id\" = {0} FOR UPDATE",
                    TemplateGenerationControlPolicyDefaults.PolicyId)
                .SingleAsync(cancellationToken);
        if (policy.Revision != command.ExpectedRevision)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlPolicyConflict);
        }

        var oldPolicyJson = SerializeAuditPolicy(policy);
        var now = DateTime.UtcNow;
        policy.Revision++;
        policy.AdmissionEnabled = command.AdmissionEnabled;
        policy.ConfirmedFalConcurrencyLimit = command.ConfirmedFalConcurrencyLimit;
        policy.ConfirmedAtUtc = now;
        policy.ReservedHeadroom = command.ReservedHeadroom;
        policy.ApplicationHardCeiling = command.ApplicationHardCeiling;
        policy.UpdatedAtUtc = now;
        policy.UpdatedByAdminUserId = command.ActorUserId;
        policy.LastReason = normalizedReason;

        var response = await BuildResponseAsync(policy, cancellationToken);
        var receiptId = CreateReceiptId(command.ActorUserId, normalizedIdempotencyKey);
        dbContext.TemplateGenerationControlPolicyCommandReceipts.Add(
            new TemplateGenerationControlPolicyCommandReceipt
            {
                Id = receiptId,
                ActorUserId = command.ActorUserId,
                IdempotencyKey = normalizedIdempotencyKey,
                RequestHash = requestHash,
                PolicyRevision = policy.Revision,
                ResponseJson = JsonSerializer.Serialize(response, JsonOptions),
                CreatedAtUtc = now
            });
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            new AdminAuditEntry(
                AuditAction,
                nameof(TemplateGenerationControlPolicy),
                policy.Id.ToString("D"),
                oldPolicyJson,
                SerializeAuditPolicy(policy),
                normalizedReason,
                SubjectUserId: null,
                EventId: receiptId,
                ActorUserId: command.ActorUserId,
                CorrelationId: CorrelationContext.ResolveOrCreate())
            {
                OccurredAtUtc = now
            },
            httpContextAccessor?.HttpContext);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            if (transaction is not null)
            {
                await transaction.CommitAsync(cancellationToken);
            }
        }
        catch (DbUpdateException)
        {
            if (transaction is not null)
            {
                await transaction.RollbackAsync(cancellationToken);
            }

            dbContext.ChangeTracker.Clear();
            var persistedReceipt = await FindReceiptAsync(
                command.ActorUserId,
                normalizedIdempotencyKey,
                cancellationToken);
            if (persistedReceipt is not null)
            {
                return await ResolveReplayAsync(persistedReceipt, requestHash, cancellationToken);
            }

            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlPolicyConflict);
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);

        logger?.LogWarning(
            "ADMIN ACTION: template generation control policy updated. Revision={Revision} AdmissionEnabled={AdmissionEnabled} ConfirmedFalConcurrencyLimit={ConfirmedFalConcurrencyLimit} ReservedHeadroom={ReservedHeadroom} ApplicationHardCeiling={ApplicationHardCeiling} ActorUserIdHash={ActorUserIdHash}",
            policy.Revision,
            policy.AdmissionEnabled,
            policy.ConfirmedFalConcurrencyLimit,
            policy.ReservedHeadroom,
            policy.ApplicationHardCeiling,
            TemplateLogSanitizer.SafeId(command.ActorUserId));

        return Result.Success(response);
    }

    private async Task<AdminTemplateGenerationControlResponse> BuildResponseAsync(
        TemplateGenerationControlPolicy policy,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var runtimePolicy = TemplateGenerationRuntimePolicyCalculator.Calculate(policy);
        var balance = await providerRuntimeSnapshotService.GetSnapshotAsync(cancellationToken);

        var queuedJobs = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                || x.Status == TemplateGenerationStatus.Retrying);
        var totalDepth = await queuedJobs.CountAsync(cancellationToken);
        var imageDepth = await queuedJobs.CountAsync(
            x => x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage,
            cancellationToken);
        var videoDepth = totalDepth - imageDepth;
        var oldestQueuedAtUtc = await queuedJobs
            .MinAsync(x => (DateTime?)x.QueuedAtUtc, cancellationToken);

        var stageRows = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => ActiveGenerationStatuses.Contains(x.Status))
            .GroupBy(x => x.Status)
            .Select(group => new { Stage = group.Key, Count = group.Count(), OldestAtUtc = group.Min(x => x.UpdatedAtUtc) })
            .OrderBy(x => x.Stage)
            .ToListAsync(cancellationToken);

        var activeAttempts = dbContext.TemplateGenerationProviderAttempts
            .AsNoTracking()
            .Where(x => ActiveAttemptStates.Contains(x.State));
        var attemptStageRows = await activeAttempts
            .GroupBy(x => x.Stage)
            .Select(group => new
            {
                Stage = group.Key,
                Count = group.Count(),
                OldestAtUtc = group.Min(x => x.CreatedAtUtc)
            })
            .OrderBy(x => x.Stage)
            .ToListAsync(cancellationToken);
        var attemptTotal = await activeAttempts.CountAsync(cancellationToken);
        var attemptImages = await activeAttempts.CountAsync(
            x => x.Stage == TemplateGenerationProviderAttemptStage.ImageGeneration,
            cancellationToken);
        var attemptPreprocessing = await activeAttempts.CountAsync(
            x => x.Stage == TemplateGenerationProviderAttemptStage.VideoPreprocessing,
            cancellationToken);
        var borrowedAttempts = await activeAttempts.CountAsync(
            x => x.IsBorrowedCapacity,
            cancellationToken);
        var submissionUnknownAttempts = activeAttempts
            .Where(x => x.State == TemplateGenerationProviderAttemptState.SubmissionUnknown);
        var submissionUnknownCount = await submissionUnknownAttempts.CountAsync(cancellationToken);
        var oldestSubmissionUnknownAtUtc = await submissionUnknownAttempts
            .MinAsync(x => (DateTime?)x.CreatedAtUtc, cancellationToken);
        var webhookDeadLetters = dbContext.TemplateProviderWebhookInbox
            .AsNoTracking()
            .Where(x => x.Status == TemplateProviderWebhookInboxStatus.DeadLettered);
        var webhookDeadLetterCount = await webhookDeadLetters.CountAsync(cancellationToken);
        var oldestWebhookDeadLetteredAtUtc = await webhookDeadLetters
            .MinAsync(x => x.DeadLetteredAtUtc, cancellationToken);

        var legacyInflight = dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => (x.Status == TemplateGenerationStatus.SubmittingToProvider
                    || x.Status == TemplateGenerationStatus.ProviderQueued
                    || x.Status == TemplateGenerationStatus.ProviderProcessing)
                && !x.ProviderAttempts.Any());
        var legacyTotal = await legacyInflight.CountAsync(cancellationToken);
        var legacyImages = await legacyInflight.CountAsync(
            x => x.QueueMediaType == TemplateGenerationQueue.MediaTypeImage,
            cancellationToken);
        var legacyPreprocessing = await legacyInflight.CountAsync(
            x => x.CurrentProviderStage == "video_preprocessing",
            cancellationToken);

        var inFlightTotal = attemptTotal + legacyTotal;
        var imageInFlight = attemptImages + legacyImages;
        var videoInFlight = inFlightTotal - imageInFlight;
        var activeWorkerThreshold = now.Subtract(WorkerHeartbeatMaxAge);
        var workerFingerprints = dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(x => x.Component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent);
        var activeWorkers = await workerFingerprints
            .Where(x => !x.MismatchDetected && x.LastSeenAtUtc >= activeWorkerThreshold)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ThenByDescending(x => x.StartedAtUtc)
            .ThenByDescending(x => x.Id)
            .ToArrayAsync(cancellationToken);
        var activeWorkerCount = activeWorkers.Length;
        var workerRuntime = ResolveWorkerRuntime(activeWorkers);
        var latestWorker = await workerFingerprints
            .OrderByDescending(x => x.LastSeenAtUtc)
            .ThenByDescending(x => x.StartedAtUtc)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);

        var alerts = BuildAlerts(
            policy,
            runtimePolicy,
            balance,
            latestWorker,
            activeWorkerCount,
            workerRuntime,
            submissionUnknownCount,
            oldestSubmissionUnknownAtUtc,
            webhookDeadLetterCount,
            oldestWebhookDeadLetteredAtUtc,
            now);
        return new AdminTemplateGenerationControlResponse(
            policy.Revision,
            policy.AdmissionEnabled,
            policy.ConfirmedFalConcurrencyLimit,
            policy.ConfirmedAtUtc,
            policy.ReservedHeadroom,
            policy.ApplicationHardCeiling,
            runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations,
            MapProfile(runtimePolicy.BaseProfile),
            MapProfile(runtimePolicy.EffectiveProfile),
            new AdminTemplateGenerationProviderBalanceResponse(
                balance.BalanceState.ToString().ToLowerInvariant(),
                balance.CurrentBalanceUsd,
                balance.LastSuccessfulAtUtc,
                balance.CheckedAtUtc),
            new AdminTemplateGenerationQueueCapacityResponse(
                totalDepth,
                imageDepth,
                videoDepth,
                oldestQueuedAtUtc,
                stageRows.Select(row => new AdminTemplateGenerationQueueStageResponse(
                    ToSnakeCase(row.Stage.ToString()),
                    row.Count,
                    row.OldestAtUtc))
                    .Concat(attemptStageRows.Select(row => new AdminTemplateGenerationQueueStageResponse(
                        $"provider_{ToSnakeCase(row.Stage.ToString())}",
                        row.Count,
                        row.OldestAtUtc)))
                    .ToArray()),
            new AdminTemplateGenerationLaneCapacityResponse(
                inFlightTotal,
                imageInFlight,
                videoInFlight,
                attemptPreprocessing + legacyPreprocessing,
                Math.Max(0, inFlightTotal - borrowedAttempts),
                borrowedAttempts,
                Math.Max(0, runtimePolicy.EffectiveProfile.VideoReservedConcurrentGenerations - videoInFlight),
                submissionUnknownCount),
            new AdminTemplateGenerationWorkerCapacityResponse(
                activeWorkerCount,
                workerRuntime.HeartbeatAtUtc,
                workerRuntime.AppliedPolicyRevision,
                workerRuntime.SchedulerV2Enabled,
                workerRuntime.DispatchConcurrency,
                workerRuntime.ReconciliationConcurrency,
                workerRuntime.MediaImportConcurrency,
                workerRuntime.MaintenanceConcurrency,
                workerRuntime.LastProgressAtUtc),
            alerts,
            now);
    }

    private static IReadOnlyList<AdminTemplateGenerationControlAlertResponse> BuildAlerts(
        TemplateGenerationControlPolicy policy,
        TemplateGenerationRuntimePolicySnapshot runtimePolicy,
        TemplateProviderRuntimeSnapshot balance,
        TemplateRuntimeConfigFingerprint? latestWorker,
        int activeWorkerCount,
        WorkerRuntimeReport workerRuntime,
        int submissionUnknownCount,
        DateTime? oldestSubmissionUnknownAtUtc,
        int webhookDeadLetterCount,
        DateTime? oldestWebhookDeadLetteredAtUtc,
        DateTime now)
    {
        var alerts = new List<AdminTemplateGenerationControlAlertResponse>();
        if (workerRuntime.SchedulerV2Enabled == false)
        {
            alerts.Add(new(
                "generation-scheduler-v2-disabled",
                workerRuntime.StartedAtUtc ?? policy.UpdatedAtUtc,
                "warning",
                "Scheduler V2 is disabled",
                "The worker is using the compatibility loop until the rollout flag is enabled."));
        }
        else if (activeWorkerCount > 0 && HasUnknownWorkerRuntimeConfiguration(workerRuntime))
        {
            alerts.Add(new(
                "generation-worker-runtime-config-unknown",
                workerRuntime.StartedAtUtc ?? policy.UpdatedAtUtc,
                "critical",
                "Generation worker runtime configuration is unknown",
                "Active workers have not reported one consistent Scheduler V2 and lane configuration."));
        }

        if (activeWorkerCount > 0
            && workerRuntime.AppliedPolicyRevision is not null
            && workerRuntime.AppliedPolicyRevision != policy.Revision)
        {
            alerts.Add(new(
                "generation-worker-policy-revision-stale",
                policy.UpdatedAtUtc,
                "critical",
                "Generation worker policy revision is stale",
                $"The worker applied policy revision {workerRuntime.AppliedPolicyRevision}; current revision is {policy.Revision}."));
        }

        if (!policy.AdmissionEnabled)
        {
            alerts.Add(new(
                "generation-admission-paused",
                policy.UpdatedAtUtc,
                "warning",
                "Generation admission is paused",
                "New generation requests are not being admitted."));
        }

        if (submissionUnknownCount > 0)
        {
            alerts.Add(new(
                "generation-provider-submission-unknown",
                oldestSubmissionUnknownAtUtc ?? now,
                "critical",
                "Provider submissions require reconciliation",
                $"{submissionUnknownCount} ambiguous provider submission(s) still occupy capacity and require an evidence-backed admin resolution."));
        }

        if (webhookDeadLetterCount > 0)
        {
            alerts.Add(new(
                "generation-provider-webhook-dead-letter",
                oldestWebhookDeadLetteredAtUtc ?? now,
                "critical",
                "Provider webhook reconciliation requires intervention",
                $"{webhookDeadLetterCount} provider webhook event(s) exhausted automatic reconciliation retries and were dead-lettered."));
        }

        if (policy.ConfirmedAtUtc < now.Subtract(ConfirmationMaxAge))
        {
            alerts.Add(new(
                "fal-concurrency-confirmation-stale",
                policy.ConfirmedAtUtc.Add(ConfirmationMaxAge),
                "warning",
                "fal.ai concurrency confirmation is stale",
                "Confirm the current fal.ai concurrency limit in the provider dashboard."));
        }

        if (runtimePolicy.EffectiveProfile.GlobalMaxConcurrentGenerations <= 0)
        {
            alerts.Add(new(
                "generation-effective-capacity-zero",
                policy.UpdatedAtUtc,
                "critical",
                "Effective generation capacity is zero",
                "Reserved headroom leaves no provider capacity for PetMagic."));
        }

        var balanceChangedAt = balance.StatusChangedAtUtc;
        if (balance.BalanceState == TemplateProviderBalanceState.Critical)
        {
            alerts.Add(new(
                "fal-balance-critical",
                balanceChangedAt,
                "critical",
                "fal.ai balance is critical",
                "New provider submissions must remain paused until the balance is replenished."));
        }
        else if (balance.BalanceState == TemplateProviderBalanceState.Low)
        {
            alerts.Add(new(
                "fal-balance-low",
                balanceChangedAt,
                "warning",
                "fal.ai balance is low",
                "Replenish the provider balance before it reaches the critical threshold."));
        }
        else if (balance.BalanceState == TemplateProviderBalanceState.Stale)
        {
            alerts.Add(new(
                "fal-balance-stale",
                balanceChangedAt,
                "warning",
                "fal.ai balance is stale",
                "The last known balance is still within the five-minute safety window."));
        }
        else if (balance.BalanceState == TemplateProviderBalanceState.Unknown)
        {
            alerts.Add(new(
                "fal-balance-unknown",
                balanceChangedAt,
                "critical",
                "fal.ai balance is unknown",
                "Provider balance has no usable recent snapshot."));
        }

        if (latestWorker?.MismatchDetected == true)
        {
            alerts.Add(new(
                "generation-worker-fingerprint-mismatch",
                latestWorker.StartedAtUtc,
                "critical",
                "Generation worker configuration mismatch",
                "The generation worker is not running with the expected scheduler configuration."));
        }

        if (activeWorkerCount == 0)
        {
            alerts.Add(new(
                "generation-worker-heartbeat-missing",
                latestWorker?.LastSeenAtUtc.Add(WorkerHeartbeatMaxAge) ?? policy.UpdatedAtUtc,
                "critical",
                "Generation worker heartbeat is missing",
                "No healthy generation worker reported during the last two minutes."));
        }

        return alerts;
    }

    private static WorkerRuntimeReport ResolveWorkerRuntime(
        IReadOnlyList<TemplateRuntimeConfigFingerprint> activeWorkers)
    {
        if (activeWorkers.Count == 0)
        {
            return new WorkerRuntimeReport(null, null, null, null, null, null, null, null, null);
        }

        var latestWorker = activeWorkers[0];
        return new WorkerRuntimeReport(
            latestWorker.StartedAtUtc,
            latestWorker.LastSeenAtUtc,
            ResolveConsensus(activeWorkers, worker => worker.AppliedPolicyRevision),
            ResolveConsensus(activeWorkers, worker => worker.GenerationSchedulerV2Enabled),
            ResolveConsensus(activeWorkers, worker => worker.GenerationDispatchConcurrency),
            ResolveConsensus(activeWorkers, worker => worker.ProviderReconciliationConcurrency),
            ResolveConsensus(activeWorkers, worker => worker.MediaImportConcurrency),
            ResolveConsensus(activeWorkers, worker => worker.GenerationMaintenanceConcurrency),
            activeWorkers
                .Where(worker => worker.LastProgressAtUtc.HasValue)
                .Select(worker => worker.LastProgressAtUtc)
                .Max());
    }

    private static bool HasUnknownWorkerRuntimeConfiguration(WorkerRuntimeReport workerRuntime) =>
        workerRuntime.AppliedPolicyRevision is null
        || workerRuntime.SchedulerV2Enabled is null
        || workerRuntime.DispatchConcurrency is null
        || workerRuntime.ReconciliationConcurrency is null
        || workerRuntime.MediaImportConcurrency is null
        || workerRuntime.MaintenanceConcurrency is null;

    private static T? ResolveConsensus<T>(
        IReadOnlyList<TemplateRuntimeConfigFingerprint> activeWorkers,
        Func<TemplateRuntimeConfigFingerprint, T?> selector)
        where T : struct
    {
        var first = selector(activeWorkers[0]);
        if (!first.HasValue)
        {
            return null;
        }

        for (var index = 1; index < activeWorkers.Count; index++)
        {
            var current = selector(activeWorkers[index]);
            if (!current.HasValue || !EqualityComparer<T>.Default.Equals(first.Value, current.Value))
            {
                return null;
            }
        }

        return first.Value;
    }

    private sealed record WorkerRuntimeReport(
        DateTime? StartedAtUtc,
        DateTime? HeartbeatAtUtc,
        long? AppliedPolicyRevision,
        bool? SchedulerV2Enabled,
        int? DispatchConcurrency,
        int? ReconciliationConcurrency,
        int? MediaImportConcurrency,
        int? MaintenanceConcurrency,
        DateTime? LastProgressAtUtc);

    private async Task<TemplateGenerationControlPolicy> EnsurePolicyAsync(CancellationToken cancellationToken)
    {
        var policy = await dbContext.TemplateGenerationControlPolicies
            .SingleOrDefaultAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId, cancellationToken);
        if (policy is not null)
        {
            return policy;
        }

        policy = TemplateGenerationControlPolicyDefaults.Create(DateTime.UtcNow);
        dbContext.TemplateGenerationControlPolicies.Add(policy);
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
            return policy;
        }
        catch (DbUpdateException)
        {
            dbContext.Entry(policy).State = EntityState.Detached;
            return await dbContext.TemplateGenerationControlPolicies
                .SingleAsync(x => x.Id == TemplateGenerationControlPolicyDefaults.PolicyId, cancellationToken);
        }
    }

    private Task<TemplateGenerationControlPolicyCommandReceipt?> FindReceiptAsync(
        Guid actorUserId,
        string idempotencyKey,
        CancellationToken cancellationToken)
    {
        return dbContext.TemplateGenerationControlPolicyCommandReceipts
            .AsNoTracking()
            .SingleOrDefaultAsync(
                receipt => receipt.ActorUserId == actorUserId
                    && receipt.IdempotencyKey == idempotencyKey,
                cancellationToken);
    }

    private async Task<Result<AdminTemplateGenerationControlResponse>> ResolveReplayAsync(
        TemplateGenerationControlPolicyCommandReceipt receipt,
        string requestHash,
        CancellationToken cancellationToken)
    {
        if (!string.Equals(receipt.RequestHash, requestHash, StringComparison.Ordinal))
        {
            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlIdempotencyConflict);
        }

        var response = JsonSerializer.Deserialize<AdminTemplateGenerationControlResponse>(
            receipt.ResponseJson,
            JsonOptions);
        if (response is null)
        {
            return Result.Failure<AdminTemplateGenerationControlResponse>(
                TemplatesErrors.GenerationControlPolicyConflict);
        }

        await TemplateAdminAuditOutbox.TryDeliverExistingAsync(
            dbContext,
            adminAuditLog,
            logger,
            receipt.Id,
            cancellationToken);
        return Result.Success(response);
    }

    private Task<IDbContextTransaction?> BeginTransactionAsync(CancellationToken cancellationToken)
    {
        return string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal)
            ? BeginNpgsqlTransactionAsync(cancellationToken)
            : Task.FromResult<IDbContextTransaction?>(null);
    }

    private async Task<IDbContextTransaction?> BeginNpgsqlTransactionAsync(CancellationToken cancellationToken) =>
        await dbContext.Database.BeginTransactionAsync(cancellationToken);

    private static bool IsValidPolicy(UpdateAdminTemplateGenerationControlPolicyCommand command)
    {
        return command.ExpectedRevision > 0
            && command.ConfirmedFalConcurrencyLimit > 0
            && command.ConfirmedFalConcurrencyLimit <= CapacityLimitMax
            && command.ReservedHeadroom >= 0
            && command.ReservedHeadroom < command.ConfirmedFalConcurrencyLimit
            && command.ApplicationHardCeiling > 0
            && command.ApplicationHardCeiling <= CapacityLimitMax;
    }

    private static AdminTemplateGenerationConcurrencyProfileResponse MapProfile(
        TemplateGenerationConcurrencyProfile profile) => new(
        profile.GlobalMaxConcurrentGenerations,
        profile.ImageReservedConcurrentGenerations,
        profile.ImageProtectedConcurrentGenerations,
        profile.ImageMaxConcurrentGenerations,
        profile.VideoReservedConcurrentGenerations,
        profile.VideoMaxConcurrentGenerations,
        profile.VideoBorrowMaxConcurrentGenerations,
        profile.VideoPreprocessingMaxConcurrentGenerations);

    private static string? Normalize(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private static string CreateRequestHash(
        UpdateAdminTemplateGenerationControlPolicyCommand command,
        string normalizedReason)
    {
        var canonical = string.Join(
            '|',
            command.ExpectedRevision,
            normalizedReason.Length,
            normalizedReason,
            command.AdmissionEnabled,
            command.ConfirmedFalConcurrencyLimit,
            command.ReservedHeadroom,
            command.ApplicationHardCeiling);
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(canonical)));
    }

    private static Guid CreateReceiptId(Guid actorUserId, string idempotencyKey)
    {
        var raw = $"{ReceiptScope}:{actorUserId:D}:{idempotencyKey}";
        return new Guid(SHA256.HashData(Encoding.UTF8.GetBytes(raw)).AsSpan(0, 16));
    }

    private static string SerializeAuditPolicy(TemplateGenerationControlPolicy policy) =>
        JsonSerializer.Serialize(new
        {
            policy.Revision,
            policy.AdmissionEnabled,
            policy.ConfirmedFalConcurrencyLimit,
            policy.ConfirmedAtUtc,
            policy.ReservedHeadroom,
            policy.ApplicationHardCeiling
        }, JsonOptions);

    private static string ToSnakeCase(string value)
    {
        var builder = new StringBuilder(value.Length + 8);
        for (var index = 0; index < value.Length; index++)
        {
            var character = value[index];
            if (char.IsUpper(character) && index > 0)
            {
                builder.Append('_');
            }

            builder.Append(char.ToLowerInvariant(character));
        }

        return builder.ToString();
    }
}
