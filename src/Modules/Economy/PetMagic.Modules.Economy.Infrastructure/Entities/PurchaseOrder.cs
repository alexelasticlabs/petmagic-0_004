namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class PurchaseOrder
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public Guid PackId { get; set; }

    public Guid? SavedPaymentMethodId { get; set; }

    public string PaymentProvider { get; set; } = "stripe";

    public string Status { get; set; } = "pending";

    public decimal PriceAmount { get; set; }

    public string CurrencyCode { get; set; } = "USD";

    public int SparkToGrant { get; set; }

    public string? ExternalPaymentId { get; set; }

    public string? CheckoutUrl { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime? ConfirmedAtUtc { get; set; }
}
