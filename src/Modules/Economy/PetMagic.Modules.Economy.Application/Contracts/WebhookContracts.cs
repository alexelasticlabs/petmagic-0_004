namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record StripeWebhookResultResponse(string EventId, bool Processed, string Status);

public sealed record StoreWebhookResultResponse(string Provider, string EventId, bool Processed, string Status);
