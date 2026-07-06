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
    ILogger<TemplateSchedulerConfigStartupService> logger) : IHostedService
{
    private static readonly TimeSpan ActiveFingerprintMaxAge = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan HeartbeatInterval = TimeSpan.FromSeconds(30);

    private CancellationTokenSource? heartbeatCancellationTokenSource;
    private Task? heartbeatTask;

    public async Task StartAsync(CancellationToken cancellationToken)
    {
        var component = componentConfig.Value;
        var profileName = string.IsNullOrWhiteSpace(environment.EnvironmentName)
            ? Environments.Production
            : environment.EnvironmentName.Trim();
        var fingerprint = TemplateSchedulerConfigFingerprint.Create(options, profileName, component);
        var now = DateTime.UtcNow;

        logger.LogInformation(
            "Template scheduler config startup fingerprint. Component={Component} ProfileName={ProfileName} Checksum={Checksum} Config={ConfigJson}",
            component,
            profileName,
            fingerprint.Checksum,
            fingerprint.SanitizedDumpJson);

        try
        {
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
                    throw new InvalidOperationException(
                        $"Template scheduler config fingerprint mismatch is fatal for GenerationWorker. {mismatchDetails}");
                }

                return;
            }

            runtimeState.MarkHealthy(component, profileName, fingerprint.Checksum);
            StartHeartbeat(currentFingerprintId);
        }
        catch (Exception exception) when (environment.IsDevelopment() && exception is not InvalidOperationException)
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
                using var scope = scopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                var fingerprint = await dbContext.TemplateRuntimeConfigFingerprints
                    .FirstOrDefaultAsync(x => x.Id == fingerprintId, cancellationToken);
                if (fingerprint is null)
                {
                    return;
                }

                fingerprint.LastSeenAtUtc = DateTime.UtcNow;
                await dbContext.SaveChangesAsync(cancellationToken);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            logger.LogWarning(
                "Template scheduler config heartbeat failed. FingerprintId={FingerprintId} ExceptionType={ExceptionType}",
                fingerprintId,
                SafeLogValues.ExceptionType(exception));
        }
    }
}
