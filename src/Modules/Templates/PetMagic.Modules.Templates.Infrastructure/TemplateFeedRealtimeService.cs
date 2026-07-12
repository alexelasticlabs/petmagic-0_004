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
    ILogger<TemplateFeedRealtimeService> logger) : ITemplateFeedRealtimeService, IAsyncDisposable
{
    private const string NpgsqlProviderName = "Npgsql.EntityFrameworkCore.PostgreSQL";
    private static readonly JsonSerializerOptions RealtimeJsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan TemplatesInvalidationThrottleWindow = TimeSpan.FromSeconds(2);

    private readonly ConcurrentDictionary<Guid, RealtimeSubscriber> subscribers = new();
    private readonly ConcurrentDictionary<Guid, byte> recentlyBroadcastEventIds = new();
    private readonly ConcurrentQueue<Guid> recentlyBroadcastEventOrder = new();
    private readonly object pumpLock = new();
    private readonly object cursorLock = new();
    private CancellationTokenSource? pumpCancellation;
    private Task? pumpTask;
    private DateTime pumpCursorCreatedAtUtc;
    private Guid pumpCursorId;
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
            FullMode = BoundedChannelFullMode.DropOldest
        });
        var subscriber = new RealtimeSubscriber(channel);

        subscribers[subscriptionId] = subscriber;
        cancellationToken.Register(() => RemoveSubscriber(subscriptionId));
        EnsureEventPumpStarted();
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
        if (persistedEvent is not null)
        {
            BroadcastPersistedEvent(persistedEvent);
            return;
        }

        foreach (var entry in subscribers)
        {
            TryWriteSubscriberEvent(entry.Value.Channel, realtimeEvent);
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

    private void EnsureEventPumpStarted()
    {
        lock (pumpLock)
        {
            if (pumpTask is not null)
            {
                return;
            }

            pumpCursorCreatedAtUtc = DateTime.UtcNow;
            pumpCursorId = Guid.Empty;
            var cancellation = new CancellationTokenSource();
            pumpCancellation = cancellation;
            pumpTask = Task.Run(() => PumpPersistedEventsAsync(cancellation.Token), CancellationToken.None);
        }
    }

    private async Task PumpPersistedEventsAsync(CancellationToken cancellationToken)
    {
        var delay = TimeSpan.FromMilliseconds(Math.Max(250, options.RealtimePollingIntervalMilliseconds));

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                using var scope = serviceScopeFactory.CreateScope();
                var dbContext = scope.ServiceProvider.GetRequiredService<TemplatesDbContext>();
                var cursor = ReadPumpCursor();
                var events = await LoadPersistedEventsAfterCursorAsync(
                    dbContext,
                    cursor.CreatedAtUtc,
                    cursor.Id,
                    cancellationToken);

                foreach (var realtimeEvent in events)
                {
                    BroadcastPersistedEvent(realtimeEvent);
                    AdvancePumpCursor(realtimeEvent.CreatedAtUtc, realtimeEvent.Id);
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

    private (DateTime CreatedAtUtc, Guid Id) ReadPumpCursor()
    {
        lock (cursorLock)
        {
            return (pumpCursorCreatedAtUtc, pumpCursorId);
        }
    }

    private void AdvancePumpCursor(DateTime createdAtUtc, Guid id)
    {
        lock (cursorLock)
        {
            if (createdAtUtc < pumpCursorCreatedAtUtc
                || (createdAtUtc == pumpCursorCreatedAtUtc && id.CompareTo(pumpCursorId) <= 0))
            {
                return;
            }

            pumpCursorCreatedAtUtc = createdAtUtc;
            pumpCursorId = id;
        }
    }

    private void BroadcastPersistedEvent(TemplateRealtimeEventRecord persistedEvent)
    {
        if (!recentlyBroadcastEventIds.TryAdd(persistedEvent.Id, 0))
        {
            return;
        }

        recentlyBroadcastEventOrder.Enqueue(persistedEvent.Id);
        while (recentlyBroadcastEventOrder.Count > 1_000
               && recentlyBroadcastEventOrder.TryDequeue(out var expiredEventId))
        {
            recentlyBroadcastEventIds.TryRemove(expiredEventId, out _);
        }

        var realtimeEvent = new TemplateFeedRealtimeEvent(
            persistedEvent.Topic,
            string.IsNullOrWhiteSpace(persistedEvent.Data) ? "{}" : persistedEvent.Data);
        foreach (var subscriber in subscribers.Values)
        {
            TryWriteSubscriberEvent(subscriber.Channel, realtimeEvent);
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

    public async ValueTask DisposeAsync()
    {
        CancellationTokenSource? cancellation;
        Task? task;
        lock (pumpLock)
        {
            cancellation = pumpCancellation;
            task = pumpTask;
            pumpCancellation = null;
            pumpTask = null;
        }

        if (cancellation is null)
        {
            return;
        }

        await cancellation.CancelAsync();
        if (task is not null)
        {
            await task.ConfigureAwait(false);
        }

        cancellation.Dispose();
    }

    private sealed record RealtimeSubscriber(Channel<TemplateFeedRealtimeEvent> Channel);

    private sealed record TemplateGenerationRealtimeStatusPayload(
        string EventType,
        Guid UserId,
        Guid GenerationId,
        string Status,
        DateTime UpdatedAtUtc,
        bool RequiresRefetch);
}
