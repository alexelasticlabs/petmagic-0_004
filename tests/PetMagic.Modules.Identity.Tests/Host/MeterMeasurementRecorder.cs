using System.Collections.Concurrent;
using System.Diagnostics.Metrics;

namespace PetMagic.Modules.Identity.Tests.Host;

internal sealed class MeterMeasurementRecorder : IDisposable
{
    private readonly MeterListener listener = new();
    private readonly string meterName;
    private readonly HashSet<string> instrumentNames;

    public MeterMeasurementRecorder(string meterName, params string[] instrumentNames)
    {
        this.meterName = meterName;
        this.instrumentNames = instrumentNames.Length == 0
            ? []
            : new HashSet<string>(instrumentNames, StringComparer.Ordinal);

        listener.InstrumentPublished = (instrument, meterListener) =>
        {
            if (string.Equals(instrument.Meter.Name, this.meterName, StringComparison.Ordinal)
                && (this.instrumentNames.Count == 0 || this.instrumentNames.Contains(instrument.Name)))
            {
                meterListener.EnableMeasurementEvents(instrument);
            }
        };
        listener.SetMeasurementEventCallback<long>((instrument, measurement, tags, _) =>
            Record(instrument.Name, measurement, tags));
        listener.SetMeasurementEventCallback<double>((instrument, measurement, tags, _) =>
            Record(instrument.Name, measurement, tags));
        listener.Start();
    }

    public ConcurrentQueue<RecordedMeasurement> Measurements { get; } = [];

    public void Dispose()
    {
        listener.Dispose();
    }

    private void Record(string instrumentName, double value, ReadOnlySpan<KeyValuePair<string, object?>> tags)
    {
        var copiedTags = new Dictionary<string, object?>(StringComparer.Ordinal);
        foreach (var tag in tags)
        {
            copiedTags[tag.Key] = tag.Value;
        }

        Measurements.Enqueue(new RecordedMeasurement(instrumentName, value, copiedTags));
    }
}

internal sealed record RecordedMeasurement(
    string InstrumentName,
    double Value,
    IReadOnlyDictionary<string, object?> Tags);
