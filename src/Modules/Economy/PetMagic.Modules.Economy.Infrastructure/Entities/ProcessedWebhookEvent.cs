namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class ProcessedWebhookEvent
{
    public Guid Id { get; set; }

    public string Provider { get; set; } = "stripe";

    public string EventId { get; set; } = string.Empty;

    public string EventType { get; set; } = string.Empty;

    public DateTime ProcessedAtUtc { get; set; }
}
