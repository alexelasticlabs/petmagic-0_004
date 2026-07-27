namespace PetMagic.Modules.Identity.Application.Contracts;

public sealed record AdminUserSessionListItemResponse(
    Guid SessionId,
    string Status,
    bool CanRevoke,
    DateTime CreatedAtUtc,
    DateTime ExpiresAtUtc,
    DateTime? RevokedAtUtc);

public sealed record AdminUserSessionsResponse(
    IReadOnlyList<AdminUserSessionListItemResponse> Items,
    int TotalCount,
    int ActiveCount,
    bool HasMore);

public sealed record AdminRevokeUserSessionCommand(
    Guid ActorUserId,
    Guid UserId,
    Guid SessionId,
    string Reason,
    string? IdempotencyKey);

public sealed record AdminRevokeAllUserSessionsCommand(
    Guid ActorUserId,
    Guid UserId,
    string Reason,
    string? IdempotencyKey);

public sealed record AdminUserSessionRevokeResponse(
    Guid UserId,
    Guid? SessionId,
    int RevokedCount,
    DateTime OccurredAtUtc,
    bool Replayed);
