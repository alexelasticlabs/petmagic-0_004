namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class WalletLedgerEntry
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public int Delta { get; set; }

    public int BalanceAfter { get; set; }

    public string Source { get; set; } = string.Empty;

    public string Reason { get; set; } = string.Empty;

    public string? SourceProvider { get; set; }

    public string? SourceTransactionId { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
