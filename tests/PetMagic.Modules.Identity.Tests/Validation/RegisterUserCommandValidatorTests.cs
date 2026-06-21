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
        Assert.Contains(result.Errors, error => error.PropertyName == nameof(RegisterUserCommand.Password)
            && error.ErrorMessage == "auth.password_policy_invalid");
    }

    [Theory]
    [InlineData("pet12345")]
    [InlineData("PET12345")]
    [InlineData("PetMagic")]
    [InlineData("Pet1234")]
    public void Should_Fail_With_Machine_Readable_Key_When_Password_Policy_Is_Not_Met(string password)
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", password, "Demo", true, true, CurrentLegalVersion, CurrentLegalVersion, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == nameof(RegisterUserCommand.Password)
            && error.ErrorMessage == "auth.password_policy_invalid");
    }

    [Fact]
    public void Should_Fail_With_Machine_Readable_Key_When_Email_Is_Invalid()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("not-an-email", "Pet12345", "Demo", true, true, CurrentLegalVersion, CurrentLegalVersion, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == nameof(RegisterUserCommand.Email)
            && error.ErrorMessage == "auth.email_invalid");
    }

    [Fact]
    public void Should_Fail_When_Terms_Are_Not_Accepted()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", false, true, CurrentLegalVersion, CurrentLegalVersion, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == nameof(RegisterUserCommand.TermsOfUseAccepted)
            && error.ErrorMessage == "auth.terms_required");
    }

    [Fact]
    public void Should_Pass_When_Payload_Is_Valid()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", true, true, CurrentLegalVersion, CurrentLegalVersion, true);

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Should_Pass_When_Document_Versions_Are_Omitted_But_Both_Documents_Are_Accepted()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", true, true, "", "", true);

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }

    [Fact]
    public void Should_Fail_With_Machine_Readable_Key_When_Document_Versions_Are_Stale()
    {
        var validator = new RegisterUserCommandValidator(new FakeLegalDocumentsCatalog());
        var command = new RegisterUserCommand("demo@petmagic.app", "Pet12345", "Demo", true, true, "old", "old", true);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.ErrorMessage == "auth.legal_versions_invalid");
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
