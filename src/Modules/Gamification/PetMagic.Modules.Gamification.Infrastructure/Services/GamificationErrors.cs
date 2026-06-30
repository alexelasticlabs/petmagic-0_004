using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Gamification.Infrastructure.Services;

internal static class GamificationErrors
{
    public static readonly Error StreakNotFound = new("gamification.streak_not_found", "No streak exists for the specified user.");
}
