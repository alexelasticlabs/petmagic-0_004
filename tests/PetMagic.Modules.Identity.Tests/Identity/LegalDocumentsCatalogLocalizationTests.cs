using PetMagic.Modules.Identity.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class LegalDocumentsCatalogLocalizationTests
{
    [Theory]
    [InlineData("ru-RU", "Пользовательское соглашение PetMagic")]
    [InlineData("ru", "Пользовательское соглашение PetMagic")]
    public void GetCurrentDocuments_ShouldReturnApprovedRussianCopy_ForRussianLocales(
        string locale,
        string expectedTermsTitle)
    {
        var catalog = new LegalDocumentsCatalog();

        var documents = catalog.GetCurrentDocuments(locale);

        Assert.Equal(expectedTermsTitle, documents.TermsOfUse.Title);
        Assert.Equal("Политика конфиденциальности PetMagic", documents.PrivacyPolicy.Title);
    }

    [Theory]
    [InlineData("en-US")]
    [InlineData("de-DE")]
    [InlineData("es-ES")]
    [InlineData("fr-FR")]
    [InlineData("it-IT")]
    [InlineData("pl-PL")]
    [InlineData(null)]
    public void GetCurrentDocuments_ShouldFallbackToApprovedEnglishCopy_WhenLegalTranslationIsNotApproved(
        string? locale)
    {
        var catalog = new LegalDocumentsCatalog();

        var documents = catalog.GetCurrentDocuments(locale);

        Assert.Equal("PetMagic Terms of Use", documents.TermsOfUse.Title);
        Assert.Equal("PetMagic Privacy Policy", documents.PrivacyPolicy.Title);
    }
}
