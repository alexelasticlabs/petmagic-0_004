using System.Diagnostics;
using System.Text.RegularExpressions;

using Microsoft.Extensions.Primitives;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Host.Api.Observability;

public static partial class CorrelationId
{
    public const string HeaderName = CorrelationContext.HeaderName;
    public const string HttpContextItemKey = "__PetMagicCorrelationId";
    public const int MaxLength = CorrelationContext.MaxLength;

    public static string Create() => Activity.Current?.TraceId.ToString() ?? Guid.NewGuid().ToString("N");

    public static string NormalizeOrCreate(StringValues values)
    {
        var candidate = values.FirstOrDefault();
        if (string.IsNullOrWhiteSpace(candidate))
        {
            return Create();
        }

        candidate = candidate.Trim();
        return IsValid(candidate) ? candidate : Create();
    }

    public static bool IsValid(string value)
    {
        return value.Length is > 0 and <= MaxLength
            && CorrelationIdRegex().IsMatch(value);
    }

    [GeneratedRegex("^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$", RegexOptions.CultureInvariant)]
    private static partial Regex CorrelationIdRegex();
}
