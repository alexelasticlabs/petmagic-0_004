using System.Net;
using System.Security.Cryptography;
using System.Text;

using Microsoft.AspNetCore.Identity;

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

    private static UserAvatarResponse? ToAvatarResponse(AppUser user)
    {
        if (string.IsNullOrWhiteSpace(user.AvatarUrl)
            || string.IsNullOrWhiteSpace(user.AvatarFileName)
            || string.IsNullOrWhiteSpace(user.AvatarContentType))
        {
            return null;
        }

        return new UserAvatarResponse(
            user.AvatarUrl,
            user.AvatarFileName,
            user.AvatarContentType,
            user.AvatarFileSizeBytes,
            user.AvatarUpdatedAtUtc);
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
        var userLogins = await userManager.GetLoginsAsync(user);

        return [.. userLogins
            .GroupBy(x => x.LoginProvider, StringComparer.OrdinalIgnoreCase)
            .OrderBy(x => x.Key, StringComparer.OrdinalIgnoreCase)
            .Select(group => new LinkedAccountResponse(
                group.First().LoginProvider,
                ToLinkedAccountDisplayName(group.First().ProviderDisplayName ?? group.First().LoginProvider),
                CanDisconnectLinkedProvider(user, userLogins, group.Count())))];
    }

    private static bool CanDisconnectLinkedProvider(AppUser user, IEnumerable<UserLoginInfo> allLogins, int providerLoginCount)
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

