namespace PetMagic.Modules.Templates.Infrastructure;

internal static class FalModelPricing
{
    private static readonly IReadOnlyDictionary<string, decimal> MotionUsdPerSecondByModel =
        new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
        {
            ["fal-ai/kling-video/v3/pro/motion-control"] = 0.168m,
            ["fal-ai/kling-video/v3/standard/motion-control"] = 0.126m
        };

    public static decimal? TryCalculateMotionCostUsd(string? model, double? outputVideoDurationSeconds)
    {
        if (string.IsNullOrWhiteSpace(model)
            || !outputVideoDurationSeconds.HasValue
            || outputVideoDurationSeconds.Value <= 0
            || !MotionUsdPerSecondByModel.TryGetValue(model, out var usdPerSecond))
        {
            return null;
        }

        var duration = Convert.ToDecimal(outputVideoDurationSeconds.Value);
        return decimal.Round(duration * usdPerSecond, 4, MidpointRounding.AwayFromZero);
    }
}
