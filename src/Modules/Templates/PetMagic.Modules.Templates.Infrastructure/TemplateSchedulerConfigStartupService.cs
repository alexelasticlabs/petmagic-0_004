using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

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
                .OrderByDescending(x => x.StartedAtUtc)
                .ThenByDescending(x => x.Id)
                .FirstOrDefaultAsync(cancellationToken);
            var isMismatch = other is not null
                && !string.Equals(other.Checksum, fingerprint.Checksum, StringComparison.Ordinal);
            var mismatchDetails = isMismatch
                ? $"current={component}:{fingerprint.Checksum}; other={other!.Component}:{other.Checksum}; profile={profileName}"
                : null;

            dbContext.TemplateRuntimeConfigFingerprints.Add(new TemplateRuntimeConfigFingerprint
            {
                Id = Guid.NewGuid(),
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
        }
        catch (Exception exception) when (environment.IsDevelopment() && exception is not InvalidOperationException)
        {
            runtimeState.MarkMismatch(
                component,
                profileName,
                fingerprint.Checksum,
                $"startup_fingerprint_persistence_failed:{exception.GetType().Name}");
            logger.LogWarning(
                exception,
                "Template scheduler config startup fingerprint persistence failed in Development.");
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
