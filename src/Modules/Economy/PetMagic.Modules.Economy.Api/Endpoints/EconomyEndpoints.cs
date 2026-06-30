using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Economy.Application.Contracts;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class EconomyEndpoints
{
    private const string InvalidSubjectCode = "economy.invalid_subject";
    private const string InvalidSubjectMessage = "Invalid access token subject.";
    private const string InsufficientBalanceCode = "economy.insufficient_balance";
    private const string PurchaseNotFoundCode = "economy.purchase_not_found";
    private const string InvalidStripeSignatureCode = "economy.invalid_stripe_signature";
    private const string InvalidStoreWebhookSignatureCode = "economy.invalid_store_webhook_signature";
    private const string InvalidWebhookPayloadCode = "economy.invalid_webhook_payload";

    public static IEndpointRouteBuilder MapEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/economy")
            .WithTags("Economy")
            .RequireRateLimiting("economy")
            .RequireAuthorization(policy => policy
                .RequireAuthenticatedUser()
                .RequireAssertion(context =>
                    context.User.IsInRole("Admin")
                    || context.User.IsInRole("Moderator")
                    || !context.User.HasClaim(c => c.Type == "account_status")
                    || string.Equals(
                        context.User.FindFirst("account_status")?.Value,
                        "Active",
                        StringComparison.Ordinal)));

        group.MapGet("/wallet", GetWalletAsync)
            .RequireAuthorization();

        group.MapGet("/wallet/ledger", GetWalletLedgerAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-weekly", ClaimWeeklyAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/claim-ad", ClaimAdRewardAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/spend", SpendAsync)
            .RequireAuthorization();

        group.MapPost("/wallet/redeem", RedeemCodeAsync)
            .RequireAuthorization();

        group.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireAuthorization();

        group.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireAuthorization();

        group.MapGet("/rewards", GetRewardsSummaryAsync)
            .RequireAuthorization();

        group.MapPost("/referrals/activate", ActivateReferralCodeAsync)
            .RequireAuthorization();

        group.MapGet("/packs", ListPacksAsync)
            .AllowAnonymous();

        group.MapGet("/wallet/checkout-config", GetWalletCheckoutConfigAsync)
            .AllowAnonymous();

        group.MapGet("/premium/plans", ListPremiumPlansAsync)
            .AllowAnonymous();

        group.MapGet("/subscriptions/paywall-config", GetPaywallConfigAsync)
            .AllowAnonymous();

        endpoints.MapGet("/api/billing/products", GetBillingProductsAsync)
            .WithTags("Billing")
            .AllowAnonymous()
            .RequireRateLimiting("economy");

        group.MapGet("/premium/status", GetPremiumStatusAsync)
            .RequireAuthorization();

        group.MapGet("/me/subscription", GetSubscriptionSummaryAsync)
            .RequireAuthorization();

        group.MapGet("/premium/stripe-diagnostics", GetStripeDiagnosticsAsync)
            .RequireAuthorization("AdminOnly");

        group.MapPost("/premium/checkout", CreatePremiumCheckoutAsync)
            .RequireAuthorization();

        group.MapPost("/premium/manage", CreatePremiumBillingPortalAsync)
            .RequireAuthorization();

        group.MapPost("/premium/cancel", CancelPremiumSubscriptionAsync)
            .RequireAuthorization();

        group.MapPost("/premium/store/verify", VerifyPremiumStorePurchaseAsync)
            .RequireAuthorization();

        endpoints.MapPost("/api/billing/google/validate", ValidateGooglePlayBillingAsync)
            .WithTags("Billing")
            .RequireAuthorization()
            .RequireRateLimiting("economy");

        endpoints.MapPost("/api/billing/apple/validate", ValidateAppleAppStoreBillingAsync)
            .WithTags("Billing")
            .RequireAuthorization()
            .RequireRateLimiting("economy");

        group.MapPost("/premium/verify-stripe", VerifyPremiumStripeSubscriptionAsync)
            .RequireAuthorization();

        group.MapGet("/payment-methods", ListPaymentMethodsAsync)
            .RequireAuthorization();

        group.MapPost("/payment-methods/setup", CreatePaymentMethodSetupAsync)
            .RequireAuthorization();

        group.MapDelete("/payment-methods/{paymentMethodId:guid}", RemovePaymentMethodAsync)
            .RequireAuthorization();

        group.MapGet("/purchases", ListPurchasesAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/create", CreatePurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/{orderId:guid}/confirm", ConfirmPurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/{orderId:guid}/verify-stripe", VerifyStripeCheckoutAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/{orderId:guid}/verify-store", VerifyStoreCheckoutAsync)
            .RequireAuthorization();

        group.MapGet("/purchases/{orderId:guid}", GetPurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/webhooks/stripe", StripeWebhookAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks");

        group.MapPost("/webhooks/app-store", AppStoreServerNotificationAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks");

        endpoints.MapPost("/api/webhooks/apple-app-store", AppStoreServerNotificationAsync)
            .WithTags("Billing Webhooks")
            .AllowAnonymous()
            .RequireRateLimiting("webhooks");

        group.MapPost("/webhooks/google-play", GooglePlayDeveloperNotificationAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks");

        endpoints.MapPost("/api/webhooks/google-play", GooglePlayDeveloperNotificationAsync)
            .WithTags("Billing Webhooks")
            .AllowAnonymous()
            .RequireRateLimiting("webhooks");

        var stripePaymentsGroup = endpoints.MapGroup("/api/payments/stripe")
            .WithTags("Stripe Payments")
            .RequireRateLimiting("economy")
            .RequireAuthorization(policy => policy
                .RequireAuthenticatedUser()
                .RequireAssertion(context =>
                    context.User.IsInRole("Admin")
                    || context.User.IsInRole("Moderator")
                    || !context.User.HasClaim(c => c.Type == "account_status")
                    || string.Equals(
                        context.User.FindFirst("account_status")?.Value,
                        "Active",
                        StringComparison.Ordinal)));

        stripePaymentsGroup.MapPost("/token-purchase", CreateStripeTokenPurchaseAsync)
            .RequireAuthorization();

        stripePaymentsGroup.MapPost("/subscription", CreateStripeSubscriptionAsync)
            .RequireAuthorization();

        stripePaymentsGroup.MapPost("/customer-portal", CreateStripeCustomerPortalAsync)
            .RequireAuthorization();

        stripePaymentsGroup.MapGet("/diagnostics", GetStripeDiagnosticsAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }
}
