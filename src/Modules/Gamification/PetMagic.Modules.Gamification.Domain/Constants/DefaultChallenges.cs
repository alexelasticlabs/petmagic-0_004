namespace PetMagic.Modules.Gamification.Domain.Constants;

public static class DefaultChallenges
{
    public static readonly ChallengeTemplate[] Templates =
    [
        new("generate_images", 5, "gamificationChallengeGenerateImages", "gamificationChallengeGenerateImagesDesc", 25),
        new("try_templates", 3, "gamificationChallengeTryTemplates", "gamificationChallengeTryTemplatesDesc", 20),
        new("share_creations", 2, "gamificationChallengeShareCreations", "gamificationChallengeShareCreationsDesc", 15)
    ];

    public sealed record ChallengeTemplate(
        string ChallengeType,
        int TargetValue,
        string TitleKey,
        string DescriptionKey,
        int RewardSpark);
}
