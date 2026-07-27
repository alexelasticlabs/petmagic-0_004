using System.IO;

namespace PetMagic.Modules.Identity.Application.Contracts;

public sealed record UpdateUserAvatarCommand(
    Guid UserId,
    string FileName,
    string ContentType,
    byte[]? Content,
    Stream? ContentStream,
    long? ContentLengthBytes)
{
    public UpdateUserAvatarCommand(Guid userId, string fileName, string contentType, byte[] content)
        : this(userId, fileName, contentType, content, null, content.LongLength)
    {
    }

    public UpdateUserAvatarCommand(Guid userId, string fileName, string contentType, Stream contentStream, long? contentLengthBytes = null)
        : this(userId, fileName, contentType, null, contentStream, contentLengthBytes)
    {
    }
}

public sealed record RemoveUserAvatarCommand(Guid UserId);

public sealed record AdminUserDetailResponse(
    Guid UserId,
    string Email,
    string? DisplayName,
    bool IsPremium,
    bool IsActive,
    bool EmailConfirmed,
    bool TermsOfUseAccepted,
    bool PrivacyPolicyAccepted,
    bool MarketingEmailsEnabled,
    LegalAcceptanceStatusResponse LegalAcceptance,
    IReadOnlyList<string> Roles,
    DateTime CreatedAtUtc,
    UserAvatarResponse? Avatar);

public sealed record AdminAdjustUserWalletCommand(
    Guid UserId,
    string Operation,
    int Amount,
    string Reason,
    string? IdempotencyKey = null);

public sealed record DeleteAdminUserCommand(Guid UserId);

public sealed record AdminUserWalletOperationResponse(
    Guid UserId,
    string Operation,
    int Delta,
    int NewBalance,
    string Source,
    string Reason,
    DateTime OccurredAtUtc);

public sealed record AdminUserAnalyticsSummaryResponse(
    int WalletBalance,
    int TotalTokensCredited,
    int TotalTokensSpent,
    int ManualTokensGranted,
    int ManualTokensDebited,
    int TotalPurchases,
    int SuccessfulPurchases,
    int TotalPurchasedSpark,
    DateTime? LastPurchaseAtUtc,
    int TotalGenerations,
    int CompletedGenerations,
    int FailedGenerations,
    DateTime? LastGenerationAtUtc,
    int TotalViews,
    int TotalVideoViews,
    int SuccessfulLogins,
    int FailedLogins,
    DateTime? LastLoginAtUtc,
    int TemplateAnalyticsEvents,
    int AuditEvents,
    DateTime? LastActivityAtUtc);

public sealed record AdminUserAuditEventResponse(
    Guid AuditEventId,
    string Action,
    string Details,
    DateTime OccurredAtUtc);

public sealed record AdminUserPurchaseResponse(
    Guid OrderId,
    string Status,
    decimal PriceAmount,
    string CurrencyCode,
    int SparkToGrant,
    string PaymentProvider,
    DateTime CreatedAtUtc,
    DateTime? ConfirmedAtUtc);

public sealed record AdminUserGenerationResponse(
    Guid GenerationId,
    Guid TemplateId,
    string TemplateTitle,
    string TemplateType,
    string Status,
    int TokenCost,
    string? FailureCode,
    string? FailureMessage,
    string? OutputUrl,
    DateTime CreatedAtUtc,
    DateTime? CompletedAtUtc);

public sealed record AdminUserTemplateEventResponse(
    Guid EventId,
    Guid TemplateId,
    string TemplateTitle,
    string EventType,
    string Source,
    string DeviceClass,
    string CountryCode,
    Guid? GenerationId,
    string? FeedbackMessage,
    DateTime CreatedAtUtc);

public sealed record AdminUserFailureBreakdownItemResponse(
    string FailureCode,
    int Count,
    DateTime? LastOccurredAtUtc);

public sealed record AdminUserWalletLedgerItemResponse(
    Guid EntryId,
    int Delta,
    int BalanceAfter,
    string Source,
    string Reason,
    DateTime CreatedAtUtc);

public sealed record AdminUserActivityItemResponse(
    string Kind,
    string Title,
    string? Details,
    DateTime OccurredAtUtc);

public sealed record AdminUserAnalyticsResponse(
    AdminUserAnalyticsSummaryResponse Summary,
    IReadOnlyList<AdminUserActivityItemResponse> RecentActivity,
    IReadOnlyList<AdminUserAuditEventResponse> RecentAuditEvents,
    IReadOnlyList<AdminUserPurchaseResponse> RecentPurchases,
    IReadOnlyList<AdminUserGenerationResponse> RecentGenerations,
    IReadOnlyList<AdminUserTemplateEventResponse> RecentTemplateEvents,
    IReadOnlyList<AdminUserWalletLedgerItemResponse> RecentWalletLedger,
    IReadOnlyList<AdminUserFailureBreakdownItemResponse> FailureBreakdown);
