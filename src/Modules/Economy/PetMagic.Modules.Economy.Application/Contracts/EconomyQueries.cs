namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record GetPaywallConfigQuery(string Platform, string AppVersion, string Country, string Locale);

public sealed record GetWalletCheckoutConfigQuery(string Platform, string AppVersion, string Country, string Locale);

public sealed record TestPaymentProviderConfigurationMatchQuery(
    string Provider,
    string Platform,
    string Country,
    string AppVersion);
