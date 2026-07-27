using FluentValidation;

using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Application.Validation;

public sealed class RegisterUserCommandValidator : AbstractValidator<RegisterUserCommand>
{
    public RegisterUserCommandValidator(ILegalDocumentsCatalog legalDocumentsCatalog)
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Password).ApplyPasswordPolicy();
        RuleFor(x => x.TermsOfUseAccepted)
            .Equal(true)
            .WithMessage(AuthValidationMessages.TermsRequired);
        RuleFor(x => x.PrivacyPolicyAccepted)
            .Equal(true)
            .WithMessage(AuthValidationMessages.PrivacyRequired);
        RuleFor(x => x)
            .Must(command => legalDocumentsCatalog.MatchesCurrentVersions(command.TermsOfUseVersion, command.PrivacyPolicyVersion)
                || (command.TermsOfUseAccepted
                    && command.PrivacyPolicyAccepted
                    && string.IsNullOrWhiteSpace(command.TermsOfUseVersion)
                    && string.IsNullOrWhiteSpace(command.PrivacyPolicyVersion)))
            .WithMessage(AuthValidationMessages.LegalVersionsInvalid);
    }
}

public sealed class AcceptLegalDocumentsCommandValidator : AbstractValidator<AcceptLegalDocumentsCommand>
{
    public AcceptLegalDocumentsCommandValidator(ILegalDocumentsCatalog legalDocumentsCatalog)
    {
        RuleFor(x => x.TermsOfUseVersion)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.LegalVersionsInvalid);
        RuleFor(x => x.PrivacyPolicyVersion)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.LegalVersionsInvalid);
        RuleFor(x => x)
            .Must(command => legalDocumentsCatalog.MatchesCurrentVersions(command.TermsOfUseVersion, command.PrivacyPolicyVersion))
            .WithMessage(AuthValidationMessages.LegalVersionsInvalid);
    }
}

public sealed class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Password).NotEmpty();
    }
}

public sealed class UpdateCurrentUserProfileCommandValidator : AbstractValidator<UpdateCurrentUserProfileCommand>
{
    public UpdateCurrentUserProfileCommandValidator()
    {
        RuleFor(x => x.DisplayName)
            .MaximumLength(120)
            .WithMessage("users.display_name_too_long");
    }
}

public sealed class ResendEmailVerificationCodeCommandValidator : AbstractValidator<ResendEmailVerificationCodeCommand>
{
    public ResendEmailVerificationCodeCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
    }
}

public sealed class VerifyEmailCodeCommandValidator : AbstractValidator<VerifyEmailCodeCommand>
{
    public VerifyEmailCodeCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
    }
}

public sealed class RequestEmailConfirmationCommandValidator : AbstractValidator<RequestEmailConfirmationCommand>
{
    public RequestEmailConfirmationCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
    }
}

public sealed class ConfirmEmailCommandValidator : AbstractValidator<ConfirmEmailCommand>
{
    public ConfirmEmailCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
    }
}

public sealed class RequestPasswordResetCommandValidator : AbstractValidator<RequestPasswordResetCommand>
{
    public RequestPasswordResetCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
    }
}

public sealed class VerifyPasswordResetCodeCommandValidator : AbstractValidator<VerifyPasswordResetCodeCommand>
{
    public VerifyPasswordResetCodeCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
    }
}

public sealed class ResetPasswordCommandValidator : AbstractValidator<ResetPasswordCommand>
{
    public ResetPasswordCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
        RuleFor(x => x.NewPassword).ApplyPasswordPolicy();
    }
}

public sealed class ConfirmPasswordResetCommandValidator : AbstractValidator<ConfirmPasswordResetCommand>
{
    public ConfirmPasswordResetCommandValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .WithMessage(AuthValidationMessages.EmailInvalid)
            .EmailAddress()
            .WithMessage(AuthValidationMessages.EmailInvalid);
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
        RuleFor(x => x.NewPassword).ApplyPasswordPolicy();
    }
}

public sealed class ConfirmCurrentPasswordChangeCommandValidator : AbstractValidator<ConfirmCurrentPasswordChangeCommand>
{
    public ConfirmCurrentPasswordChangeCommandValidator()
    {
        RuleFor(x => x.Code)
            .NotEmpty()
            .Length(6)
            .Matches("^[0-9]{6}$");
        RuleFor(x => x.NewPassword).ApplyPasswordPolicy();
        RuleFor(x => x.RefreshToken).NotEmpty();
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

internal static class AuthValidationMessages
{
    public const string EmailInvalid = "auth.email_invalid";
    public const string PasswordPolicyInvalid = "auth.password_policy_invalid";
    public const string TermsRequired = "auth.terms_required";
    public const string PrivacyRequired = "auth.privacy_required";
    public const string LegalVersionsInvalid = "auth.legal_versions_invalid";
}

internal static class AuthPasswordValidationRules
{
    public static IRuleBuilderOptions<T, string> ApplyPasswordPolicy<T>(
        this IRuleBuilder<T, string> ruleBuilder)
    {
        return ruleBuilder
            .NotEmpty()
            .WithMessage(AuthValidationMessages.PasswordPolicyInvalid)
            .MinimumLength(8)
            .WithMessage(AuthValidationMessages.PasswordPolicyInvalid)
            .Matches("[A-Z]")
            .WithMessage(AuthValidationMessages.PasswordPolicyInvalid)
            .Matches("[a-z]")
            .WithMessage(AuthValidationMessages.PasswordPolicyInvalid)
            .Matches("[0-9]")
            .WithMessage(AuthValidationMessages.PasswordPolicyInvalid);
    }
}

public sealed class GoogleNativeLoginCommandValidator : AbstractValidator<GoogleNativeLoginCommand>
{
    public GoogleNativeLoginCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty();
    }
}

public sealed class GoogleNativeLinkCommandValidator : AbstractValidator<GoogleNativeLinkCommand>
{
    public GoogleNativeLinkCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty();
    }
}

public sealed class GoogleSocialLoginCommandValidator : AbstractValidator<GoogleSocialLoginCommand>
{
    public GoogleSocialLoginCommandValidator()
    {
        RuleFor(x => x.IdToken).NotEmpty();
        RuleFor(x => x.ServerAuthCode).NotEmpty();
    }
}

public sealed class AppleSocialLoginCommandValidator : AbstractValidator<AppleSocialLoginCommand>
{
    public AppleSocialLoginCommandValidator()
    {
        RuleFor(x => x.IdentityToken).NotEmpty();
        RuleFor(x => x.AuthorizationCode).NotEmpty();
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
            .WithMessage("users.role_not_supported");
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
            .WithMessage("users.role_not_supported");
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
            .WithMessage("economy.wallet_operation_not_supported");
        RuleFor(x => x.Amount)
            .GreaterThan(0)
            .LessThanOrEqualTo(100_000);
        RuleFor(x => x.Reason)
            .NotEmpty()
            .MaximumLength(120);
        RuleFor(x => x.IdempotencyKey)
            .MaximumLength(256);
    }
}

public sealed class AdminRevokeUserSessionCommandValidator : AbstractValidator<AdminRevokeUserSessionCommand>
{
    public AdminRevokeUserSessionCommandValidator()
    {
        RuleFor(x => x.ActorUserId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.SessionId).NotEmpty();
        RuleFor(x => x.Reason)
            .NotEmpty()
            .Must(reason => !string.IsNullOrWhiteSpace(reason))
            .WithMessage("users.session_reason_required")
            .MaximumLength(240);
        RuleFor(x => x.IdempotencyKey)
            .NotEmpty()
            .MaximumLength(256);
    }
}

public sealed class AdminRevokeAllUserSessionsCommandValidator : AbstractValidator<AdminRevokeAllUserSessionsCommand>
{
    public AdminRevokeAllUserSessionsCommandValidator()
    {
        RuleFor(x => x.ActorUserId).NotEmpty();
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Reason)
            .NotEmpty()
            .Must(reason => !string.IsNullOrWhiteSpace(reason))
            .WithMessage("users.session_reason_required")
            .MaximumLength(240);
        RuleFor(x => x.IdempotencyKey)
            .NotEmpty()
            .MaximumLength(256);
    }
}

public sealed class SendBulkEmailCommandValidator : AbstractValidator<SendBulkEmailCommand>
{
    public SendBulkEmailCommandValidator()
    {
        RuleFor(x => x.Audience)
            .NotEmpty()
            .Must(audience => EmailAudiences.All.Contains(audience, StringComparer.OrdinalIgnoreCase))
            .WithMessage("users.bulk_email_audience_invalid");

        RuleFor(x => x.Subject)
            .NotEmpty()
            .MaximumLength(200);

        RuleFor(x => x.Body)
            .NotEmpty()
            .MaximumLength(10000);

        RuleFor(x => x.IdempotencyKey)
            .MaximumLength(256);

        RuleFor(x => x.UserIds)
            .Must((command, userIds) =>
                !string.Equals(command.Audience, EmailAudiences.Selected, StringComparison.OrdinalIgnoreCase)
                || (userIds is { Count: > 0 } && userIds.All(id => id != Guid.Empty)))
            .WithMessage("users.bulk_email_user_ids_required");
    }
}

public sealed class DeleteAdminUserCommandValidator : AbstractValidator<DeleteAdminUserCommand>
{
    public DeleteAdminUserCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}
