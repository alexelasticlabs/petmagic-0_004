using PetMagic.Modules.Identity.Application.Contracts;

namespace PetMagic.Modules.Identity.Application.Abstractions;

public interface ILegalDocumentsCatalog
{
    string CurrentTermsOfUseVersion { get; }

    string CurrentPrivacyPolicyVersion { get; }

    LegalDocumentsResponse GetCurrentDocuments(string? locale);

    bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion);
}
