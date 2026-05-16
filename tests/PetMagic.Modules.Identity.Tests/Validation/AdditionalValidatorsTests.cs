using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class AdditionalValidatorsTests
{
    [Fact]
    public void ExternalLoginValidator_Should_Fail_When_Subject_Is_Missing()
    {
        var validator = new ExternalLoginCallbackCommandValidator();
        var command = new ExternalLoginCallbackCommand("Google", string.Empty, "user@petmagic.app", "User");

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void RevokeRoleValidator_Should_Fail_For_Unsupported_Role()
    {
        var validator = new RevokeRoleCommandValidator();
        var command = new RevokeRoleCommand(Guid.NewGuid(), "SuperAdmin");

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void SetUserActiveStatusValidator_Should_Pass_For_Valid_Id()
    {
        var validator = new SetUserActiveStatusCommandValidator();
        var command = new SetUserActiveStatusCommand(Guid.NewGuid(), true);

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }

    [Fact]
    public void LogoutCommandValidator_Should_Fail_When_RefreshToken_Is_Empty()
    {
        var validator = new LogoutCommandValidator();
        var command = new LogoutCommand(Guid.NewGuid(), string.Empty);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void LogoutCommandValidator_Should_Pass_For_Valid_Payload()
    {
        var validator = new LogoutCommandValidator();
        var command = new LogoutCommand(Guid.NewGuid(), "refresh-token");

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }
}
