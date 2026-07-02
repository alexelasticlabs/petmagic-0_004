namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class WalletLedgerEntry
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public int Delta { get; set; }

    public int BalanceAfter { get; set; }

    public string Source { get; set; } = string.Empty;

    public string Reason { get; set; } = string.Empty;

    public string TokenKind { get; set; } = string.Empty;

    public string OperationKind { get; set; } = string.Empty;

    public Guid? TokenBucketId { get; set; }

    public string? BucketDeltasJson { get; set; }

    public DateTime? ExpiresAtUtc { get; set; }

    public string? SourceProvider { get; set; }

    public string? SourceTransactionId { get; set; }

    public DateTime CreatedAtUtc { get; set; }
}
