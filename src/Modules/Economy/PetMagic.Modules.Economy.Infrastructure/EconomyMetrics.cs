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

    private static readonly Counter<long> WebhookDuplicatesTotal = Meter.CreateCounter<long>(
        "stripe_webhook_duplicate_total",
        unit: "{event}",
        description: "Number of duplicate payment webhook deliveries ignored by idempotency protection (all providers, see provider tag).");

    private static readonly Counter<long> WalletBalanceNegativePreventedTotal = Meter.CreateCounter<long>(
        "wallet_balance_negative_total",
        unit: "{attempt}",
        description: "Number of wallet mutations rejected by the non-negative balance CHECK constraint (should stay at zero; any increase signals a concurrency bug upstream).");

    private static readonly Counter<long> SandboxReceiptInProductionTotal = Meter.CreateCounter<long>(
        "store_receipt_sandbox_in_prod_total",
        unit: "{receipt}",
        description: "Number of sandbox store receipts rejected while running in production (fraud signal, alert on any increase).");

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

    public static void RecordDuplicateWebhook(string provider, string? eventType = null)
    {
        WebhookDuplicatesTotal.Add(
            1,
            new KeyValuePair<string, object?>("provider", provider),
            new KeyValuePair<string, object?>("event_type", string.IsNullOrWhiteSpace(eventType) ? "unknown" : eventType));
    }

    public static void RecordWalletBalanceNegativePrevented(string operation, string? source = null)
    {
        WalletBalanceNegativePreventedTotal.Add(
            1,
            new KeyValuePair<string, object?>("operation", operation),
            new KeyValuePair<string, object?>("source", string.IsNullOrWhiteSpace(source) ? "unknown" : source));
    }

    public static void RecordSandboxReceiptInProduction(string provider, string operation)
    {
        SandboxReceiptInProductionTotal.Add(
            1,
            new KeyValuePair<string, object?>("provider", provider),
            new KeyValuePair<string, object?>("operation", operation));
    }
}
