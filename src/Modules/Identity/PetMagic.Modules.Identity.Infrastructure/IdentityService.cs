using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Net;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed class IdentityService(
    UserManager<AppUser> userManager,
    RoleManager<IdentityRole<Guid>> roleManager,
    IdentityDbContext dbContext,
    IIdentityEmailTemplateRenderer emailTemplateRenderer,
    EmailOptions emailOptions,
    IOptions<JwtOptions> jwtOptions) : IIdentityService
{
    public async Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var normalizedEmail = email.ToUpperInvariant();
        var existing = await userManager.Users
            .AnyAsync(x => x.NormalizedEmail == normalizedEmail, cancellationToken);

        if (existing)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserAlreadyExists);
        }

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            UserName = email,
            Email = email,
            EmailConfirmed = false,
            DisplayName = command.DisplayName,
            IsPremium = false,
            IsActive = true,
            CreatedAtUtc = DateTime.UtcNow
        };

        var createResult = await userManager.CreateAsync(user, command.Password);
        if (!createResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        var addRoleResult = await userManager.AddToRoleAsync(user, SystemRoles.User);
        if (!addRoleResult.Succeeded)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.OperationFailed);
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.EmailConfirmation, cancellationToken);
        await WriteAuditAsync(user.Id, "user.registered", "User self-registration completed.", cancellationToken);

        return Result.Success(ToUserProfileResponse(user, [SystemRoles.User]));
    }

    public async Task<Result<TokenPairResponse>> LoginAsync(LoginCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        var validPassword = await userManager.CheckPasswordAsync(user, command.Password);
        if (!validPassword)
        {
            await WriteAuditAsync(user.Id, "auth.login.failed", "Invalid password.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        if (!user.EmailConfirmed)
        {
            await WriteAuditAsync(user.Id, "auth.login.denied", "Login denied: email is not confirmed.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.EmailNotConfirmed);
        }

        var roles = await userManager.GetRolesAsync(user);
        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.login.succeeded", "User logged in.", cancellationToken);

        return Result.Success(tokenPair);
    }

    public async Task<Result> RequestEmailConfirmationAsync(RequestEmailConfirmationCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive || user.EmailConfirmed)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        var lastActiveCode = await dbContext.UserEmailCodes
            .Where(x => x.UserId == user.Id
                && x.Purpose == EmailCodePurpose.EmailConfirmation
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (lastActiveCode?.LastSentAtUtc is not null
            && lastActiveCode.LastSentAtUtc > now.AddSeconds(-emailOptions.ConfirmationResendCooldownSeconds))
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.EmailConfirmation, cancellationToken);
        await WriteAuditAsync(user.Id, "user.email_confirmation.requested", "Email confirmation code requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> ConfirmEmailAsync(ConfirmEmailCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure(IdentityErrors.EmailCodeInvalid);
        }

        if (user.EmailConfirmed)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        var codeEntity = await FindMatchingCodeAsync(user.Id, EmailCodePurpose.EmailConfirmation, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            return Result.Failure(IdentityErrors.EmailCodeInvalid);
        }

        codeEntity.ConsumedAtUtc = now;
        user.EmailConfirmed = true;

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "user.email_confirmed", "Email address confirmed.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RequestPasswordResetAsync(RequestPasswordResetCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == command.Email.Trim().ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive || string.IsNullOrWhiteSpace(user.Email) || string.IsNullOrWhiteSpace(user.PasswordHash))
        {
            return Result.Success();
        }

        await QueueEmailCodeAsync(user, EmailCodePurpose.PasswordReset, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_reset.requested", "Password reset requested.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> ConfirmPasswordResetAsync(ConfirmPasswordResetCommand command, CancellationToken cancellationToken)
    {
        var email = command.Email.Trim();
        var user = await userManager.Users
            .FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpperInvariant(), cancellationToken);

        if (user is null || !user.IsActive)
        {
            return Result.Failure(IdentityErrors.PasswordResetCodeInvalid);
        }

        var now = DateTime.UtcNow;
        var codeEntity = await FindMatchingCodeAsync(user.Id, EmailCodePurpose.PasswordReset, command.Code, now, cancellationToken);
        if (codeEntity is null)
        {
            return Result.Failure(IdentityErrors.PasswordResetCodeInvalid);
        }

        user.PasswordHash = userManager.PasswordHasher.HashPassword(user, command.NewPassword);
        user.SecurityStamp = Guid.NewGuid().ToString("N");

        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        codeEntity.ConsumedAtUtc = now;
        await RevokeRefreshTokensAsync(user.Id, now, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.password_reset.succeeded", "Password reset completed.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result<TokenPairResponse>> ExternalLoginAsync(ExternalLoginCallbackCommand command, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(command.Provider) || string.IsNullOrWhiteSpace(command.ProviderSubject))
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalPrincipalInvalid);
        }

        var user = await userManager.FindByLoginAsync(command.Provider, command.ProviderSubject);

        if (user is null)
        {
            if (string.IsNullOrWhiteSpace(command.Email))
            {
                return Result.Failure<TokenPairResponse>(IdentityErrors.ExternalEmailMissing);
            }

            user = await userManager.FindByEmailAsync(command.Email);

            if (user is null)
            {
                user = new AppUser
                {
                    Id = Guid.NewGuid(),
                    UserName = command.Email,
                    Email = command.Email,
                    EmailConfirmed = true,
                    DisplayName = command.DisplayName,
                    IsPremium = false,
                    IsActive = true,
                    CreatedAtUtc = DateTime.UtcNow
                };

                var createResult = await userManager.CreateAsync(user);
                if (!createResult.Succeeded)
                {
                    return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
                }

                await userManager.AddToRoleAsync(user, SystemRoles.User);
            }

            var addLoginResult = await userManager.AddLoginAsync(user, new UserLoginInfo(command.Provider, command.ProviderSubject, command.Provider));
            if (!addLoginResult.Succeeded)
            {
                return Result.Failure<TokenPairResponse>(IdentityErrors.OperationFailed);
            }
        }

        if (!user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidCredentials);
        }

        var roles = await userManager.GetRolesAsync(user);
        if (!roles.Contains(SystemRoles.User, StringComparer.Ordinal))
        {
            await userManager.AddToRoleAsync(user, SystemRoles.User);
            roles.Add(SystemRoles.User);
        }

        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.external_login.succeeded", $"External provider: {command.Provider}", cancellationToken);

        return Result.Success(tokenPair);
    }

    public async Task<Result<TokenPairResponse>> RefreshAsync(RefreshTokenCommand command, CancellationToken cancellationToken)
    {
        var hash = HashToken(command.RefreshToken);
        var session = await dbContext.RefreshTokenSessions
            .Where(x => x.TokenHash == hash)
            .FirstOrDefaultAsync(cancellationToken);

        if (session is null)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        if (session.RevokedAtUtc is not null)
        {
            await WriteAuditAsync(session.UserId, "auth.refresh.reuse_detected", "Detected refresh token reuse attempt.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        if (session.ExpiresAtUtc <= DateTime.UtcNow)
        {
            await WriteAuditAsync(session.UserId, "auth.refresh.expired", "Refresh attempt with expired token.", cancellationToken);
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        var user = await userManager.FindByIdAsync(session.UserId.ToString());
        if (user is null || !user.IsActive)
        {
            return Result.Failure<TokenPairResponse>(IdentityErrors.InvalidRefreshToken);
        }

        session.RevokedAtUtc = DateTime.UtcNow;
        var roles = await userManager.GetRolesAsync(user);
        var pair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(user.Id, "auth.refresh.succeeded", "Refresh token rotated.", cancellationToken);

        return Result.Success(pair);
    }

    public async Task<Result> LogoutAsync(LogoutCommand command, CancellationToken cancellationToken)
    {
        var hash = HashToken(command.RefreshToken);
        var session = await dbContext.RefreshTokenSessions
            .Where(x => x.TokenHash == hash)
            .FirstOrDefaultAsync(cancellationToken);

        if (session is null)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "Logout requested for non-existing refresh token.", cancellationToken);
            return Result.Success();
        }

        if (session.UserId != command.UserId)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.denied", "Logout denied: refresh token belongs to a different user.", cancellationToken);
            return Result.Failure(IdentityErrors.RefreshTokenOwnershipViolation);
        }

        if (session.RevokedAtUtc is not null)
        {
            await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "Logout requested for already revoked refresh token.", cancellationToken);
            return Result.Success();
        }

        session.RevokedAtUtc = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(command.UserId, "auth.logout.succeeded", "User logged out and refresh token revoked.", cancellationToken);

        return Result.Success();
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

    public async Task<Result<IReadOnlyList<UserListItemResponse>>> ListUsersAsync(CancellationToken cancellationToken)
    {
        var users = await userManager.Users
            .OrderByDescending(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);

        var output = new List<UserListItemResponse>(users.Count);

        foreach (var user in users)
        {
            var roles = await userManager.GetRolesAsync(user);
            output.Add(new UserListItemResponse(
                user.Id,
                user.Email ?? string.Empty,
                user.DisplayName,
                user.IsPremium,
                user.IsActive,
                user.EmailConfirmed,
                roles.ToList(),
                user.CreatedAtUtc));
        }

        return Result.Success<IReadOnlyList<UserListItemResponse>>(output);
    }

    public async Task<Result> SendBulkEmailAsync(SendBulkEmailCommand command, CancellationToken cancellationToken)
    {
        IQueryable<AppUser> query = userManager.Users
            .Where(x => x.IsActive && x.EmailConfirmed && !string.IsNullOrWhiteSpace(x.Email));

        if (string.Equals(command.Audience, EmailAudiences.Premium, StringComparison.OrdinalIgnoreCase))
        {
            query = query.Where(x => x.IsPremium);
        }
        else if (string.Equals(command.Audience, EmailAudiences.Selected, StringComparison.OrdinalIgnoreCase))
        {
            var selectedIds = command.UserIds?
                .Where(id => id != Guid.Empty)
                .Distinct()
                .ToArray() ?? [];

            query = query.Where(x => selectedIds.Contains(x.Id));
        }

        var recipients = await query
            .Select(x => new { x.Id, x.Email })
            .ToListAsync(cancellationToken);

        if (recipients.Count == 0)
        {
            return Result.Success();
        }

        var now = DateTime.UtcNow;
        foreach (var recipient in recipients)
        {
            dbContext.EmailDispatchJobs.Add(CreateBroadcastEmailJob(recipient.Id, recipient.Email!, command.Subject, command.Body, now));
        }

        await dbContext.SaveChangesAsync(cancellationToken);
        await WriteAuditAsync(null, "admin.bulk_email.queued", $"Bulk email queued for {recipients.Count} recipients.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> AssignRoleAsync(AssignRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        if (!await roleManager.RoleExistsAsync(command.Role))
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        var addResult = await userManager.AddToRoleAsync(user, command.Role);
        if (!addResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.assigned", $"Assigned role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> RevokeRoleAsync(RevokeRoleCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        if (string.Equals(command.Role, SystemRoles.User, StringComparison.Ordinal))
        {
            return Result.Failure(IdentityErrors.CannotRevokeBaseRole);
        }

        var currentRoles = await userManager.GetRolesAsync(user);
        if (!currentRoles.Contains(command.Role, StringComparer.Ordinal))
        {
            return Result.Success();
        }

        var removeResult = await userManager.RemoveFromRoleAsync(user, command.Role);
        if (!removeResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.role.revoked", $"Revoked role '{command.Role}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetPremiumStatusAsync(SetPremiumStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsPremium = command.IsPremium;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.premium.updated", $"Premium status changed to '{command.IsPremium}'.", cancellationToken);
        return Result.Success();
    }

    public async Task<Result> SetUserActiveStatusAsync(SetUserActiveStatusCommand command, CancellationToken cancellationToken)
    {
        var user = await userManager.FindByIdAsync(command.UserId.ToString());
        if (user is null)
        {
            return Result.Failure(IdentityErrors.UserNotFound);
        }

        user.IsActive = command.IsActive;
        var updateResult = await userManager.UpdateAsync(user);
        if (!updateResult.Succeeded)
        {
            return Result.Failure(IdentityErrors.OperationFailed);
        }

        await WriteAuditAsync(user.Id, "user.active.updated", $"Active status changed to '{command.IsActive}'.", cancellationToken);
        return Result.Success();
    }

    private async Task<TokenPairResponse> IssueTokenPairAsync(AppUser user, IEnumerable<string> roles, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(jwtOptions.Value.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Email, user.Email ?? string.Empty),
            new("premium", user.IsPremium ? "true" : "false")
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

        var message = purpose == EmailCodePurpose.EmailConfirmation
            ? emailTemplateRenderer.RenderEmailConfirmation(user.DisplayName, code, expiresAtUtc)
            : emailTemplateRenderer.RenderPasswordReset(user.DisplayName, code, expiresAtUtc);

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

    private async Task InvalidateActiveCodesAsync(Guid userId, EmailCodePurpose purpose, DateTime now, CancellationToken cancellationToken)
    {
        var activeCodes = await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId
                && x.Purpose == purpose
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now)
            .ToListAsync(cancellationToken);

        foreach (var activeCode in activeCodes)
        {
            activeCode.ConsumedAtUtc = now;
        }
    }

    private async Task<UserEmailCode?> FindMatchingCodeAsync(
        Guid userId,
        EmailCodePurpose purpose,
        string code,
        DateTime now,
        CancellationToken cancellationToken)
    {
        var codeHash = HashToken(code.Trim());
        return await dbContext.UserEmailCodes
            .Where(x => x.UserId == userId
                && x.Purpose == purpose
                && x.ConsumedAtUtc == null
                && x.ExpiresAtUtc > now
                && x.CodeHash == codeHash)
            .OrderByDescending(x => x.RequestedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task RevokeRefreshTokensAsync(Guid userId, DateTime revokedAtUtc, CancellationToken cancellationToken)
    {
        var sessions = await dbContext.RefreshTokenSessions
            .Where(x => x.UserId == userId && x.RevokedAtUtc == null)
            .ToListAsync(cancellationToken);

        foreach (var session in sessions)
        {
            session.RevokedAtUtc = revokedAtUtc;
        }
    }

    private static string CreateVerificationCode(int length)
    {
        var size = Math.Clamp(length, 6, 12);
        var chars = new char[size];
        for (var index = 0; index < size; index++)
        {
            chars[index] = (char)('0' + RandomNumberGenerator.GetInt32(0, 10));
        }

        return new string(chars);
    }

    private static EmailDispatchJob CreateBroadcastEmailJob(Guid userId, string recipientEmail, string subject, string body, DateTime now)
    {
        return new EmailDispatchJob
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            RecipientEmail = recipientEmail,
            Kind = EmailDispatchKind.Broadcast,
            Status = EmailDispatchStatus.Queued,
            Subject = subject.Trim(),
            HtmlBody = $"<p>{WebUtility.HtmlEncode(body).Replace("\n", "<br/>", StringComparison.Ordinal)}</p>",
            TextBody = body,
            AttemptCount = 0,
            QueuedAtUtc = now,
            UpdatedAtUtc = now,
            NextAttemptAtUtc = now
        };
    }

    private static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToHexString(bytes);
    }

    private static UserProfileResponse ToUserProfileResponse(AppUser user, IEnumerable<string> roles) =>
        new(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.IsPremium,
            user.EmailConfirmed,
            roles.ToList());
}
