namespace PetMagic.Modules.Gamification.Domain.Constants;

public static class XpThresholds
{
    public const int BaseXpPerGeneration = 10;
    public const int BonusXpTemplateOfTheDay = 5;
    public const int BonusXpFirstOfDay = 3;

    public static readonly int[] LevelThresholds =
    [
        0,      // Level 1
        50,     // Level 2
        150,    // Level 3
        350,    // Level 4
        700,    // Level 5
        1200,   // Level 6
        2000,   // Level 7
        3200,   // Level 8
        5000,   // Level 9
        8000    // Level 10
    ];

    public const int MaxLevel = 10;

    public static int GetLevel(int xp)
    {
        for (var i = LevelThresholds.Length - 1; i >= 0; i--)
        {
            if (xp >= LevelThresholds[i])
            {
                return i + 1;
            }
        }

        return 1;
    }

    public static int GetXpForNextLevel(int currentLevel)
    {
        if (currentLevel >= MaxLevel)
        {
            return LevelThresholds[^1];
        }

        return LevelThresholds[currentLevel];
    }

    public static int GetXpForCurrentLevel(int currentLevel)
    {
        if (currentLevel <= 0)
        {
            return 0;
        }

        return LevelThresholds[Math.Min(currentLevel - 1, LevelThresholds.Length - 1)];
    }
}
