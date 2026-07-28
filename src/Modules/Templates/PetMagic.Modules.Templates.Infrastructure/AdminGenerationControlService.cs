using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class AdminGenerationControlService(
    TemplatesDbContext dbContext,
    ITemplateGenerationRuntimeSettingsProvider runtimeSettings,
    FalProviderHealthMonitor providerMonitor,
    GenerationOperationalAlertService alertService,
    IAdminAuditLog? adminAuditLog,
    ILogger<AdminGenerationControlService> logger,
    IRenderGenerationWorkerClient? renderClient = null) : IAdminGenerationControlService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan ManualProviderRefreshCooldown = TimeSpan.FromSeconds(5);

    public Task<Result<AdminGenerationControlResponse>> GetAsync(
        Guid adminUserId,
        CancellationToken cancellationToken) => BuildResponseAsync(adminUserId, cancellationToken);

    public async Task<Result<AdminGenerationControlResponse>> UpdateAsync(
        UpdateAdminGenerationControlCommand command,
        CancellationToken cancellationToken)
    {
        var validationError = Validate(command);
        if (validationError is not null)
        {
            return Result.Failure<AdminGenerationControlResponse>(validationError);
        }

        var row = await dbContext.TemplateGenerationRuntimeSettings
            .SingleOrDefaultAsync(
                x => x.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId,
                cancellationToken);
        if (row is null)
        {
            return Result.Failure<AdminGenerationControlResponse>(new Error(
                "templates.generation_control_unavailable",
                "Generation runtime settings are not initialized."));
        }

        if (row.Version != command.ExpectedVersion)
        {
            return VersionConflict();
        }

        var oldValue = MapSettings(row);
        dbContext.Entry(row).Property(x => x.Version).OriginalValue = command.ExpectedVersion;
        row.Version++;
        row.GlobalMaxConcurrent = command.GlobalMaxConcurrent;
        row.ImageMaxConcurrent = command.ImageMaxConcurrent;
        row.ImageProtectedConcurrent = command.ImageProtectedConcurrent;
        row.VideoGuaranteedConcurrent = command.VideoGuaranteedConcurrent;
        row.VideoMaxConcurrent = command.VideoMaxConcurrent;
        row.VideoBorrowMaxConcurrent = command.VideoBorrowMaxConcurrent;
        row.WorkerLoopsPerInstance = command.WorkerLoopsPerInstance;
        row.FalConfiguredConcurrency = command.FalConfiguredConcurrency;
        row.FalReservedConcurrency = command.FalReservedConcurrency;
        row.FalBalanceLowThresholdUsd = command.FalBalanceLowThresholdUsd;
        row.FalBalanceCriticalThresholdUsd = command.FalBalanceCriticalThresholdUsd;
        row.LastChangeReason = command.Reason.Trim();
        row.UpdatedByAdminId = command.ActorUserId;
        row.UpdatedAtUtc = DateTime.UtcNow;

        var eventId = Guid.NewGuid();
        var pendingAudit = TemplateAdminAuditOutbox.Enqueue(
            dbContext,
            new AdminAuditEntry(
                "templates.generation_control.updated",
                "template_generation_runtime_settings",
                row.Id.ToString("D"),
                JsonSerializer.Serialize(oldValue, JsonOptions),
                JsonSerializer.Serialize(MapSettings(row), JsonOptions),
                command.Reason.Trim(),
                EventId: eventId,
                ActorUserId: command.ActorUserId,
                CorrelationId: command.CorrelationId)
            {
                ActorRole = command.ActorRole,
                OccurredAtUtc = row.UpdatedAtUtc
            });

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            dbContext.ChangeTracker.Clear();
            return VersionConflict();
        }

        await TemplateAdminAuditOutbox.TryDeliverAsync(
            dbContext,
            adminAuditLog,
            logger,
            pendingAudit,
            cancellationToken);
        await runtimeSettings.RefreshAsync(cancellationToken);
        try
        {
            await alertService.EvaluateAsync(cancellationToken);
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Generation operational alerts could not be refreshed after a settings update. ExceptionType={ExceptionType}",
                exception.GetType().Name);
        }
        return await BuildResponseAsync(command.ActorUserId, cancellationToken);
    }

    public async Task<Result<AdminGenerationControlResponse>> RefreshProviderAsync(
        Guid adminUserId,
        CancellationToken cancellationToken)
    {
        var lastCheckedAt = await dbContext.TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .MaxAsync(x => (DateTime?)x.CheckedAtUtc, cancellationToken);
        if (lastCheckedAt is null || DateTime.UtcNow - lastCheckedAt >= ManualProviderRefreshCooldown)
        {
            await providerMonitor.RefreshNowAsync(cancellationToken);
        }

        return await BuildResponseAsync(adminUserId, cancellationToken);
    }

    public async Task<Result<AdminGenerationOperationalAlertResponse>> AcknowledgeAlertAsync(
        Guid alertId,
        Guid adminUserId,
        CancellationToken cancellationToken)
    {
        var alert = await dbContext.TemplateGenerationOperationalAlerts
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == alertId, cancellationToken);
        if (alert is null)
        {
            return Result.Failure<AdminGenerationOperationalAlertResponse>(new Error(
                "templates.generation_alert_not_found",
                "Generation operational alert was not found."));
        }

        var acknowledgement = await dbContext.TemplateGenerationOperationalAlertAcknowledgements
            .SingleOrDefaultAsync(
                x => x.AlertId == alertId && x.AdminUserId == adminUserId,
                cancellationToken);
        var acknowledgedAtUtc = DateTime.UtcNow;
        if (acknowledgement is null)
        {
            acknowledgement = new TemplateGenerationOperationalAlertAcknowledgement
            {
                AlertId = alertId,
                AdminUserId = adminUserId,
                AlertActivatedAtUtc = alert.ActivatedAtUtc,
                AcknowledgedAtUtc = acknowledgedAtUtc
            };
            dbContext.TemplateGenerationOperationalAlertAcknowledgements.Add(acknowledgement);
            try
            {
                await dbContext.SaveChangesAsync(cancellationToken);
                await dbContext.Entry(acknowledgement).ReloadAsync(cancellationToken);
            }
            catch (DbUpdateException)
            {
                dbContext.Entry(acknowledgement).State = EntityState.Detached;
                var persistedAcknowledgement = await dbContext.TemplateGenerationOperationalAlertAcknowledgements
                    .AsNoTracking()
                    .SingleOrDefaultAsync(
                        x => x.AlertId == alertId && x.AdminUserId == adminUserId,
                        cancellationToken);
                if (persistedAcknowledgement is null)
                {
                    throw;
                }

                acknowledgement = persistedAcknowledgement;
            }
        }

        if (acknowledgement.AlertActivatedAtUtc != alert.ActivatedAtUtc)
        {
            acknowledgement.AlertActivatedAtUtc = alert.ActivatedAtUtc;
            acknowledgement.AcknowledgedAtUtc = acknowledgedAtUtc;
            dbContext.TemplateGenerationOperationalAlertAcknowledgements.Update(acknowledgement);
            await dbContext.SaveChangesAsync(cancellationToken);
        }

        return Result.Success(MapAlert(
            alert,
            acknowledgement.AlertActivatedAtUtc == alert.ActivatedAtUtc
                ? acknowledgement.AcknowledgedAtUtc
                : null));
    }

    private async Task<Result<AdminGenerationControlResponse>> BuildResponseAsync(
        Guid adminUserId,
        CancellationToken cancellationToken)
    {
        await runtimeSettings.RefreshAsync(cancellationToken);
        var current = runtimeSettings.Current;
        var row = await dbContext.TemplateGenerationRuntimeSettings
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == TemplateGenerationRuntimeSettingsProvider.SettingsId, cancellationToken);

        var queueCounts = await dbContext.TemplateGenerationJobs
            .AsNoTracking()
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                || x.Status == TemplateGenerationStatus.Processing
                || x.Status == TemplateGenerationStatus.SubmittingToProvider
                || x.Status == TemplateGenerationStatus.ProviderQueued
                || x.Status == TemplateGenerationStatus.ProviderProcessing
                || x.Status == TemplateGenerationStatus.ImportingMedia)
            .GroupBy(x => new { x.Status, x.QueueMediaType })
            .Select(x => new { x.Key.Status, x.Key.QueueMediaType, Count = x.LongCount() })
            .ToArrayAsync(cancellationToken);
        var activeImage = queueCounts
            .Where(x => x.Status != TemplateGenerationStatus.Queued
                && TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType) == TemplateGenerationQueue.MediaTypeImage)
            .Sum(x => x.Count);
        var activeVideo = queueCounts
            .Where(x => x.Status != TemplateGenerationStatus.Queued
                && TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType) == TemplateGenerationQueue.MediaTypeVideo)
            .Sum(x => x.Count);
        var queuedImage = queueCounts
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType) == TemplateGenerationQueue.MediaTypeImage)
            .Sum(x => x.Count);
        var queuedVideo = queueCounts
            .Where(x => x.Status == TemplateGenerationStatus.Queued
                && TemplateGenerationQueue.NormalizeMediaType(x.QueueMediaType) == TemplateGenerationQueue.MediaTypeVideo)
            .Sum(x => x.Count);
        var activeGlobal = activeImage + activeVideo;
        var effectiveImageMax = TemplateGenerationCapacityPolicy.ResolveEffectiveImageMax(
            current,
            activeVideo,
            queuedVideo);
        var borrowedVideo = Math.Max(0, activeVideo - current.VideoGuaranteedConcurrent);
        var isDraining = current.NewClaimsPaused
            || activeGlobal > current.GlobalMaxConcurrent
            || activeImage > effectiveImageMax
            || activeVideo > current.VideoMaxConcurrent;

        var now = DateTime.UtcNow;
        var freshAfter = now.Subtract(GenerationOperationalAlertService.WorkerStaleAfter);
        var fingerprints = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(x => x.Component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            .OrderByDescending(x => x.LastSeenAtUtc)
            .Take(100)
            .ToArrayAsync(cancellationToken);
        var workers = fingerprints.Select(x =>
        {
            var age = Math.Max(0, (long)(now - x.LastSeenAtUtc).TotalSeconds);
            var stale = x.LastSeenAtUtc < freshAfter;
            return new AdminGenerationWorkerResponse(
                x.Id.ToString("D"),
                x.LastSeenAtUtc,
                age,
                x.AppliedSettingsVersion,
                x.ConfiguredLoops,
                stale,
                !stale
                    && x.AppliedSettingsVersion == current.Version
                    && x.NewClaimsPaused == current.NewClaimsPaused,
                x.NewClaimsPaused);
        }).ToArray();

        var provider = await dbContext.TemplateFalProviderHealthSnapshots
            .AsNoTracking()
            .OrderByDescending(x => x.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var providerStale = !FalProviderHealthPolicy.IsSnapshotCurrent(provider?.LastSuccessAtUtc, now);
        var inflight = queueCounts
            .Where(x => x.Status is TemplateGenerationStatus.SubmittingToProvider
                or TemplateGenerationStatus.ProviderQueued
                or TemplateGenerationStatus.ProviderProcessing)
            .Sum(x => x.Count);
        var balanceStatus = providerStale || provider?.BalanceUsd is null
            ? "unknown"
            : provider.BalanceUsd <= current.FalBalanceCriticalThresholdUsd
                ? "critical"
                : provider.BalanceUsd <= current.FalBalanceLowThresholdUsd
                    ? "low"
                    : "healthy";

        var alerts = await dbContext.TemplateGenerationOperationalAlerts
            .AsNoTracking()
            .Where(x => x.ResolvedAtUtc == null || x.ResolvedAtUtc >= now.AddDays(-7))
            .OrderBy(x => x.ResolvedAtUtc != null)
            .ThenByDescending(x => x.UpdatedAtUtc)
            .Take(100)
            .ToArrayAsync(cancellationToken);
        var alertIds = alerts.Select(x => x.Id).ToArray();
        var acknowledgements = await dbContext.TemplateGenerationOperationalAlertAcknowledgements
            .AsNoTracking()
            .Where(x => x.AdminUserId == adminUserId && alertIds.Contains(x.AlertId))
            .ToDictionaryAsync(x => x.AlertId, cancellationToken);

        var render = await BuildRenderStatusAsync(cancellationToken);
        var reportedFreshLoopCount = workers.Where(x => !x.IsStale).Sum(x => x.ConfiguredLoops);
        var renderLoopCeiling = render?.ActiveInstances is { } activeInstances
            ? activeInstances * current.WorkerLoopsPerInstance
            : int.MaxValue;
        var freshLoopCount = Math.Min(reportedFreshLoopCount, renderLoopCeiling);
        var health = balanceStatus is "critical" or "unknown"
            ? "critical"
            : isDraining
                || freshLoopCount < current.GlobalMaxConcurrent
                || workers.Any(x => !x.IsStale && !x.IsConfigCurrent)
                    ? "degraded"
                    : "healthy";

        var settingsResponse = row is null
            ? MapSettings(current)
            : MapSettings(row);
        return Result.Success(new AdminGenerationControlResponse(
            settingsResponse,
            new AdminGenerationCapacityStatusResponse(
                now,
                activeGlobal,
                activeImage,
                activeVideo,
                queuedImage,
                queuedVideo,
                effectiveImageMax,
                borrowedVideo,
                isDraining,
                health),
            new AdminFalProviderStatusResponse(
                current.FalConfiguredConcurrency,
                current.FalReservedConcurrency,
                current.FalUsableConcurrency,
                inflight,
                provider?.BalanceUsd,
                balanceStatus,
                provider?.CheckedAtUtc,
                provider?.LastSuccessAtUtc,
                providerStale),
            workers,
            render,
            alerts.Select(x =>
            {
                acknowledgements.TryGetValue(x.Id, out var acknowledgement);
                return MapAlert(
                    x,
                    acknowledgement?.AlertActivatedAtUtc == x.ActivatedAtUtc
                        ? acknowledgement.AcknowledgedAtUtc
                        : null);
            }).ToArray()));
    }

    private async Task<AdminGenerationRenderStatusResponse?> BuildRenderStatusAsync(
        CancellationToken cancellationToken)
    {
        if (renderClient is null)
        {
            return null;
        }

        var activeStatuses = new[]
        {
            AdminGenerationRenderControlService.StatusRequested,
            AdminGenerationRenderControlService.StatusDraining,
            AdminGenerationRenderControlService.StatusScaling,
            AdminGenerationRenderControlService.StatusVerifying
        };
        var activeOperation = await dbContext.TemplateRenderScaleOperations
            .AsNoTracking()
            .Where(x => activeStatuses.Contains(x.Status))
            .OrderByDescending(x => x.CreatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
        var operationResponse = activeOperation is null
            ? null
            : AdminGenerationRenderControlService.Map(activeOperation);

        if (!renderClient.IsConfigured)
        {
            return new AdminGenerationRenderStatusResponse(
                false,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                false,
                RenderGenerationWorkerErrors.NotConfigured.Code,
                operationResponse);
        }

        var targetResult = await renderClient.GetTargetStatusAsync(cancellationToken);
        if (targetResult.IsFailure)
        {
            return new AdminGenerationRenderStatusResponse(
                true,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                false,
                targetResult.Error.Code,
                operationResponse);
        }

        var instancesResult = await renderClient.ListInstancesAsync(cancellationToken);
        var target = targetResult.Value;
        return new AdminGenerationRenderStatusResponse(
            true,
            target.ServiceId,
            target.Name,
            target.Type,
            target.Plan,
            target.Region,
            target.DesiredInstances,
            instancesResult.IsSuccess ? instancesResult.Value.Count : null,
            target.AutoscalingEnabled,
            instancesResult.IsFailure ? instancesResult.Error.Code : null,
            operationResponse);
    }

    private static Error? Validate(UpdateAdminGenerationControlCommand command)
    {
        if (command.ExpectedVersion <= 0)
        {
            return Invalid("expectedVersion");
        }

        if (command.GlobalMaxConcurrent <= 0
            || command.ImageMaxConcurrent <= 0
            || command.VideoGuaranteedConcurrent <= 0
            || command.VideoMaxConcurrent <= 0
            || command.FalConfiguredConcurrency <= 0)
        {
            return Invalid("concurrency");
        }

        if (command.FalReservedConcurrency < 0
            || command.GlobalMaxConcurrent > command.FalConfiguredConcurrency - command.FalReservedConcurrency)
        {
            return Invalid("falReservedConcurrency");
        }

        if (command.ImageMaxConcurrent > command.GlobalMaxConcurrent
            || command.VideoMaxConcurrent > command.GlobalMaxConcurrent
            || command.ImageProtectedConcurrent <= 0
            || command.ImageProtectedConcurrent > command.ImageMaxConcurrent
            || command.VideoGuaranteedConcurrent > command.VideoMaxConcurrent
            || command.VideoBorrowMaxConcurrent < 0
            || command.VideoGuaranteedConcurrent + command.VideoBorrowMaxConcurrent < command.VideoMaxConcurrent)
        {
            return Invalid("laneConcurrency");
        }

        if (command.WorkerLoopsPerInstance is < 1 or > 2)
        {
            return Invalid("workerLoopsPerInstance");
        }

        if (command.FalBalanceLowThresholdUsd < 0
            || command.FalBalanceCriticalThresholdUsd < 0
            || command.FalBalanceCriticalThresholdUsd > command.FalBalanceLowThresholdUsd)
        {
            return Invalid("falBalanceThresholds");
        }

        var reason = command.Reason?.Trim() ?? string.Empty;
        return reason.Length is < 3 or > 500 ? Invalid("reason") : null;
    }

    private static Error Invalid(string field) => new(
        "templates.generation_control_invalid",
        $"Invalid generation control field: {field}.",
        new Dictionary<string, object?> { ["field"] = field });

    private static Result<AdminGenerationControlResponse> VersionConflict() =>
        Result.Failure<AdminGenerationControlResponse>(new Error(
            "templates.generation_control_version_conflict",
            "Generation runtime settings changed. Reload and review the latest version."));

    private static AdminGenerationRuntimeSettingsResponse MapSettings(TemplateGenerationRuntimeSettings row) => new(
        row.Version,
        row.GlobalMaxConcurrent,
        row.ImageMaxConcurrent,
        row.ImageProtectedConcurrent,
        row.VideoGuaranteedConcurrent,
        row.VideoMaxConcurrent,
        row.VideoBorrowMaxConcurrent,
        row.WorkerLoopsPerInstance,
        row.FalConfiguredConcurrency,
        row.FalReservedConcurrency,
        row.FalBalanceLowThresholdUsd,
        row.FalBalanceCriticalThresholdUsd,
        row.UpdatedAtUtc,
        row.UpdatedByAdminId);

    private static AdminGenerationRuntimeSettingsResponse MapSettings(TemplateGenerationRuntimeSnapshot row) => new(
        row.Version,
        row.GlobalMaxConcurrent,
        row.ImageMaxConcurrent,
        row.ImageProtectedConcurrent,
        row.VideoGuaranteedConcurrent,
        row.VideoMaxConcurrent,
        row.VideoBorrowMaxConcurrent,
        row.WorkerLoopsPerInstance,
        row.FalConfiguredConcurrency,
        row.FalReservedConcurrency,
        row.FalBalanceLowThresholdUsd,
        row.FalBalanceCriticalThresholdUsd,
        row.UpdatedAtUtc,
        null);

    private static AdminGenerationOperationalAlertResponse MapAlert(
        TemplateGenerationOperationalAlert alert,
        DateTime? acknowledgedAtUtc) => new(
            alert.Id,
            alert.Code,
            alert.Severity,
            alert.Title,
            alert.Message,
            alert.ActivatedAtUtc,
            alert.ResolvedAtUtc,
            acknowledgedAtUtc,
            alert.ResolvedAtUtc is null,
            acknowledgedAtUtc is not null);
}
