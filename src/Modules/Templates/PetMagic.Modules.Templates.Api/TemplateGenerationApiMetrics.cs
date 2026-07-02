using System.Diagnostics.Metrics;

namespace PetMagic.Modules.Templates.Api;

internal static class TemplateGenerationApiMetrics
{
    public const string MeterName = "PetMagic.Modules.Templates";

    private static readonly Meter Meter = new(MeterName);

    private static readonly Counter<long> WebhookSignatureFailuresTotal = Meter.CreateCounter<long>(
        "generation_webhook_signature_failures_total",
        unit: "{failure}",
        description: "Number of fal provider webhook signature verification failures.");

    private static readonly Counter<long> WebhookDeliveryFailuresTotal = Meter.CreateCounter<long>(
        "generation_webhook_delivery_failures_total",
        unit: "{failure}",
        description: "Number of provider webhook delivery or payload processing failures observed by the API.");

    public static void RecordWebhookSignatureFailure(string reason)
    {
        WebhookSignatureFailuresTotal.Add(
            1,
            new KeyValuePair<string, object?>("reason", string.IsNullOrWhiteSpace(reason) ? "unknown" : reason));
    }

    public static void RecordWebhookDeliveryFailure(string reason)
    {
        WebhookDeliveryFailuresTotal.Add(
            1,
            new KeyValuePair<string, object?>("reason", string.IsNullOrWhiteSpace(reason) ? "unknown" : reason));
    }
}
