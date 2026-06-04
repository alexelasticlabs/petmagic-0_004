using System.Diagnostics.Metrics;

namespace PetMagic.Modules.Economy.Infrastructure;

internal static class EconomyMetrics
{
    public const string MeterName = "PetMagic.Modules.Economy";

    private static readonly Meter Meter = new(MeterName);

    private static readonly Counter<long> EmptyCheckoutUrlCounter = Meter.CreateCounter<long>(
        "petmagic.economy.checkout.empty_url.total",
        unit: "{event}",
        description: "Number of wallet top-up checkout creation responses with empty checkout URL.");

    private static readonly Counter<long> StripeWebhookFailuresTotal = Meter.CreateCounter<long>(
        "stripe_webhook_failures_total",
        unit: "{failure}",
        description: "Number of Stripe webhook processing failures.");

    public static void RecordEmptyCheckoutUrl(string provider, string platform, string currency)
    {
        EmptyCheckoutUrlCounter.Add(
            1,
            new KeyValuePair<string, object?>("provider", provider),
            new KeyValuePair<string, object?>("platform", platform),
            new KeyValuePair<string, object?>("currency", currency));
    }

    public static void RecordStripeWebhookFailure(string errorCode, string stage, string? eventType = null)
    {
        StripeWebhookFailuresTotal.Add(
            1,
            new KeyValuePair<string, object?>("error_code", errorCode),
            new KeyValuePair<string, object?>("stage", stage),
            new KeyValuePair<string, object?>("event_type", string.IsNullOrWhiteSpace(eventType) ? "unknown" : eventType));
    }
}
