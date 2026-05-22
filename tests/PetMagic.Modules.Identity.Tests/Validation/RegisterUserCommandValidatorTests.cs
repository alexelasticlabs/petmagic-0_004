using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class RegisterUserCommandValidatorTests
{
    private const string CurrentLegalVersion = "2026-05-20";

    [Fact]
    public void Should_Fail_When_Password_Is_Weak()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "weak", "Demo", true, true, CurrentLegalVersion, CurrentLegalVersion, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Should_Fail_When_Terms_Are_Not_Accepted()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", false, true, CurrentLegalVersion, CurrentLegalVersion, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Should_Pass_When_Payload_Is_Valid()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", true, true, CurrentLegalVersion, CurrentLegalVersion, true);

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }

    private sealed class FakeLegalDocumentsCatalog : ILegalDocumentsCatalog
    {
        public string CurrentTermsOfUseVersion => CurrentLegalVersion;

        public string CurrentPrivacyPolicyVersion => CurrentLegalVersion;

        public LegalDocumentsResponse GetCurrentDocuments(string? locale)
        {
            return new LegalDocumentsResponse(
                new LegalDocumentResponse(LegalDocumentKinds.TermsOfUse, "Terms", CurrentLegalVersion, DateTime.UtcNow, "Summary", []),
                new LegalDocumentResponse(LegalDocumentKinds.PrivacyPolicy, "Privacy", CurrentLegalVersion, DateTime.UtcNow, "Summary", []));
        }

        public bool MatchesCurrentVersions(string? termsOfUseVersion, string? privacyPolicyVersion)
        {
            return string.Equals(termsOfUseVersion, CurrentLegalVersion, StringComparison.Ordinal)
                && string.Equals(privacyPolicyVersion, CurrentLegalVersion, StringComparison.Ordinal);
        }
    }
}
