namespace PetMagic.BuildingBlocks.Security;

public static class FirebaseProjectIdPolicy
{
    public static bool IsSafeProjectId(string? value)
    {
        var trimmed = value?.Trim();
        return !string.IsNullOrEmpty(trimmed)
            && trimmed.Length <= 64
            && !trimmed.Any(char.IsWhiteSpace)
            && !trimmed.Contains('/', StringComparison.Ordinal)
            && !trimmed.Contains('\\', StringComparison.Ordinal)
            && !trimmed.Contains('?', StringComparison.Ordinal)
            && !trimmed.Contains('#', StringComparison.Ordinal)
            && !trimmed.Contains(':', StringComparison.Ordinal)
            && !trimmed.Contains('@', StringComparison.Ordinal);
    }
}
