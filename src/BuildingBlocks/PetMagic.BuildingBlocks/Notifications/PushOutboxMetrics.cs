using System.Diagnostics.Metrics;

namespace PetMagic.BuildingBlocks.Notifications;

public static class PushOutboxMetrics
{
    public const string MeterName = "PetMagic.Notifications";

    private static readonly Meter Meter = new(MeterName);
    private static readonly Counter<long> DeliveryAttempts = Meter.CreateCounter<long>("push_outbox_delivery_attempts_count");
    private static readonly Counter<long> Retries = Meter.CreateCounter<long>("push_outbox_retries_count");
    private static readonly Counter<long> DeadLetters = Meter.CreateCounter<long>("push_outbox_dead_letters_count");
    private static readonly Counter<long> Sent = Meter.CreateCounter<long>("push_outbox_sent_count");
    private static readonly Histogram<long> QueueDepth = Meter.CreateHistogram<long>("push_outbox_queue_depth");

    public static void RecordAttempt(string module) => DeliveryAttempts.Add(1, new KeyValuePair<string, object?>("module", module));

    public static void RecordResult(string module, PushOutboxMessage message)
    {
        var tag = new KeyValuePair<string, object?>("module", module);
        if (message.Status == PushOutboxStatus.Queued)
        {
            Retries.Add(1, tag);
        }
        else if (message.Status == PushOutboxStatus.DeadLetter)
        {
            DeadLetters.Add(1, tag);
        }
        else if (message.Status == PushOutboxStatus.Sent)
        {
            Sent.Add(1, tag);
        }
    }

    public static void RecordQueueDepth(string module, long value) =>
        QueueDepth.Record(value, new KeyValuePair<string, object?>("module", module));
}
