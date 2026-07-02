using System.Collections.Generic;
using System.Diagnostics.Metrics;
using System.Threading;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateCategoryMetrics
{
    public const string MeterName = "PetMagic.Modules.Templates";

    private static readonly Meter Meter = new(MeterName);

    private static readonly Counter<long> CategoryFilterLookupsTotal = Meter.CreateCounter<long>(
        "category_filter_lookups_total",
        unit: "{lookup}",
        description: "Number of public category filter lookups by match mode.");

    private static readonly Counter<long> CategoryFallbackRequestsTotal = Meter.CreateCounter<long>(
        "category_fallback_requests_total",
        unit: "{request}",
        description: "Number of public feed/catalog/random requests that used legacy category string fallback.");

    private static long categoryFilterLookups;
    private static long categoryFallbackLookups;
    private static long noncanonicalCategoryTemplatesCount;

    private static readonly ObservableGauge<double> CategoryFallbackHitRate = Meter.CreateObservableGauge(
        "category_fallback_hit_rate",
        () =>
        {
            var total = Volatile.Read(ref categoryFilterLookups);
            return total <= 0 ? 0d : Volatile.Read(ref categoryFallbackLookups) / (double)total;
        },
        unit: "1",
        description: "Share of public category filter lookups that used legacy string fallback.");

    private static readonly ObservableGauge<long> NoncanonicalCategoryTemplatesCount = Meter.CreateObservableGauge(
        "noncanonical_category_templates_count",
        () => Volatile.Read(ref noncanonicalCategoryTemplatesCount),
        unit: "{template}",
        description: "Last observed count of active templates whose category does not match an active canonical category.");

    public static void RecordCategoryFilterLookup(bool usedFallback)
    {
        Interlocked.Increment(ref categoryFilterLookups);
        if (usedFallback)
        {
            Interlocked.Increment(ref categoryFallbackLookups);
            CategoryFallbackRequestsTotal.Add(1);
        }

        CategoryFilterLookupsTotal.Add(
            1,
            new KeyValuePair<string, object?>("mode", usedFallback ? "fallback" : "canonical"));
    }

    public static void RecordNoncanonicalCategoryTemplatesCount(long count)
    {
        Volatile.Write(ref noncanonicalCategoryTemplatesCount, count);
    }
}
