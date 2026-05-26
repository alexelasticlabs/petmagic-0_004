namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class SubscriptionPlan
{
    public string Id { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;

    public string BillingPeriod { get; set; } = "monthly";

    public decimal PriceAmount { get; set; }

    public string CurrencyCode { get; set; } = "USD";

    public int MonthlyTokenLimit { get; set; }

    public bool IsRecommended { get; set; }

    public bool IsActive { get; set; } = true;

    public string? AppleProductId { get; set; }

    public string? GoogleProductId { get; set; }

    public string? StripePriceId { get; set; }

    public int DisplayOrder { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
