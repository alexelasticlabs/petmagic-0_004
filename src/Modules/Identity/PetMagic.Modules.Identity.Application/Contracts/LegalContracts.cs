namespace PetMagic.Modules.Identity.Application.Contracts;

public static class LegalDocumentKinds
{
    public const string TermsOfUse = "terms-of-use";

    public const string PrivacyPolicy = "privacy-policy";
}

public sealed record LegalDocumentSectionResponse(
    string Heading,
    IReadOnlyList<string> Paragraphs);

public sealed record LegalDocumentResponse(
    string Kind,
    string Title,
    string Version,
    DateTime PublishedAtUtc,
    string Summary,
    IReadOnlyList<LegalDocumentSectionResponse> Sections);

public sealed record LegalDocumentsResponse(
    LegalDocumentResponse TermsOfUse,
    LegalDocumentResponse PrivacyPolicy);

public sealed record LegalAcceptanceStatusResponse(
    bool TermsOfUseAccepted,
    string? TermsOfUseAcceptedVersion,
    DateTime? TermsOfUseAcceptedAtUtc,
    bool PrivacyPolicyAccepted,
    string? PrivacyPolicyAcceptedVersion,
    DateTime? PrivacyPolicyAcceptedAtUtc,
    string CurrentTermsOfUseVersion,
    string CurrentPrivacyPolicyVersion,
    bool RequiresAcceptance);

public sealed record AcceptLegalDocumentsCommand(
    string TermsOfUseVersion,
    string PrivacyPolicyVersion);
