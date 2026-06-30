using System.Net;
using System.Security.Cryptography;
using System.Text;

using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Infrastructure;

public sealed partial class IdentityService
{
    private static string CreateVerificationCode(int length)
    {
        var size = 6;
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

    private UserAvatarResponse? ToAvatarResponse(AppUser user)
    {
        if (string.IsNullOrWhiteSpace(user.AvatarUrl)
            || string.IsNullOrWhiteSpace(user.AvatarFileName)
            || string.IsNullOrWhiteSpace(user.AvatarContentType))
        {
            return null;
        }

        var avatarUrl = ResolveManagedAvatarUrl(user.AvatarUrl);
        if (string.IsNullOrWhiteSpace(avatarUrl))
        {
            return null;
        }

        return new UserAvatarResponse(
            avatarUrl,
            user.AvatarFileName,
            user.AvatarContentType,
            user.AvatarFileSizeBytes,
            user.AvatarUpdatedAtUtc);
    }

    private string? ResolveManagedAvatarUrl(string? avatarUrl)
    {
        if (string.IsNullOrWhiteSpace(avatarUrl))
        {
            return null;
        }

        var trimmed = avatarUrl.Trim();
        var baseUrl = avatarStorageOptions.PublicBaseUrl.TrimEnd('/');
        if (!trimmed.StartsWith(baseUrl, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var relativePath = trimmed[baseUrl.Length..].TrimStart('/').Replace('\\', '/');
        if (!relativePath.StartsWith("user-avatars/", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return avatarReadUrlSigner.CreateReadUrl(trimmed);
    }

    private LegalAcceptanceStatusResponse ToLegalAcceptanceResponse(AppUser user)
    {
        var currentTermsVersion = legalDocumentsCatalog.CurrentTermsOfUseVersion;
        var currentPrivacyVersion = legalDocumentsCatalog.CurrentPrivacyPolicyVersion;
        var requiresAcceptance = !user.TermsOfUseAccepted
            || !user.PrivacyPolicyAccepted
            || !string.Equals(user.TermsOfUseAcceptedVersion, currentTermsVersion, StringComparison.Ordinal)
            || !string.Equals(user.PrivacyPolicyAcceptedVersion, currentPrivacyVersion, StringComparison.Ordinal);

        return new LegalAcceptanceStatusResponse(
            user.TermsOfUseAccepted,
            user.TermsOfUseAcceptedVersion,
            user.TermsOfUseAcceptedAtUtc,
            user.PrivacyPolicyAccepted,
            user.PrivacyPolicyAcceptedVersion,
            user.PrivacyPolicyAcceptedAtUtc,
            currentTermsVersion,
            currentPrivacyVersion,
            requiresAcceptance);
    }

    private AdminUserDetailResponse ToAdminUserDetailResponse(AppUser user, IEnumerable<string> roles) =>
        new(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.IsPremium,
            user.IsActive,
            user.EmailConfirmed,
            user.TermsOfUseAccepted,
            user.PrivacyPolicyAccepted,
            user.MarketingEmailsEnabled,
            ToLegalAcceptanceResponse(user),
            [.. roles],
            user.CreatedAtUtc,
            ToAvatarResponse(user));

    private async Task<IReadOnlyList<LinkedAccountResponse>> ListLinkedAccountsAsync(AppUser user)
    {
        var providerAccounts = await dbContext.ExternalAuthProviders
            .Where(x => x.UserId == user.Id)
            .OrderBy(x => x.Provider)
            .ToListAsync();

        return [.. providerAccounts
            .GroupBy(x => x.Provider, StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .Select(group => new LinkedAccountResponse(
                group.First().Provider,
                ToLinkedAccountDisplayName(group.First().Provider),
                CanDisconnectLinkedProvider(user, providerAccounts, group.Count())))];
    }

    private static bool CanDisconnectLinkedProvider(AppUser user, IEnumerable<ExternalAuthProvider> allLogins, int providerLoginCount)
    {
        if (!string.IsNullOrWhiteSpace(user.PasswordHash))
        {
            return true;
        }

        return allLogins.Count() > providerLoginCount;
    }

    private static string ToLinkedAccountDisplayName(string provider)
    {
        if (string.Equals(provider, "Google", StringComparison.OrdinalIgnoreCase))
        {
            return "Google";
        }

        if (string.Equals(provider, "Apple", StringComparison.OrdinalIgnoreCase))
        {
            return "Apple";
        }

        return provider;
    }

    private static string? NormalizeEmail(string? email)
    {
        var normalized = email?.Trim();
        return string.IsNullOrWhiteSpace(normalized) ? null : normalized;
    }

    private static string? NormalizeExternalProvider(string? provider)
    {
        if (string.Equals(provider, "Google", StringComparison.OrdinalIgnoreCase))
        {
            return "Google";
        }

        if (string.Equals(provider, "Apple", StringComparison.OrdinalIgnoreCase))
        {
            return "Apple";
        }

        return null;
    }

    private async Task<bool> IsDeletedEmailBlockedAsync(string email, CancellationToken cancellationToken)
    {
        var normalizedEmail = NormalizeEmail(email);
        return !string.IsNullOrWhiteSpace(normalizedEmail)
            && await dbContext.DeletedAccountBlocks
                .AnyAsync(x => x.Email == normalizedEmail, cancellationToken);
    }

    private async Task<bool> IsDeletedProviderBlockedAsync(string provider, string providerUserId, CancellationToken cancellationToken)
    {
        return await dbContext.DeletedAccountBlocks
            .AnyAsync(
                x => x.Provider == provider && x.ProviderUserId == providerUserId,
                cancellationToken);
    }

    private UserProfileResponse ToUserProfileResponse(AppUser user, IEnumerable<string> roles) =>
        new(
            user.Id,
            user.Email ?? string.Empty,
            user.DisplayName,
            user.IsPremium,
            user.EmailConfirmed,
            user.AccountStatus.ToString(),
            user.TermsOfUseAccepted,
            user.PrivacyPolicyAccepted,
            user.MarketingEmailsEnabled,
            ToLegalAcceptanceResponse(user),
            [.. roles],
            ToAvatarResponse(user));
}
