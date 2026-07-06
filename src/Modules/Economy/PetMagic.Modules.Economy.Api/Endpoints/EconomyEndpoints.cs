using System.Security.Claims;
using System.Text;

using FluentValidation;

using Microsoft.AspNetCore.Authorization;
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
    private const string InvalidSubjectMessage = InvalidSubjectCode;
    private const string InsufficientBalanceCode = "economy.insufficient_balance";
    private const string PurchaseNotFoundCode = "economy.purchase_not_found";
    private const string InvalidStripeSignatureCode = "economy.invalid_stripe_signature";
    private const string InvalidStoreWebhookSignatureCode = "economy.invalid_store_webhook_signature";
    private const string InvalidWebhookPayloadCode = "economy.invalid_webhook_payload";
    private const int MaxEconomyJsonRequestBodyBytes = 32 * 1024;
    private const int MaxEconomyWebhookRequestBodyBytes = 256 * 1024;

    public static IEndpointRouteBuilder MapEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/economy")
            .WithTags("Economy")
            .RequireRateLimiting("economy")
            .AddEndpointFilter(ApplyPrivateEconomyResponseHeadersAsync)
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
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/wallet/claim-ad", ClaimAdRewardAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/wallet/redeem", RedeemCodeAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapGet("/rewards", GetRewardsSummaryAsync)
            .RequireAuthorization();

        group.MapPost("/referrals/activate", ActivateReferralCodeAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

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
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/premium/manage", CreatePremiumBillingPortalAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/premium/cancel", CancelPremiumSubscriptionAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/premium/store/verify", VerifyPremiumStorePurchaseAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        endpoints.MapPost("/api/billing/google/validate", ValidateGooglePlayBillingAsync)
            .WithTags("Billing")
            .AddEndpointFilter(ApplyPrivateEconomyResponseHeadersAsync)
            .RequireAuthorization()
            .RequireRateLimiting("economy")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        endpoints.MapPost("/api/billing/apple/validate", ValidateAppleAppStoreBillingAsync)
            .WithTags("Billing")
            .AddEndpointFilter(ApplyPrivateEconomyResponseHeadersAsync)
            .RequireAuthorization()
            .RequireRateLimiting("economy")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/premium/verify-stripe", VerifyPremiumStripeSubscriptionAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapGet("/payment-methods", ListPaymentMethodsAsync)
            .RequireAuthorization();

        group.MapPost("/payment-methods/setup", CreatePaymentMethodSetupAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapDelete("/payment-methods/{paymentMethodId:guid}", RemovePaymentMethodAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapGet("/purchases", ListPurchasesAsync)
            .RequireAuthorization();

        group.MapPost("/purchases/create", CreatePurchaseAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/purchases/{orderId:guid}/verify-stripe", VerifyStripeCheckoutAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapPost("/purchases/{orderId:guid}/verify-store", VerifyStoreCheckoutAsync)
            .RequireAuthorization()
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyJsonRequestBodyBytes));

        group.MapGet("/purchases/{orderId:guid}", GetPurchaseAsync)
            .RequireAuthorization();

        group.MapPost("/webhooks/stripe", StripeWebhookAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyWebhookRequestBodyBytes));

        group.MapPost("/webhooks/app-store", AppStoreServerNotificationAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyWebhookRequestBodyBytes));

        endpoints.MapPost("/api/webhooks/apple-app-store", AppStoreServerNotificationAsync)
            .WithTags("Billing Webhooks")
            .AllowAnonymous()
            .RequireRateLimiting("webhooks")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyWebhookRequestBodyBytes));

        group.MapPost("/webhooks/google-play", GooglePlayDeveloperNotificationAsync)
            .AllowAnonymous()
            .RequireRateLimiting("webhooks")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyWebhookRequestBodyBytes));

        endpoints.MapPost("/api/webhooks/google-play", GooglePlayDeveloperNotificationAsync)
            .WithTags("Billing Webhooks")
            .AllowAnonymous()
            .RequireRateLimiting("webhooks")
            .WithMetadata(new RequestSizeLimitAttribute(MaxEconomyWebhookRequestBodyBytes));

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateEconomyResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        var endpoint = context.HttpContext.GetEndpoint();
        if (endpoint?.Metadata.GetMetadata<IAllowAnonymous>() is null)
        {
            context.HttpContext.Response.Headers.CacheControl = "no-store";
            context.HttpContext.Response.Headers.Pragma = "no-cache";
            context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";
        }

        return await next(context);
    }
}
