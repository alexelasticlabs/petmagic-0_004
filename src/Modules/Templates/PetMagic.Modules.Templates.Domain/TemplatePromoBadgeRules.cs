using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Domain;

public static class TemplatePromoBadgeRules
{
    public const int NewBadgeDays = 30;
    public const int TrendingBadgeDays = 14;
    public const int PopularTokenCostThreshold = 60;

    public static readonly string[] FunnyKeywords = ["funny", "meme", "viral", "dance", "lol", "cute"];

    public static string? ResolveAutoBadge(
        DateTime createdAtUtc,
        DateTime updatedAtUtc,
        TemplateStatus status,
        bool isPremium,
        int tokenCost,
        IEnumerable<string?> searchFragments,
        DateTime utcNow)
    {
        if (createdAtUtc >= utcNow.AddDays(-NewBadgeDays))
        {
            return TemplatePromoBadgeMode.New.ToString();
        }

        if (status == TemplateStatus.Active && updatedAtUtc >= utcNow.AddDays(-TrendingBadgeDays))
        {
            return TemplatePromoBadgeMode.Trending.ToString();
        }

        if (status == TemplateStatus.Active && (isPremium || tokenCost >= PopularTokenCostThreshold))
        {
            return TemplatePromoBadgeMode.Popular.ToString();
        }

        var searchText = string.Join(' ', searchFragments.Where(fragment => !string.IsNullOrWhiteSpace(fragment))).ToLowerInvariant();

        return FunnyKeywords.Any(keyword => searchText.Contains(keyword, StringComparison.Ordinal))
            ? TemplatePromoBadgeMode.Funny.ToString()
            : null;
    }
}
