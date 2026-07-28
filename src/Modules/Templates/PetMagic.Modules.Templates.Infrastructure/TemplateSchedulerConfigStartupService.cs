using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.Modules.Templates.Application.Abstractions;
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
    ILogger<TemplateSchedulerConfigStartupService> logger,
    ITemplateGenerationRuntimeSettingsProvider? generationRuntimeSettings = null) : IHostedService
{
    private static readonly TimeSpan ActiveFingerprintMaxAge = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan HeartbeatInterval = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan StartupFingerprintRetryBaseDelay = TimeSpan.FromSeconds(2);
    private const int StartupFingerprintMaxPersistenceAttempts = 6;

    private CancellationTokenSource? heartbeatCancellationTokenSource;
    private Task? heartbeatTask;
    private Guid? activeFingerprintId;

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
            .Where(x => !x.MismatchDetected)
            .Where(x => x.LastSeenAtUtc >= now.Subtract(ActiveFingerprintMaxAge))
            .OrderByDescending(x => x.StartedAtUtc)
            .ThenByDescending(x => x.Id)
            .FirstOrDefaultAsync(cancellationToken);
        var isMismatch = other is not null
            && !string.Equals(other.Checksum, fingerprint.Checksum, StringComparison.Ordinal);
        var mismatchDetails = isMismatch
            ? $"current={component}:{fingerprint.Checksum}; other={other!.Component}:{other.Checksum}; profile={profileName}"
            : null;

        var currentFingerprintId = Guid.NewGuid();
        var runtimeSnapshot = generationRuntimeSettings?.Current;
        dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
        {
            Id = currentFingerprintId,
            Component = component,
            ProfileName = profileName,
            Checksum = fingerprint.Checksum,
            ConfigJson = fingerprint.SanitizedDumpJson,
            StartedAtUtc = now,
            LastSeenAtUtc = now,
            AppliedSettingsVersion = runtimeSnapshot?.Version ?? 0,
            ConfiguredLoops = runtimeSnapshot?.WorkerLoopsPerInstance
                ?? Math.Clamp(options.MaxConcurrentJobsPerWorker, 1, 2),
            NewClaimsPaused = runtimeSnapshot?.NewClaimsPaused ?? false,
            MismatchDetected = isMismatch,
            MismatchDetails = mismatchDetails
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

            if (component == TemplateSchedulerConfigFingerprint.GenerationWorkerComponent)
            {
                throw new TemplateSchedulerConfigMismatchException(
                    $"Template scheduler config fingerprint mismatch is fatal for GenerationWorker. {mismatchDetails}");
            }

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

        await MarkFingerprintStoppedAsync(cancellationToken);
    }

    private void StartHeartbeat(Guid fingerprintId)
    {
        activeFingerprintId = fingerprintId;
        heartbeatCancellationTokenSource = new CancellationTokenSource();
        heartbeatTask = RunHeartbeatAsync(fingerprintId, heartbeatCancellationTokenSource.Token);
    }

    private async Task MarkFingerprintStoppedAsync(CancellationToken cancellationToken)
    {
        if (activeFingerprintId is not { } fingerprintId)
        {
            return;
        }

        activeFingerprintId = null;
        try
        {
            using var scope = scopeFactory.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var fingerprint = await dbContext.TemplateRuntimeConfigFingerprints
                .SingleOrDefaultAsync(x => x.Id == fingerprintId, cancellationToken);
            if (fingerprint is null)
            {
                return;
            }

            fingerprint.ConfiguredLoops = 0;
            fingerprint.NewClaimsPaused = true;
            fingerprint.LastSeenAtUtc = DateTime.UtcNow.Subtract(ActiveFingerprintMaxAge);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template scheduler config fingerprint could not be marked as stopped. FingerprintId={FingerprintId} ExceptionType={ExceptionType}",
                fingerprintId,
                SafeLogValues.ExceptionType(exception));
        }
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
                    using var scope = scopeFactory.CreateScope();
                    var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                    var fingerprint = await dbContext.TemplateRuntimeConfigFingerprints
                        .FirstOrDefaultAsync(x => x.Id == fingerprintId, cancellationToken);
                    if (fingerprint is null)
                    {
                        return;
                    }

                    fingerprint.LastSeenAtUtc = DateTime.UtcNow;
                    var runtimeSnapshot = generationRuntimeSettings?.Current;
                    fingerprint.AppliedSettingsVersion = runtimeSnapshot?.Version ?? 0;
                    fingerprint.ConfiguredLoops = runtimeSnapshot?.WorkerLoopsPerInstance
                        ?? Math.Clamp(options.MaxConcurrentJobsPerWorker, 1, 2);
                    fingerprint.NewClaimsPaused = runtimeSnapshot?.NewClaimsPaused ?? false;
                    await dbContext.SaveChangesAsync(cancellationToken);
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception exception)
                {
                    logger.LogWarning(
                        "Template scheduler config heartbeat failed; the next heartbeat will retry. FingerprintId={FingerprintId} ExceptionType={ExceptionType}",
                        fingerprintId,
                        SafeLogValues.ExceptionType(exception));
                }
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
    }

    private sealed class TemplateSchedulerConfigMismatchException(string message) : InvalidOperationException(message);
}
