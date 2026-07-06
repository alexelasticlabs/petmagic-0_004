using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading.Channels;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

using PetMagic.BuildingBlocks.Observability;
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

    private readonly ConcurrentDictionary<Guid, RealtimeSubscriber> subscribers = new();
    private long _lastTemplatesInvalidationTicks;
    private long _lastRealtimeEventCleanupTicks;

    public ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default)
    {
        var subscriptionId = Guid.NewGuid();
        var channel = Channel.CreateBounded<TemplateFeedRealtimeEvent>(new BoundedChannelOptions(
            Math.Max(1, options.RealtimeSubscriberBufferSize))
        {
            SingleReader = true,
            SingleWriter = false,
            FullMode = BoundedChannelFullMode.Wait
        });
        var subscriber = new RealtimeSubscriber(channel, DateTime.UtcNow);

        subscribers[subscriptionId] = subscriber;
        cancellationToken.Register(() => RemoveSubscriber(subscriptionId));
        _ = Task.Run(() => PollPersistedEventsAsync(subscriptionId, subscriber, cancellationToken), CancellationToken.None);
        return channel.Reader;
    }

    public ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default)
    {
        TemplateGenerationMetrics.RecordSseEventPublished(TemplateFeedInvalidationScopes.Full);
        TemplateGenerationMetrics.RecordSseFullInvalidation();

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

    public ValueTask PublishTemplatesFeedInvalidatedAsync(
        TemplateFeedInvalidationPayload payload,
        CancellationToken cancellationToken = default)
    {
        var scope = string.IsNullOrWhiteSpace(payload.Scope)
            ? TemplateFeedInvalidationScopes.Full
            : payload.Scope.Trim();
        TemplateGenerationMetrics.RecordSseEventPublished(scope);
        if (string.Equals(scope, TemplateFeedInvalidationScopes.Full, StringComparison.OrdinalIgnoreCase))
        {
            TemplateGenerationMetrics.RecordSseFullInvalidation();
        }

        var data = JsonSerializer.Serialize(payload with { Scope = scope }, RealtimeJsonOptions);
        return PublishAsync(new TemplateFeedRealtimeEvent(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated, data), cancellationToken);
    }

    public ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default)
    {
        var payload = new TemplateGenerationRealtimeStatusPayload(
            "generation.status_changed",
            generation.UserId,
            generation.GenerationId,
            generation.Status,
            generation.UpdatedAtUtc,
            RequiresRefetch: true);
        var data = JsonSerializer.Serialize(payload, RealtimeJsonOptions);
        return PublishAsync(new TemplateFeedRealtimeEvent(TemplateFeedRealtimeTopics.GenerationStatusChanged, data), cancellationToken);
    }

    private async ValueTask PublishAsync(TemplateFeedRealtimeEvent realtimeEvent, CancellationToken cancellationToken)
    {
        var persistedEvent = await PersistAsync(realtimeEvent, CancellationToken.None);
        foreach (var entry in subscribers)
        {
            if (TryWriteSubscriberEvent(entry.Value.Channel, realtimeEvent) && persistedEvent is not null)
            {
                entry.Value.AdvanceCursor(persistedEvent.CreatedAtUtc, persistedEvent.Id);
            }
        }
    }

    private async Task<TemplateRealtimeEventRecord?> PersistAsync(TemplateFeedRealtimeEvent realtimeEvent, CancellationToken cancellationToken)
    {
        try
        {
            using var scope = serviceScopeFactory.CreateScope();
            var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
            var persistedEvent = new TemplateRealtimeEventRecord
            {
                Id = Guid.NewGuid(),
                Topic = realtimeEvent.Topic,
                Data = realtimeEvent.Data,
                CreatedAtUtc = DateTime.UtcNow
            };
            dbContext.TemplateRealtimeEvents.Add(persistedEvent);
            await dbContext.SaveChangesAsync(cancellationToken);
            await PrunePersistedEventsIfDueAsync(dbContext, cancellationToken);
            return persistedEvent;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            return null;
        }
        catch (Exception exception)
        {
            TemplateGenerationMetrics.RecordSseDeliveryFailure(realtimeEvent.Topic);
            logger.LogWarning(
                "Template realtime event persistence failed. Topic={Topic} ExceptionType={ExceptionType}",
                realtimeEvent.Topic,
                SafeLogValues.ExceptionType(exception));
            return null;
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
            logger.LogWarning(
                "Template realtime event cleanup failed. ExceptionType={ExceptionType}",
                SafeLogValues.ExceptionType(exception));
        }
    }

    private async Task PollPersistedEventsAsync(
        Guid subscriptionId,
        RealtimeSubscriber subscriber,
        CancellationToken cancellationToken)
    {
        var delay = TimeSpan.FromMilliseconds(Math.Max(250, options.RealtimePollingIntervalMilliseconds));

        while (!cancellationToken.IsCancellationRequested && subscribers.ContainsKey(subscriptionId))
        {
            try
            {
                using var scope = serviceScopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                var cursor = subscriber.ReadCursor();
                var events = await LoadPersistedEventsAfterCursorAsync(
                    dbContext,
                    cursor.CreatedAtUtc,
                    cursor.Id,
                    cancellationToken);

                foreach (var realtimeEvent in events)
                {
                    var eventPayload = new TemplateFeedRealtimeEvent(
                        realtimeEvent.Topic,
                        string.IsNullOrWhiteSpace(realtimeEvent.Data) ? "{}" : realtimeEvent.Data);
                    if (!TryWriteSubscriberEvent(subscriber.Channel, eventPayload))
                    {
                        break;
                    }

                    subscriber.AdvanceCursor(realtimeEvent.CreatedAtUtc, realtimeEvent.Id);
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                return;
            }
            catch (Exception exception)
            {
                TemplateGenerationMetrics.RecordSseDeliveryFailure("polling");
                logger.LogWarning(
                    "Template realtime event polling failed. ExceptionType={ExceptionType}",
                    SafeLogValues.ExceptionType(exception));
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
        if (!subscribers.TryRemove(subscriptionId, out var subscriber))
        {
            return;
        }

        subscriber.Channel.Writer.TryComplete();
    }

    private static bool TryWriteSubscriberEvent(
        Channel<TemplateFeedRealtimeEvent> channel,
        TemplateFeedRealtimeEvent realtimeEvent)
    {
        if (channel.Writer.TryWrite(realtimeEvent))
        {
            return true;
        }

        TemplateGenerationMetrics.RecordSseSubscriberDrop(realtimeEvent.Topic);
        return false;
    }

    private sealed class RealtimeSubscriber(Channel<TemplateFeedRealtimeEvent> channel, DateTime startedAtUtc)
    {
        private readonly object cursorLock = new();
        private DateTime lastSeenCreatedAtUtc = startedAtUtc;
        private Guid lastSeenId = Guid.Empty;

        public Channel<TemplateFeedRealtimeEvent> Channel { get; } = channel;

        public (DateTime CreatedAtUtc, Guid Id) ReadCursor()
        {
            lock (cursorLock)
            {
                return (lastSeenCreatedAtUtc, lastSeenId);
            }
        }

        public void AdvanceCursor(DateTime createdAtUtc, Guid id)
        {
            lock (cursorLock)
            {
                if (createdAtUtc < lastSeenCreatedAtUtc)
                {
                    return;
                }

                if (createdAtUtc == lastSeenCreatedAtUtc && id.CompareTo(lastSeenId) <= 0)
                {
                    return;
                }

                lastSeenCreatedAtUtc = createdAtUtc;
                lastSeenId = id;
            }
        }
    }

    private sealed record TemplateGenerationRealtimeStatusPayload(
        string EventType,
        Guid UserId,
        Guid GenerationId,
        string Status,
        DateTime UpdatedAtUtc,
        bool RequiresRefetch);
}
