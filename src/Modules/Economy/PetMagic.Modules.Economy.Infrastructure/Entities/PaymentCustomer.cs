namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class PaymentCustomer
{
    public Guid UserId { get; set; }

    public string Provider { get; set; } = "stripe";

    public string ExternalCustomerId { get; set; } = string.Empty;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
