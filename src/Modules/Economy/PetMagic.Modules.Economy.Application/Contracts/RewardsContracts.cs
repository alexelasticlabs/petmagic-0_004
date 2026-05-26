namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record RewardsSummaryResponse(
    string ReferralCode,
    int ReferralBonusSpark,
    string ReferralStatus,
    string? ReferrerCode,
    DateTime? ReferralActivatedAtUtc,
    DateTime? ReferralQualifiedAtUtc,
    int TotalReferralBonusEarned,
    int ReferredUsersCount,
    int PendingReferredUsersCount,
    int RewardedReferredUsersCount);

public sealed record ReferralCodeAppliedResponse(
    string ReferralCode,
    string Status,
    int ReferralBonusSpark,
    DateTime ActivatedAtUtc);

public sealed record RedeemCodeAppliedResponse(
    Guid RedeemCodeId,
    string RewardKind,
    int RewardValue,
    WalletOperationResponse? WalletOperation,
    DateTime? PremiumExpiresAtUtc);
