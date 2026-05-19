using System.Collections.Concurrent;
using System.Threading.Channels;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateFeedRealtimeService : ITemplateFeedRealtimeService
{
    private readonly ConcurrentDictionary<Guid, Channel<TemplateFeedRealtimeEvent>> subscribers = new();

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
        var realtimeEvent = new TemplateFeedRealtimeEvent(TemplateFeedRealtimeTopics.TemplatesFeedInvalidated);

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