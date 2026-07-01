namespace PetMagic.Modules.Templates.Infrastructure;

internal static class FakeAiFailure
{
    public const string Sentinel = "__petmagic_fake_fail__";

    public static bool IsRequested(params string?[] values)
    {
        return values.Any(value => value?.Contains(Sentinel, StringComparison.OrdinalIgnoreCase) == true);
    }
}
