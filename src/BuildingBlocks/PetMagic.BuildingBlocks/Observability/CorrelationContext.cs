using System.Diagnostics;
using System.Text.RegularExpressions;

namespace PetMagic.BuildingBlocks.Observability;

public static partial class CorrelationContext
{
    private static readonly AsyncLocal<string?> CurrentCorrelationId = new();

    public const string HeaderName = "X-Correlation-ID";
    public const int MaxLength = 128;

    public static string? CurrentId => CurrentCorrelationId.Value;

    public static IDisposable Push(string? correlationId)
    {
        var previous = CurrentCorrelationId.Value;
        CurrentCorrelationId.Value = !string.IsNullOrWhiteSpace(correlationId) && IsValid(correlationId)
            ? correlationId
            : null;

        return new RestoreScope(previous);
    }

    public static string ResolveOrCreate()
    {
        if (!string.IsNullOrWhiteSpace(CurrentCorrelationId.Value) && IsValid(CurrentCorrelationId.Value))
        {
            return CurrentCorrelationId.Value;
        }

        var traceId = Activity.Current?.TraceId.ToString();
        return !string.IsNullOrWhiteSpace(traceId)
            && !string.Equals(traceId, "00000000000000000000000000000000", StringComparison.Ordinal)
            ? traceId
            : Guid.NewGuid().ToString("N");
    }

    public static bool IsValid(string value)
    {
        return value.Length is > 0 and <= MaxLength
            && CorrelationIdRegex().IsMatch(value);
    }

    [GeneratedRegex("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$", RegexOptions.CultureInvariant)]
    private static partial Regex CorrelationIdRegex();

    private sealed class RestoreScope(string? previous) : IDisposable
    {
        public void Dispose()
        {
            CurrentCorrelationId.Value = previous;
        }
    }
}
