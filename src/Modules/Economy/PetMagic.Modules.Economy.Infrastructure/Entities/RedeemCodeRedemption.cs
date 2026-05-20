namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class RedeemCodeRedemption
{
    public Guid Id { get; set; }

    public Guid RedeemCodeId { get; set; }

    public Guid UserId { get; set; }

    public Guid WalletLedgerEntryId { get; set; }

    public DateTime RedeemedAtUtc { get; set; }
}
