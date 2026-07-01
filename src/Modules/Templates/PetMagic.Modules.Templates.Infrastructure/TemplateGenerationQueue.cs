using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationQueue
{
    public const string MediaTypeImage = "image";
    public const string MediaTypeVideo = "video";
    public const string TierFree = "free";
    public const string TierPremium = "premium";
    public const string TierPrivileged = "privileged";
    public const string TierAdmin = "admin";

    public static string ResolveMediaType(TemplateType templateType)
    {
        return templateType == TemplateType.Video ? MediaTypeVideo : MediaTypeImage;
    }

    public static string ResolveMediaType(TemplateGenerationJob job)
    {
        if (string.Equals(job.QueueMediaType, MediaTypeVideo, StringComparison.OrdinalIgnoreCase))
        {
            return MediaTypeVideo;
        }

        return job.Template?.TemplateType == TemplateType.Video ? MediaTypeVideo : MediaTypeImage;
    }

    public static string NormalizeTier(string? tier)
    {
        return tier?.Trim().ToLowerInvariant() switch
        {
            TierAdmin => TierAdmin,
            TierPrivileged => TierPrivileged,
            TierPremium => TierPremium,
            _ => TierFree
        };
    }

    public static int ResolveTierBaseScore(string tier, TemplatesOptions options)
    {
        return NormalizeTier(tier) switch
        {
            TierAdmin => options.AdminQueuePriorityScore,
            TierPrivileged => options.PrivilegedQueuePriorityScore,
            TierPremium => options.PremiumQueuePriorityScore,
            _ => options.FreeQueuePriorityScore
        };
    }

    public static int ResolvePriorityScore(TemplateGenerationJob job, DateTime now, TemplatesOptions options)
    {
        var waitedSeconds = Math.Max(0, (now - job.QueuedAtUtc).TotalSeconds);
        var agingSteps = (int)Math.Floor(waitedSeconds / Math.Max(1, options.QueuePriorityAgingIntervalSeconds));
        return ResolveTierBaseScore(job.QueueTier, options)
            + agingSteps * Math.Max(0, options.QueuePriorityAgingBoost);
    }

    public static string ResolveLane(string mediaType, string tier)
    {
        return $"{NormalizeMediaType(mediaType)}:{NormalizeTier(tier)}";
    }

    public static string NormalizeMediaType(string? mediaType)
    {
        return string.Equals(mediaType, MediaTypeVideo, StringComparison.OrdinalIgnoreCase)
            ? MediaTypeVideo
            : MediaTypeImage;
    }
}
