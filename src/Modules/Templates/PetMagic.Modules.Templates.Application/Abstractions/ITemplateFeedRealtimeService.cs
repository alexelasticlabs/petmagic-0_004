using System.Threading.Channels;

using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Application.Abstractions;

public static class TemplateFeedRealtimeTopics
{
    public const string TemplatesFeedInvalidated = "templates.feed.invalidated";
    public const string GenerationStatusChanged = "templates.generation.status_changed";
}

public sealed record TemplateFeedRealtimeEvent(string Topic, string Data = "{}");

public static class TemplateFeedInvalidationScopes
{
    public const string Full = "full";
    public const string Template = "template";
    public const string Category = "category";
    public const string TemplateOfTheDay = "templateOfTheDay";
}

public sealed record TemplateFeedInvalidationPayload(
    string Scope,
    Guid? TemplateId = null,
    string? Category = null,
    long? MediaVersion = null,
    string? TemplateType = null,
    bool? IsPubliclyVisible = null,
    bool IsCritical = false,
    string? Reason = null,
    string? Locale = null);

public interface ITemplateFeedRealtimeService
{
    ChannelReader<TemplateFeedRealtimeEvent> Subscribe(CancellationToken cancellationToken = default);

    ValueTask PublishTemplatesFeedInvalidatedAsync(CancellationToken cancellationToken = default);

    ValueTask PublishTemplatesFeedInvalidatedAsync(
        TemplateFeedInvalidationPayload payload,
        CancellationToken cancellationToken = default);

    ValueTask PublishGenerationStatusChangedAsync(TemplateGenerationResponse generation, CancellationToken cancellationToken = default);
}
