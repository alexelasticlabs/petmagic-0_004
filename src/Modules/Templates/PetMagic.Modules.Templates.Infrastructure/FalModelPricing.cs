namespace PetMagic.Modules.Templates.Infrastructure;

internal static class FalModelPricing
{
    private static readonly IReadOnlyDictionary<string, decimal> PreprocessingUsdPerRequestByModel =
        new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
        {
            ["openai/gpt-image-2/edit"] = 0.219m,
            ["fal-ai/nano-banana-pro/edit"] = 0.15m,
            ["fal-ai/flux-2-pro/edit"] = 0.03m,
            ["fal-ai/gpt-image-1.5/edit"] = 0.133m,
            ["fal-ai/bytedance/seedream/v5/lite/edit"] = 0.035m,
            ["fal-ai/nano-banana-2/edit"] = 0.08m,
        };

    private static readonly IReadOnlyDictionary<string, decimal> MotionUsdPerSecondByModel =
        new Dictionary<string, decimal>(StringComparer.OrdinalIgnoreCase)
        {
            ["fal-ai/kling-video/v3/pro/motion-control"] = 0.168m,
            ["fal-ai/kling-video/v3/standard/motion-control"] = 0.126m
        };

    public static decimal? TryGetPreprocessingCostUsd(string? model)
    {
        if (string.IsNullOrWhiteSpace(model)
            || !PreprocessingUsdPerRequestByModel.TryGetValue(model, out var cost))
        {
            return null;
        }

        return cost;
    }

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

    public static decimal? TryCalculateEstimatedGenerationCostUsd(
        string? preprocessingModel,
        string? motionModel,
        double? referenceVideoDurationSeconds)
    {
        var preprocessingCost = TryGetPreprocessingCostUsd(preprocessingModel);
        var motionCost = TryCalculateMotionCostUsd(motionModel, referenceVideoDurationSeconds);
        if (!preprocessingCost.HasValue || !motionCost.HasValue)
        {
            return null;
        }

        return decimal.Round(preprocessingCost.Value + motionCost.Value, 4, MidpointRounding.AwayFromZero);
    }
}
