namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class CurrencyPack
{
    public Guid Id { get; set; }

    public string Code { get; set; } = string.Empty;

    public string DisplayName { get; set; } = string.Empty;

    public string CurrencyCode { get; set; } = "USD";

    public decimal PriceAmount { get; set; }

    public int GrantedSpark { get; set; }

    public int BonusSpark { get; set; }

    public bool IsActive { get; set; }

    public int SortOrder { get; set; }
}
