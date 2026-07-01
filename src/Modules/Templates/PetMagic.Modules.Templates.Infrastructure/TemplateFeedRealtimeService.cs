using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateFeedRealtimeService(
    IServiceScopeFactory serviceScopeFactory,
    TemplatesOptions options,
    ILogger<TemplateFeedRealtimeService> logger) : ITemplateFeedRealtimeService
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private static readonly JsonSerializerOptions RealtimeJsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan TemplatesInvalidationThrottleWindow = TimeSpan.FromSeconds(2);

    private readonly ConcurrentDictionary<Guid, Channel<TemplateFeedRealtimeEvent>> subscribers = new();
    private long _lastTemplatesInvalidationTicks;
    private long _lastRealtimeEventCleanupTicks;

    public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
    {
        var subscriptionId = Guid.NewGuid();
        var channel = Channel.CreateUnbounded<TemplateFeedRealtimeEvent>(new UnboundedChannelOptions
        {
            SingleReader = true,
            SingleWriter = false
        });

        subscribers[subscriptionId] = channel;
        cancellationToken.Register(() => RemoveSubscriber(subscriptionId));
        _ = Task.Run(() => PollPersistedEventsAsync(subscriptionId, channel, DateTime.UtcNow, cancellationToken), CancellationToken.None);
        return channel.Reader;
    }

    public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
    {
        var nowTicks = DateTime.UtcNow.Ticks;

        while (true)
        {
            var previousTicks = Interlocked.Read(ref _lastTemplatesInvalidationTicks);
            if (nowTicks - previousTicks < TemplatesInvalidationThrottleWindow.Ticks)
            {
                return ValueTask.CompletedTask;
            }

            if (Interlocked.CompareExchange(ref _lastTemplatesInvalidationTicks, nowTicks, previousTicks) == previousTicks)
            {
                break;
            }
        }

        return PublishAsync(new TemplateFeedRealtimeEvent(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated), cancellationToken);
    }

    public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
    {
        var data = JsonSerializer.Serialize(generation, RealtimeJsonOptions);
        return PublishAsync(new TemplateFeedRealtimeEvent(TemplateFeedRealtimeTopics.GenerationStatusChanged, data), cancellationToken);
    }

    private ValueTask PublishAsync(TemplateFeedRealtimeEvent realtimeEvent, CancellationToken cancellationToken)
    {
        _ = PersistAsync(realtimeEvent, CancellationToken.None);
        foreach (var entry in subscribers)
        {
            if (!entry.Value.Writer.TryWrite(realtimeEvent))
            {
                RemoveSubscriber(entry.Key);
            }
        }

        return ValueTask.CompletedTask;
    }

    private async Task PersistAsync(TemplateFeedRealtimeEvent realtimeEvent, CancellationToken cancellationToken)
    {
        try
        {
            using var scope = serviceScopeFactory.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            dbContext.TemplateRealtimeEvents.Add(new TemplateRealtimeEventRecord
            {
                Id = Guid.NewGuid(),
                Topic = realtimeEvent.Topic,
                Data = realtimeEvent.Data,
                CreatedAtUtc = DateTime.UtcNow
            });
            await dbContext.SaveChangesAsync(cancellationToken);
            await PrunePersistedEventsIfDueAsync(dbContext, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            TemplateGenerationMetrics.RecordSseDeliveryFailure(realtimeEvent.Topic);
            logger.LogWarning(
                exception,
                "Template realtime event persistence failed. Topic={Topic}",
                realtimeEvent.Topic);
        }
    }

    private async Task PrunePersistedEventsIfDueAsync(TemplatesDbContext dbContext, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var cleanupIntervalTicks = TimeSpan.FromMinutes(Math.Max(1, options.RealtimeEventCleanupIntervalMinutes)).Ticks;
        var previousCleanupTicks = Interlocked.Read(ref _lastRealtimeEventCleanupTicks);
        if (now.Ticks - previousCleanupTicks < cleanupIntervalTicks)
        {
            return;
        }

        if (Interlocked.CompareExchange(ref _lastRealtimeEventCleanupTicks, now.Ticks, previousCleanupTicks) != previousCleanupTicks)
        {
            return;
        }

        try
        {
            var cutoff = now.AddMinutes(-Math.Max(1, options.RealtimeEventRetentionMinutes));
            var expiredEvents = await dbContext.TemplateRealtimeEvents
                .Where(x => x.CreatedAtUtc < cutoff)
                .OrderBy(x => x.CreatedAtUtc)
                .ThenBy(x => x.Id)
                .Take(Math.Max(1, options.RealtimeEventCleanupBatchSize))
                .ToArrayAsync(cancellationToken);

            if (expiredEvents.Length == 0)
            {
                return;
            }

            dbContext.TemplateRealtimeEvents.RemoveRange(expiredEvents);
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            TemplateGenerationMetrics.RecordSseDeliveryFailure("cleanup");
            logger.LogWarning(exception, "Template realtime event cleanup failed.");
        }
    }

    private async Task PollPersistedEventsAsync(
        Guid subscriptionId,
        Channel<TemplateFeedRealtimeEvent> channel,
        DateTime startedAtUtc,
        CancellationToken cancellationToken)
    {
        var lastSeenCreatedAtUtc = startedAtUtc;
        var lastSeenId = Guid.Empty;
        var delay = TimeSpan.FromMilliseconds(Math.Max(250, options.RealtimePollingIntervalMilliseconds));

        while (!cancellationToken.IsCancellationRequested && subscribers.ContainsKey(subscriptionId))
        {
            try
            {
                using var scope = serviceScopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                var events = await LoadPersistedEventsAfterCursorAsync(
                    dbContext,
                    lastSeenCreatedAtUtc,
                    lastSeenId,
                    cancellationToken);

                foreach (var realtimeEvent in events)
                {
                    lastSeenCreatedAtUtc = realtimeEvent.CreatedAtUtc;
                    lastSeenId = realtimeEvent.Id;
                    if (!channel.Writer.TryWrite(new TemplateFeedRealtimeEvent(
                            realtimeEvent.Topic,
                            string.IsNullOrWhiteSpace(realtimeEvent.Data) ? "{}" : realtimeEvent.Data)))
                    {
                        RemoveSubscriber(subscriptionId);
                        return;
                    }
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                TemplateGenerationMetrics.RecordSseDeliveryFailure("polling");
                logger.LogWarning(exception, "Template realtime event polling failed.");
            }

            try
            {
                await Task.Delay(delay, cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
        }
    }

    private static Task<TemplateRealtimeEventRecord[]> LoadPersistedEventsAfterCursorAsync(
        TemplatesDbContext dbContext,
        DateTime lastSeenCreatedAtUtc,
        Guid lastSeenId,
        CancellationToken cancellationToken)
    {
        if (string.Equals(dbContext.Database.ProviderName, NpgsqlProviderName, StringComparison.Ordinal))
        {
            return dbContext.TemplateRealtimeEvents
                .FromSqlInterpolated(
                    $"""
                    SELECT "Id", "Topic", "Data", "CreatedAtUtc"
                    FROM templates_realtime_events
                    WHERE "CreatedAtUtc" > {lastSeenCreatedAtUtc}
                        OR ("CreatedAtUtc" = {lastSeenCreatedAtUtc} AND "Id" > {lastSeenId})
                    ORDER BY "CreatedAtUtc", "Id"
                    LIMIT 100
                    """)
                .AsNoTracking()
                .ToArrayAsync(cancellationToken);
        }

        return dbContext.TemplateRealtimeEvents
            .AsNoTracking()
            .Where(x => x.CreatedAtUtc > lastSeenCreatedAtUtc
                || (x.CreatedAtUtc == lastSeenCreatedAtUtc && x.Id.CompareTo(lastSeenId) > 0))
            .OrderBy(x => x.CreatedAtUtc)
            .ThenBy(x => x.Id)
            .Take(100)
            .ToArrayAsync(cancellationToken);
    }

    private void RemoveSubscriber(Guid subscriptionId)
    {
        if (!subscribers.TryRemove(subscriptionId, out var channel))
        {
            return;
        }

        channel.Writer.TryComplete();
    }
}
