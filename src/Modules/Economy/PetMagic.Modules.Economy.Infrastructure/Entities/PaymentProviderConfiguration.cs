namespace PetMagic.Modules.Economy.Infrastructure.Entities;

public sealed class PaymentProviderConfiguration
{
    public Guid Id { get; set; }

    public string Provider { get; set; } = string.Empty;

    public string Platform { get; set; } = string.Empty;

    public string Region { get; set; } = "*";

    public bool IsEnabled { get; set; }

    public bool IsRecommended { get; set; }

    public bool IsSelectedByDefault { get; set; }

    public bool RequiresExternalWarning { get; set; }

    public bool RequiresStoreDisclosure { get; set; }

    public string AllowedFromAppVersion { get; set; } = "0.0.0";

    public bool ExternalCheckoutAllowed { get; set; }

    public int BonusTokensPercent { get; set; }

    public string? DisplayLabel { get; set; }

    public string? DisplaySubtitle { get; set; }

    public string? WarningTitle { get; set; }

    public string? WarningMessage { get; set; }

    public string Mode { get; set; } = "test";

    public string? Notes { get; set; }

    public DateTime CreatedAtUtc { get; set; }

    public DateTime UpdatedAtUtc { get; set; }
}