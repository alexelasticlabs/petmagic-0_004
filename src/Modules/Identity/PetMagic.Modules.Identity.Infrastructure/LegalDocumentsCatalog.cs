using System.Reflection;
using System.Text.Json;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Infrastructure;

internal sealed class LegalDocumentsCatalog : ILegalDocumentsCatalog
{
    private const string ResourceName = "PetMagic.LegalDocumentsCatalog.json";
    private static readonly LegalCatalogData Catalog = LoadCatalog();

    public string CurrentTermsOfUseVersion => Catalog.Version;

    public string CurrentPrivacyPolicyVersion => Catalog.Version;

    public LegalDocumentsResponse GetCurrentDocuments(string? locale)
    {
        var localeCode = NormalizeLocale(locale);
        if (!Catalog.Locales.TryGetValue(localeCode, out var localized))
        {
            localized = Catalog.Locales[Catalog.DefaultLocale];
        }

        return new LegalDocumentsResponse(
            ToResponse(LegalDocumentKinds.TermsOfUse, localized.TermsOfUse),
            ToResponse(LegalDocumentKinds.PrivacyPolicy, localized.PrivacyPolicy));
    }

    public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
    {
        return string.Equals(termsOfUseVersion, CurrentTermsOfUseVersion, StringComparison.Ordinal)
            && string.Equals(privacyPolicyVersion, CurrentPrivacyPolicyVersion, StringComparison.Ordinal);
    }

    private static LegalDocumentResponse ToResponse(string kind, LegalDocumentData document)
    {
        return new LegalDocumentResponse(
            kind,
            document.Title,
            Catalog.Version,
            Catalog.PublishedAtUtc,
            document.Summary,
            document.Sections
                .Select(section => new LegalDocumentSectionResponse(section.Title, section.Paragraphs))
                .ToArray());
    }

    private static string NormalizeLocale(string? locale)
    {
        var normalized = locale?.Trim().Replace('_', '-').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return Catalog.DefaultLocale;
        }

        var separatorIndex = normalized.IndexOf('-');
        return separatorIndex < 0 ? normalized : normalized[..separatorIndex];
    }

    private static LegalCatalogData LoadCatalog()
    {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException($"Embedded legal catalog '{ResourceName}' was not found.");
        var catalog = JsonSerializer.Deserialize<LegalCatalogData>(
            stream,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException("Embedded legal catalog is empty or invalid.");

        if (string.IsNullOrWhiteSpace(catalog.Version)
            || catalog.PublishedAtUtc.Kind != DateTimeKind.Utc
            || string.IsNullOrWhiteSpace(catalog.DefaultLocale)
            || !catalog.Locales.ContainsKey(catalog.DefaultLocale))
        {
            throw new InvalidOperationException("Embedded legal catalog metadata is invalid.");
        }

        return catalog;
    }

    private sealed record LegalCatalogData(
        string Version,
        DateTime PublishedAtUtc,
        string DefaultLocale,
        string[] RequiredLocales,
        Dictionary<string, LegalLocaleData> Locales);

    private sealed record LegalLocaleData(
        LegalDocumentData TermsOfUse,
        LegalDocumentData PrivacyPolicy);

    private sealed record LegalDocumentData(
        string Title,
        string Summary,
        LegalSectionData[] Sections);

    private sealed record LegalSectionData(string Title, string[] Paragraphs);
}
