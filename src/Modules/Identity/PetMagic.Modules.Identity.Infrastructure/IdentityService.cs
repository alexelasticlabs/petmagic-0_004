using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService(
    UserManager<AppUser> userManager,
    RoleManager<IdentityRole<Guid>> roleManager,
    IdentityDbContext dbContext,
    IServiceProvider serviceProvider,
    IHttpContextAccessor httpContextAccessor,
    ILegalDocumentsCatalog legalDocumentsCatalog,
    IIdentityEmailTemplateRenderer emailTemplateRenderer,
    IAvatarStorage avatarStorage,
    EmailOptions emailOptions,
    AvatarStorageOptions avatarStorageOptions,
    IOptions<JwtOptions> jwtOptions) : IIdentityService
{
    private const int MaxCodeAttempts = 5;
    private const int MaxCodesPerHourPerEmail = 5;

    public Task<Result<LegalDocumentsResponse>> GetCurrentLegalDocumentsAsync(string? locale, CancellationToken cancellationToken)
    {
        return Task.FromResult(Result.Success(legalDocumentsCatalog.GetCurrentDocuments(locale)));
    }

    public async Task<Result> DeleteCurrentUserAsync(DeleteCurrentUserCommand command, CancellationToken cancellationToken)
    {
        return await DeleteUserInternalAsync(
            command.UserId,
            "user.deleted",
            "User account deleted by owner.",
            cancellationToken);
    }

    public async Task<Result<UserProfileResponse>> GetCurrentUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> UpdateCurrentUserProfileAsync(Guid userId, UpdateCurrentUserProfileCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var normalizedDisplayName = command.DisplayName?.Trim();
        user.DisplayName = string.IsNullOrWhiteSpace(normalizedDisplayName) ? null : normalizedDisplayName;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.profile.updated", "User profile updated by owner.", cancellationToken);

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> AcceptLegalDocumentsAsync(Guid userId, AcceptLegalDocumentsCommand command, CancellationToken cancellationToken)
    {
        if (!legalDocumentsCatalog.MatchesCurrentVersions(command.TermsOfUseVersion, command.PrivacyPolicyVersion))
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.LegalDocumentVersionMismatch);
        }

        var user = await userManager.FindByIdAsync(userId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var now = DateTime.UtcNow;
        user.TermsOfUseAccepted = true;
        user.TermsOfUseAcceptedAtUtc = now;
        user.TermsOfUseAcceptedVersion = command.TermsOfUseVersion;
        user.PrivacyPolicyAccepted = true;
        user.PrivacyPolicyAcceptedAtUtc = now;
        user.PrivacyPolicyAcceptedVersion = command.PrivacyPolicyVersion;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.legal_documents.accepted", $"Accepted terms {command.TermsOfUseVersion} and privacy {command.PrivacyPolicyVersion}.", cancellationToken);

        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> UpdateUserAvatarAsync(UpdateUserAvatarCommand command, CancellationToken cancellationToken)
    {
        var contentLength = command.Content?.LongLength ?? command.ContentLengthBytes ?? 0;
        if (contentLength <= 0)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.InvalidAvatarUpload);
        }

        if (!command.ContentType.StartsWith("image/", StringComparison.OrdinalIgnoreCase))
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.AvatarContentTypeNotAllowed);
        }

        if (contentLength > avatarStorageOptions.MaxFileSizeBytes)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.AvatarFileTooLarge);
        }

        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var previousAvatarUrl = user.AvatarUrl;
        AvatarUploadCommand? uploadCommand = command.Content is not null
            ? new AvatarUploadCommand(command.FileName, command.ContentType, command.Content)
            : command.ContentStream is not null
                ? new AvatarUploadCommand(command.FileName, command.ContentType, command.ContentStream, contentLength)
                : null;
        if (uploadCommand is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.InvalidAvatarUpload);
        }

        var storeResult = await avatarStorage.StoreAsync(uploadCommand, cancellationToken);
        if (storeResult.IsFailure)
        {
            return Result.Failure<UserProfileResponse>(storeResult.Error);
        }

        user.AvatarUrl = storeResult.Value.Url;
        user.AvatarFileName = storeResult.Value.FileName;
        user.AvatarContentType = storeResult.Value.ContentType;
        user.AvatarFileSizeBytes = storeResult.Value.FileSizeBytes;
        user.AvatarUpdatedAtUtc = DateTime.UtcNow;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            await avatarStorage.DeleteAsync(storeResult.Value.Url, CancellationToken.None);
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        if (!string.IsNullOrWhiteSpace(previousAvatarUrl)
            && !string.Equals(previousAvatarUrl, storeResult.Value.Url, StringComparison.OrdinalIgnoreCase))
        {
            await avatarStorage.DeleteAsync(previousAvatarUrl, CancellationToken.None);
        }

        await WriteAuditAsync(user.Id, "user.avatar.updated", "User avatar uploaded or replaced.", cancellationToken);
        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }

    public async Task<Result<UserProfileResponse>> RemoveUserAvatarAsync(RemoveUserAvatarCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserNotFound);
        }

        var previousAvatarUrl = user.AvatarUrl;
        user.AvatarUrl = null;
        user.AvatarFileName = null;
        user.AvatarContentType = null;
        user.AvatarFileSizeBytes = null;
        user.AvatarUpdatedAtUtc = null;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await avatarStorage.DeleteAsync(previousAvatarUrl, CancellationToken.None);
        await WriteAuditAsync(user.Id, "user.avatar.removed", "User avatar removed.", cancellationToken);
        var roles = await userManager.GetRolesAsync(user);
        return Result.Success(ToUserProfileResponse(user, roles));
    }


    private async Task<TokenPairResponse> IssueTokenPairAsync(AppUser user, IEnumerable<string> roles, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(jwtOptions.Value.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new("premium", user.IsPremium ? "true" : "false"),
            new("account_status", user.AccountStatus.ToString())
        };
        claims.AddRange(roles.Select(role => new Claim(ClaimTypes.Role, role)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.Value.SigningKey));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var jwt = new JwtSecurityToken(
            issuer: jwtOptions.Value.Issuer,
            audience: jwtOptions.Value.Audience,
            claims: claims,
            notBefore: now,
            expires: expiresAt,
            signingCredentials: credentials);

        var accessToken = new JwtSecurityTokenHandler().WriteToken(jwt);
        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));

        dbContext.RefreshTokenSessions.Add(new RefreshTokenSession
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            TokenHash = HashToken(refreshToken),
            CreatedAtUtc = now,
            ExpiresAtUtc = now.AddDays(jwtOptions.Value.RefreshTokenDays)
        });

        await dbContext.SaveChangesAsync(cancellationToken);

        return new TokenPairResponse(
            accessToken,
            refreshToken,
            expiresAt,
            ToUserProfileResponse(user, roles));
    }

    private async Task<Result> NormalizeAccountStatusForAuthenticatedUserAsync(AppUser user, CancellationToken cancellationToken)
    {
        if (!user.IsActive || !user.EmailConfirmed || user.AccountStatus == AccountStatus.Active)
        {
            return Result.Success();
        }

        user.AccountStatus = AccountStatus.Active;
        user.AccountStatusUpdatedAtUtc = DateTime.UtcNow;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.account_status.normalized", "Account status normalized to Active for authenticated user.", cancellationToken);
        return Result.Success();
    }

    private async Task WriteAuditAsync(Guid? subjectUserId, string action, string details, CancellationToken cancellationToken)
    {
        dbContext.AuditEvents.Add(new AuditEvent
        {
            Id = Guid.NewGuid(),
            SubjectUserId = subjectUserId,
            Action = action,
            Details = details,
            OccurredAtUtc = DateTime.UtcNow
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

    private async Task QueueEmailCodeAsync(AppUser user, EmailCodePurpose purpose, CancellationToken cancellationToken)
    {
        var email = user.Email?.Trim();
        if (string.IsNullOrWhiteSpace(email))
        {
            return;
        }

        var now = DateTime.UtcNow;
        await InvalidateActiveCodesAsync(user.Id, purpose, now, cancellationToken);

        var code = CreateVerificationCode(emailOptions.VerificationCodeLength);
        var ttlMinutes = purpose == EmailCodePurpose.EmailConfirmation
            ? emailOptions.VerificationCodeTtlMinutes
            : emailOptions.PasswordResetCodeTtlMinutes;
        var expiresAtUtc = now.AddMinutes(ttlMinutes);

        dbContext.UserEmailCodes.Add(new UserEmailCode
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Email = email,
            Purpose = purpose,
            CodeHash = HashToken(code),
            RequestedAtUtc = now,
            ExpiresAtUtc = expiresAtUtc,
            LastSentAtUtc = now,
            SendCount = 1
        });

        var locale = ResolvePreferredLocale();
        var message = purpose == EmailCodePurpose.EmailConfirmation
            ? emailTemplateRenderer.RenderEmailConfirmation(user.DisplayName, code, expiresAtUtc, locale)
            : emailTemplateRenderer.RenderPasswordReset(user.DisplayName, code, expiresAtUtc, locale);

        dbContext.EmailDispatchJobs.Add(new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            RecipientEmail = email,
            Kind = purpose == EmailCodePurpose.EmailConfirmation
                ? EmailDispatchKind.EmailConfirmation
                : EmailDispatchKind.PasswordReset,
            Status = EmailDispatchStatus.Queued,
            Subject = message.Subject,
            HtmlBody = message.HtmlBody,
            TextBody = message.TextBody,
            AttemptCount = 0,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            NextAttemptAtUtc = now
        });

        await dbContext.SaveChangesAsync(cancellationToken);
    }

}
