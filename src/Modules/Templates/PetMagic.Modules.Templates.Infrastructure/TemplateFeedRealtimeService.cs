using System.Collections.Concurrent;
using System.Text.Json;
using System.Threading.Channels;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateFeedRealtimeService : ITemplateFeedRealtimeService
{
    private static readonly JsonSerializerOptions RealtimeJsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly TimeSpan TemplatesInvalidationThrottleWindow = TimeSpan.FromSeconds(2);

    private readonly ConcurrentDictionary<Guid, Channel<TemplateFeedRealtimeEvent>> subscribers = new();
    private long _lastTemplatesInvalidationTicks;

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
        foreach (var entry in subscribers)
        {
            cancellationToken.ThrowIfCancellationRequested();

            if (!entry.Value.Writer.TryWrite(realtimeEvent))
            {
                RemoveSubscriber(entry.Key);
            }
        }

        return ValueTask.CompletedTask;
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
