using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Infrastructure.Entities;

public sealed class UserEmailCode
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Email { get; set; } = string.Empty;

    public EmailCodePurpose Purpose { get; set; }

    public string CodeHash { get; set; } = string.Empty;

    public DateTime RequestedAtUtc { get; set; }

    public DateTime ExpiresAtUtc { get; set; }

    public DateTime? ConsumedAtUtc { get; set; }

    public DateTime? LastSentAtUtc { get; set; }

    public int SendCount { get; set; }

    public int FailedAttemptCount { get; set; }

    public DateTime? LockedAtUtc { get; set; }
}
