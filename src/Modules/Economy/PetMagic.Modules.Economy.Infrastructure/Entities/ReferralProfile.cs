namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class ReferralProfile
{
    public Guid UserId { get; set; }

    public string Code { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
