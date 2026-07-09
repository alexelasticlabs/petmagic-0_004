using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;

using PetMagic.BuildingBlocks.Notifications;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.SupportChat.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Data;

namespace PetMagic.Host.Api.Observability;

internal sealed class PushOutboxHealthCheck(IServiceScopeFactory scopeFactory) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        await using var scope = scopeFactory.CreateAsyncScope();
        var now = DateTime.UtcNow;
        var overdueCutoff = now.AddMinutes(-5);
        var results = new[]
        {
            await InspectAsync("economy", scope.ServiceProvider.GetRequiredService<EconomyDbContext>(), now, overdueCutoff, cancellationToken),
            await InspectAsync("templates", scope.ServiceProvider.GetRequiredService<TemplatesDbContext>(), now, overdueCutoff, cancellationToken),
            await InspectAsync("support", scope.ServiceProvider.GetRequiredService<SupportChatDbContext>(), now, overdueCutoff, cancellationToken)
        };

        var data = results.ToDictionary(
            result => result.Module,
            result => (object)new
            {
                result.Queued,
                result.Processing,
                result.DeadLetter,
                result.Overdue
            });
        var degraded = results.Any(result => result.DeadLetter > 0 || result.Overdue > 0);
        return degraded
            ? HealthCheckResult.Degraded("Push notification outbox contains overdue or dead-letter jobs.", data: data)
            : HealthCheckResult.Healthy("Push notification outboxes are current.", data);
    }

    private static async Task<ModuleResult> InspectAsync<TContext>(
        string module,
        TContext dbContext,
        DateTime now,
        DateTime overdueCutoff,
        CancellationToken cancellationToken)
        where TContext : DbContext
    {
        var messages = dbContext.Set<PushOutboxMessage>();
        var queued = await messages.LongCountAsync(x => x.Status == PushOutboxStatus.Queued, cancellationToken);
        var processing = await messages.LongCountAsync(x => x.Status == PushOutboxStatus.Processing, cancellationToken);
        var deadLetter = await messages.LongCountAsync(x => x.Status == PushOutboxStatus.DeadLetter, cancellationToken);
        var overdue = await messages.LongCountAsync(
            x => (x.Status == PushOutboxStatus.Processing
                    && (x.LockExpiresAtUtc == null || x.LockExpiresAtUtc <= now))
                || (x.Status == PushOutboxStatus.Queued
                    && x.NextAttemptAtUtc <= overdueCutoff),
            cancellationToken);
        PushOutboxMetrics.RecordQueueDepth(module, queued + processing);
        return new ModuleResult(module, queued, processing, deadLetter, overdue);
    }

    private sealed record ModuleResult(string Module, long Queued, long Processing, long DeadLetter, long Overdue);
}
