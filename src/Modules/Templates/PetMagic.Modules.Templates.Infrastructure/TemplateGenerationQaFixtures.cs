namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateGenerationQaFixtures
{
    public const string InputSourceType = "qa_fixture";
    public const string RequestHashPrefix = "qa_fixture:";
    public const string SourceImageUrl = "templates-media/qa-fixtures/source.png";
    public const string SourceImageFileName = "qa-source.png";
    public const string SourceImageContentType = "image/png";

    public static bool IsQaFixture(string? inputSourceType)
    {
        return string.Equals(inputSourceType, InputSourceType, StringComparison.OrdinalIgnoreCase);
    }
}
