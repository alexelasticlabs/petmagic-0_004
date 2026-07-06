using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateLogSanitizer
{
    public static string SafeId(Guid value)
    {
        return SafeLogValues.StableHash(value.ToString("D"));
    }

    public static string SafeFileName(string? value)
    {
        return SafeLogValues.StableHash(Path.GetFileName(value));
    }

    public static string SafeContentType(string? value)
    {
        return SafeLogValues.SanitizeText(value, maxLength: 120);
    }
}
