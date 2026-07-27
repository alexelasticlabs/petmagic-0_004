using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Application.Validation;

namespace PetMagic.Modules.Identity.Tests.Validation;

public sealed class AdminUserSessionValidatorTests
{
    [Fact]
    public async Task RevokeOne_ShouldRequireReasonAndIdempotencyKey()
    {
        var validator = new AdminRevokeUserSessionCommandValidator();
        var result = await validator.ValidateAsync(new AdminRevokeUserSessionCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            Guid.NewGuid(),
            "   ",
            null));

        Assert.False(result.IsValid);
        Assert.Contains(result.Errors, error => error.PropertyName == "Reason");
        Assert.Contains(result.Errors, error => error.PropertyName == "IdempotencyKey");
    }

    [Fact]
    public async Task RevokeAll_ShouldAcceptBoundedOperationalInput()
    {
        var validator = new AdminRevokeAllUserSessionsCommandValidator();
        var result = await validator.ValidateAsync(new AdminRevokeAllUserSessionsCommand(
            Guid.NewGuid(),
            Guid.NewGuid(),
            "Verified security incident",
            "session-intent-1"));

        Assert.True(result.IsValid);
    }
}
