namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class SavedPaymentMethod
{
    public Guid Id { get; set; }

    public Guid UserId { get; set; }

    public string Provider { get; set; } = "stripe";

    public string ExternalPaymentMethodId { get; set; } = string.Empty;

    public string Brand { get; set; } = string.Empty;

    public string Last4 { get; set; } = string.Empty;

    public long? ExpMonth { get; set; }

    public long? ExpYear { get; set; }

    public bool IsDefault { get; set; }

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}
