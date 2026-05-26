using System.Threading.Channels;

using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public static class TemplateFeedRealtimeTopics
{
    public const string TemplatesFeedInvalidated = "templates.feed.invalidated";
    public const string GenerationStatusChanged = "templates.generation.status_changed";
}

public sealed record TemplateFeedRealtimeEvent(string Topic, string Data = "{}");

public interface ITemplateFeedRealtimeService
{
    ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default);

    ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default);

    ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default);
}
