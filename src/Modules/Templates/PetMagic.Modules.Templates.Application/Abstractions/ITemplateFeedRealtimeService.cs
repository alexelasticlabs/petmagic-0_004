using System.Threading.Channels;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public static class TemplateFeedRealtimeTopics
{
    public const string TemplatesFeedInvalidated = "templates.feed.invalidated";
}

public sealed record TemplateFeedRealtimeEvent(string Topic, string Data = "{}");

public interface ITemplateFeedRealtimeService
{
    ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default);

    ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default);
}