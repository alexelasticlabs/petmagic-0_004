namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class WalletTokenBucket
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Kind { get; set; } = string.Empty;

    public int InitialAmount { get; set; }

    public int RemainingAmount { get; set; }

    public Guid? SourceLedgerEntryId { get; set; }

    public string Source { get; set; } = string.Empty;

    public string Reason { get; set; } = string.Empty;

    public DateTime? ExpiresAtUtc { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
