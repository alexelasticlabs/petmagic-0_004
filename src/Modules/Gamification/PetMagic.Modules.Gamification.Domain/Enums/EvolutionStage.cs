namespace PetMagic.Modules.Gamification.Domain.Enums;

public static class EvolutionStage
{
    public const string Egg = "egg";
    public const string Baby = "baby";
    public const string Teen = "teen";
    public const string Adult = "adult";
    public const string Legendary = "legendary";

    public static string FromLevel(int level) => level switch
    {
        <= 2 => Egg,
        <= 4 => Baby,
        <= 6 => Teen,
        <= 8 => Adult,
        _ => Legendary
    };
}
