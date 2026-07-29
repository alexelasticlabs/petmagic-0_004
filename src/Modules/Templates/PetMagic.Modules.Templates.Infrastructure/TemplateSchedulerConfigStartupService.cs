using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateSchedulerConfigStartupService(
    IServiceScopeFactory scopeFactory,
    TemplatesOptions options,
    TemplateSchedulerConfigComponent componentConfig,
    IHostEnvironment environment,
    TemplateSchedulerConfigRuntimeState runtimeState,
    TemplateGenerationWorkerRuntimeState workerRuntimeState,
    ILogger<TemplateSchedulerConfigStartupService> logger) : IHostedService
{
    private static readonly TimeSpan ActiveFingerprintMaxAge = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan HeartbeatInterval = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan StartupFingerprintRetryBaseDelay = TimeSpan.FromSeconds(2);
    private const int StartupFingerprintMaxPersistenceAttempts = 6;

    private CancellationTokenSource? heartbeatCancellationTokenSource;
    private Task? heartbeatTask;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var component = componentConfig.Value;
        var profileName = string.IsNullOrWhiteSpace(environment.EnvironmentName)
            ? Environments.Production
            : environment.EnvironmentName.Trim();
        var fingerprint = TemplateSchedulerConfigFingerprint.Create(options, profileName, component);
        logger.LogInformation(
            "Template scheduler config startup fingerprint. Component={Component} ProfileName={ProfileName} Checksum={Checksum} Config={ConfigJson}",
            component,
            profileName,
            fingerprint.Checksum,
            fingerprint.SanitizedDumpJson);

        try
        {
            await PersistStartupFingerprintWithRetryAsync(component, profileName, fingerprint, cancellationToken);
        }
        catch (Exception exception) when (environment.IsDevelopment()
            && exception is not InvalidOperationException
            && !cancellationToken.IsCancellationRequested)
        {
            runtimeState.MarkMismatch(
                component,
                profileName,
                fingerprint.Checksum,
                $"startup_fingerprint_persistence_failed:{exception.GetType().Name}");
            logger.LogWarning(
                "Template scheduler config startup fingerprint persistence failed in Development. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
        }
    }

    private async Task PersistStartupFingerprintWithRetryAsync(
        string component,
        string profileName,
        TemplateSchedulerConfigFingerprintResult fingerprint,
        CancellationToken cancellationToken)
    {
        for (var attempt = 1; attempt <= StartupFingerprintMaxPersistenceAttempts; attempt++)
        {
            try
            {
                await PersistStartupFingerprintAsync(component, profileName, fingerprint, cancellationToken);
                return;
            }
            catch (TemplateSchedulerConfigMismatchException)
            {
                throw;
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception exception) when (attempt < StartupFingerprintMaxPersistenceAttempts)
            {
                var delay = TimeSpan.FromMilliseconds(StartupFingerprintRetryBaseDelay.TotalMilliseconds * attempt);
                logger.LogWarning(
                    "Template scheduler config startup fingerprint persistence failed; retrying. Attempt={Attempt} MaxAttempts={MaxAttempts} RetryDelayMilliseconds={RetryDelayMilliseconds} ExceptionType={ExceptionType}",
                    attempt,
                    StartupFingerprintMaxPersistenceAttempts,
                    (int)delay.TotalMilliseconds,
                    SafeLogValues.ExceptionType(exception));

                await Task.Delay(delay, cancellationToken);
            }
        }
    }

    private async Task PersistStartupFingerprintAsync(
        string component,
        string profileName,
        TemplateSchedulerConfigFingerprintResult fingerprint,
        CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();

        var otherComponent = component == TemplateSchedulerConfigFingerprint.ApiComponent
            ? TemplateSchedulerConfigFingerprint.GenerationWorkerComponent
            : TemplateSchedulerConfigFingerprint.ApiComponent;
        var other = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(x => x.Component == otherComponent && x.ProfileName == profileName)
            .Where(x => x.LastSeenAtUtc >= now.Subtract(ActiveFingerprintMaxAge))
            .OrderByDescending(x => x.StartedAtUtc)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        var isMismatch = other is not null
            && !string.Equals(other.Checksum, fingerprint.Checksum, StringComparison.Ordinal);
        var isGenerationWorker = string.Equals(
            component,
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
            StringComparison.Ordinal);
        var mismatchDetails = isMismatch
            ? $"current={component}:{fingerprint.Checksum}; other={other!.Component}:{other.Checksum}; profile={profileName}"
            : null;

        var currentFingerprintId = Guid.NewGuid();
        dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
        {
            Id = currentFingerprintId,
            Component = component,
            ProfileName = profileName,
            Checksum = fingerprint.Checksum,
            ConfigJson = fingerprint.SanitizedDumpJson,
            StartedAtUtc = now,
            LastSeenAtUtc = now,
            MismatchDetected = isMismatch,
            MismatchDetails = mismatchDetails,
            GenerationSchedulerV2Enabled = isGenerationWorker ? options.GenerationSchedulerV2Enabled : null,
            GenerationDispatchConcurrency = isGenerationWorker ? options.GenerationDispatchConcurrency : null,
            ProviderReconciliationConcurrency = isGenerationWorker ? options.ProviderReconciliationConcurrency : null,
            MediaImportConcurrency = isGenerationWorker ? options.MediaImportConcurrency : null,
            GenerationMaintenanceConcurrency = isGenerationWorker ? options.GenerationMaintenanceConcurrency : null
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        if (isMismatch)
        {
            runtimeState.MarkMismatch(component, profileName, fingerprint.Checksum, mismatchDetails!);
            logger.LogCritical(
                "Template scheduler config fingerprint mismatch. Component={Component} ProfileName={ProfileName} Checksum={Checksum} OtherComponent={OtherComponent} OtherChecksum={OtherChecksum}",
                component,
                profileName,
                fingerprint.Checksum,
                other!.Component,
                other.Checksum);

            if (isGenerationWorker)
            {
                throw new TemplateSchedulerConfigMismatchException(
                    $"Template scheduler config fingerprint mismatch is fatal for GenerationWorker. {mismatchDetails}");
            }

            // API and worker are deployed sequentially on Render. Keep the API heartbeat alive so
            // it can converge automatically when the matching worker revision starts. The API
            // remains degraded, and the postdeploy gate remains closed, until that happens.
            StartHeartbeat(currentFingerprintId);
            return;
        }

        runtimeState.MarkHealthy(component, profileName, fingerprint.Checksum);
        StartHeartbeat(currentFingerprintId);
    }

    public async Task StopAsync(CancellationToken cancellationToken)
    {
        if (heartbeatCancellationTokenSource is null || heartbeatTask is null)
        {
            return;
        }

        await heartbeatCancellationTokenSource.CancelAsync();

        try
        {
            await heartbeatTask.WaitAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            heartbeatCancellationTokenSource.Dispose();
            heartbeatCancellationTokenSource = null;
            heartbeatTask = null;
        }
    }

    private void StartHeartbeat(Guid fingerprintId)
    {
        heartbeatCancellationTokenSource = new CancellationTokenSource();
        heartbeatTask = RunHeartbeatAsync(fingerprintId, heartbeatCancellationTokenSource.Token);
    }

    private async Task RunHeartbeatAsync(Guid fingerprintId, CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(HeartbeatInterval);

        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken))
            {
                try
                {
                    if (!await RefreshHeartbeatAsync(fingerprintId, cancellationToken))
                    {
                        return;
                    }
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception exception)
                {
                    logger.LogWarning(
                        "Template scheduler config heartbeat iteration failed; the next heartbeat will retry. FingerprintId={FingerprintId} ExceptionType={ExceptionType}",
                        fingerprintId,
                        SafeLogValues.ExceptionType(exception));
                }
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
    }

    internal async Task<bool> RefreshHeartbeatAsync(
        Guid fingerprintId,
        CancellationToken cancellationToken)
    {
        using var scope = scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
        var fingerprint = await dbContext.TemplateRuntimeConfigFingerprints
            .FirstOrDefaultAsync(x => x.Id == fingerprintId, cancellationToken);
        if (fingerprint is null)
        {
            return false;
        }

        var now = DateTime.UtcNow;
        fingerprint.LastSeenAtUtc = now;
        if (string.Equals(
            componentConfig.Value,
            TemplateSchedulerConfigFingerprint.GenerationWorkerComponent,
            StringComparison.Ordinal))
        {
            fingerprint.GenerationSchedulerV2Enabled = options.GenerationSchedulerV2Enabled;
            fingerprint.GenerationDispatchConcurrency = options.GenerationDispatchConcurrency;
            fingerprint.ProviderReconciliationConcurrency = options.ProviderReconciliationConcurrency;
            fingerprint.MediaImportConcurrency = options.MediaImportConcurrency;
            fingerprint.GenerationMaintenanceConcurrency = options.GenerationMaintenanceConcurrency;
            fingerprint.LastProgressAtUtc = workerRuntimeState.LastProgressAtUtc;
            var policyProvider = scope.ServiceProvider.GetService<ITemplateGenerationRuntimePolicyProvider>();
            if (policyProvider is not null)
            {
                var policy = await policyProvider.GetRuntimePolicyAsync(cancellationToken);
                fingerprint.AppliedPolicyRevision = policy.Revision;
            }
        }

        var otherComponent = string.Equals(
            componentConfig.Value,
            TemplateSchedulerConfigFingerprint.ApiComponent,
            StringComparison.Ordinal)
            ? TemplateSchedulerConfigFingerprint.GenerationWorkerComponent
            : TemplateSchedulerConfigFingerprint.ApiComponent;
        var other = await dbContext.TemplateRuntimeConfigFingerprints
            .AsNoTracking()
            .Where(x => x.Component == otherComponent && x.ProfileName == fingerprint.ProfileName)
            .Where(x => x.LastSeenAtUtc >= now.Subtract(ActiveFingerprintMaxAge))
            .OrderByDescending(x => x.StartedAtUtc)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        var isMismatch = other is not null
            && !string.Equals(other.Checksum, fingerprint.Checksum, StringComparison.Ordinal);
        var mismatchDetails = isMismatch
            ? $"current={fingerprint.Component}:{fingerprint.Checksum}; other={other!.Component}:{other.Checksum}; profile={fingerprint.ProfileName}"
            : null;
        fingerprint.MismatchDetected = isMismatch;
        fingerprint.MismatchDetails = mismatchDetails;

        await dbContext.SaveChangesAsync(cancellationToken);
        if (isMismatch)
        {
            runtimeState.MarkMismatch(
                fingerprint.Component,
                fingerprint.ProfileName,
                fingerprint.Checksum,
                mismatchDetails!);
        }
        else
        {
            runtimeState.MarkHealthy(
                fingerprint.Component,
                fingerprint.ProfileName,
                fingerprint.Checksum);
        }

        return true;
    }

    private sealed class TemplateSchedulerConfigMismatchException(string message) : InvalidOperationException(message);
}
