using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
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
    IOptions<JwtOptions> jwtOptions) : IIdentityService
{
    public async Task<Result<UserProfileResponse>> RegisterAsync(RegisterUserCommand command, CancellationToken cancellationToken)
    {
        var normalizedEmail = command.Email.Trim().ToUpperInvariant();
        var existing = await userManager.Users
            .AnyAsync(x => x.NormalizedEmail == normalizedEmail, cancellationToken);

        if (existing)
        {
            return Result.Failure<UserProfileResponse>(IdentityErrors.UserAlreadyExists);
        }

        var user = new AppUser
        {
            Id = Guid.NewGuid(),
            UserName = command.Email,
            Email = command.Email,
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

        await userManager.AddToRoleAsync(user, SystemRoles.User);
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

        var roles = await userManager.GetRolesAsync(user);
        var tokenPair = await IssueTokenPairAsync(user, roles, cancellationToken);
        await WriteAuditAsync(user.Id, "auth.login.succeeded", "User logged in.", cancellationToken);

        return Result.Success(tokenPair);
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
                roles.ToList(),
                user.CreatedAtUtc));
        }

        return Result.Success<IReadOnlyList<UserListItemResponse>>(output);
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
            roles.ToList());
}
