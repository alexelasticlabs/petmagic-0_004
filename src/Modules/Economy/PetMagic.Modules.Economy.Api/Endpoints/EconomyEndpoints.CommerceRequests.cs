namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    public sealed record PaymentMethodSetupRequest(string PaymentProvider = "stripe");

    public sealed record VerifyStripeCheckoutRequest(string? StripeReferenceId);

    public sealed record CreatePurchaseRequest(
        Guid PackId,
        string CurrencyCode,
        string PaymentProvider = "stripe",
        string Platform = "web",
        string AppVersion = "1.0.0",
        string Country = "*",
        string Locale = "en",
        Guid? PaymentMethodId = null);

    public sealed record CreatePremiumCheckoutRequest(
        string PlanCode,
        string PaymentProvider = "stripe",
        string Platform = "web",
        string AppVersion = "1.0.0",
        string Country = "*",
        string Locale = "en");

    public sealed record CreatePremiumBillingPortalRequest(string PaymentProvider = "stripe");

    public sealed record CancelPremiumSubscriptionRequest(string PaymentProvider = "stripe");

    public sealed record VerifyPremiumStorePurchaseRequest(
        string PlanCode,
        string PaymentProvider,
        string ProductId,
        string ServerVerificationData,
        string? LocalVerificationData,
        string? PurchaseId,
        string? TransactionDate);

    public sealed record VerifyPremiumStripeSubscriptionRequest(
        string PlanCode,
        string ExternalSubscriptionId);

    public sealed record VerifyPackStorePurchaseRequest(
        string PaymentProvider,
        string ProductId,
        string ServerVerificationData,
        string? LocalVerificationData,
        string? PurchaseId,
        string? TransactionDate);
}
