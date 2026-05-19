using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class RegisterUserCommandValidatorTests
{
    [Fact]
    public void Should_Fail_When_Password_Is_Weak()
    {
        var validator = new RegisterUserCommandValidator();
        var command = new RegisterUserCommand("demo@petmagic.app", "weak", "Demo", true, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Should_Fail_When_Terms_Are_Not_Accepted()
    {
        var validator = new RegisterUserCommandValidator();
        var command = new RegisterUserCommand("demo@petmagic.app", "pet123", "Demo", false, false);

        var result = validator.Validate(command);

        Assert.False(result.IsValid);
    }

    [Fact]
    public void Should_Pass_When_Payload_Is_Valid()
    {
        var validator = new RegisterUserCommandValidator();
        var command = new RegisterUserCommand("demo@petmagic.app", "pet123", "Demo", true, true);

        var result = validator.Validate(command);

        Assert.True(result.IsValid);
    }
}
