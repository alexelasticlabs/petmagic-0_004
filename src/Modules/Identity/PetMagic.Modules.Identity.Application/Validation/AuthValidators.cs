using FluentValidation;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Application.Validation;

public sealed class RegisterUserCommandValidator : AbstractValidator<RegisterUserCommand>
{
    public RegisterUserCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(6)
            .WithMessage("Password must be at least 6 characters long.");
        RuleFor(x => x.TermsOfUseAccepted)
            .Equal(true)
            .WithMessage("Terms of Use and Privacy Policy must be accepted.");
    }
}

public sealed class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).NotEmpty();
    }
}

public sealed class RequestEmailConfirmationCommandValidator : AbstractValidator<RequestEmailConfirmationCommand>
{
    public RequestEmailConfirmationCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
    }
}

public sealed class ConfirmEmailCommandValidator : AbstractValidator<ConfirmEmailCommand>
{
    public ConfirmEmailCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Code)
            .NotEmpty()
            .MinimumLength(6)
            .MaximumLength(12);
    }
}

public sealed class RequestPasswordResetCommandValidator : AbstractValidator<RequestPasswordResetCommand>
{
    public RequestPasswordResetCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
    }
}

public sealed class ConfirmPasswordResetCommandValidator : AbstractValidator<ConfirmPasswordResetCommand>
{
    public ConfirmPasswordResetCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Code)
            .NotEmpty()
            .MinimumLength(6)
            .MaximumLength(12);
        RuleFor(x => x.NewPassword)
            .NotEmpty()
            .MinimumLength(6)
            .WithMessage("Password must be at least 6 characters long.");
    }
}

public sealed class RefreshTokenCommandValidator : AbstractValidator<RefreshTokenCommand>
{
    public RefreshTokenCommandValidator()
    {
        RuleFor(x => x.RefreshToken).NotEmpty();
    }
}

public sealed class LogoutCommandValidator : AbstractValidator<LogoutCommand>
{
    public LogoutCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.RefreshToken).NotEmpty();
    }
}

public sealed class ExternalLoginCallbackCommandValidator : AbstractValidator<ExternalLoginCallbackCommand>
{
    public ExternalLoginCallbackCommandValidator()
    {
        RuleFor(x => x.Provider).NotEmpty();
        RuleFor(x => x.ProviderSubject).NotEmpty();
    }
}

public sealed class GoogleNativeLoginCommandValidator : AbstractValidator<GoogleNativeLoginCommand>
{
    public GoogleNativeLoginCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty();
    }
}

public sealed class AssignRoleCommandValidator : AbstractValidator<AssignRoleCommand>
{
    public AssignRoleCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Role)
            .NotEmpty()
            .Must(role => SystemRoles.All.Contains(role))
            .WithMessage("Role is not supported.");
    }
}

public sealed class RevokeRoleCommandValidator : AbstractValidator<RevokeRoleCommand>
{
    public RevokeRoleCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Role)
            .NotEmpty()
            .Must(role => SystemRoles.All.Contains(role))
            .WithMessage("Role is not supported.");
    }
}

public sealed class SetPremiumStatusCommandValidator : AbstractValidator<SetPremiumStatusCommand>
{
    public SetPremiumStatusCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class SetUserActiveStatusCommandValidator : AbstractValidator<SetUserActiveStatusCommand>
{
    public SetUserActiveStatusCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class AdminAdjustUserWalletCommandValidator : AbstractValidator<AdminAdjustUserWalletCommand>
{
    private static readonly string[] SupportedOperations = ["credit", "debit"];

    public AdminAdjustUserWalletCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Operation)
            .NotEmpty()
            .Must(operation => SupportedOperations.Contains(operation, StringComparer.OrdinalIgnoreCase))
            .WithMessage("Wallet operation is not supported.");
        RuleFor(x => x.Amount)
            .GreaterThan(0)
            .LessThanOrEqualTo(100_000);
        RuleFor(x => x.Reason)
            .NotEmpty()
            .MaximumLength(120);
    }
}

public sealed class SendBulkEmailCommandValidator : AbstractValidator<SendBulkEmailCommand>
{
    public SendBulkEmailCommandValidator()
    {
        RuleFor(x => x.Audience)
            .NotEmpty()
            .Must(audience => EmailAudiences.All.Contains(audience, StringComparer.OrdinalIgnoreCase))
            .WithMessage("Audience is not supported.");

        RuleFor(x => x.Subject)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Body)
            .NotEmpty()
            .MaximumLength(10000);

        RuleFor(x => x.UserIds)
            .Must((command, userIds) =>
                !string.Equals(command.Audience, EmailAudiences.Selected, StringComparison.OrdinalIgnoreCase)
                || (userIds is { Count: > 0 } && userIds.All(id => id != Guid.Empty)))
            .WithMessage("Selected audience requires at least one user id.");
    }
}
