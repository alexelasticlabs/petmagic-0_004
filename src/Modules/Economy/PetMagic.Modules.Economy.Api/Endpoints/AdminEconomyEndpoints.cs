using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private static readonly string[] PurchaseStatusFilters = ["pending", "succeeded", "failed", "refunded"];

    private static readonly string[] PaymentProviderFilters = ["stripe", "app_store", "google_play"];

    private static readonly string[] SubscriptionStatusFilters =
    [
        "active",
        "trialing",
        "graceperiod",
        "grace_period",
        "grace-period",
        "pastdue",
        "past_due",
        "past-due",
        "canceled",
        "expired",
        "refunded",
        "revoked",
        "pending"
    ];

    private static readonly string[] SubscriptionEventStatusFilters =
    [
        "active",
        "trialing",
        "graceperiod",
        "grace_period",
        "grace-period",
        "pastdue",
        "past_due",
        "past-due",
        "canceled",
        "expired",
        "processed",
        "failed",
        "pending"
    ];

    private static readonly string[] RedeemCodeStatusFilters =
    [
        "all",
        "draft",
        "scheduled",
        "active",
        "paused",
        "exhausted",
        "expired",
        "archived"
    ];

    private static readonly string[] RedeemCodeRewardKindFilters = ["all", "spark"];

    private static readonly string[] RedeemCodeSortModes = ["updated", "usage", "reward", "code", "expiry"];

    public static IEndpointRouteBuilder MapAdminEconomyEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/economy")
            .WithTags("Admin.Economy")
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        group.MapGet("/ledger", GetWalletLedgerAsync);
        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/purchases", GetPurchasesAsync);
        group.MapPost("/purchases/{orderId:guid}/refund", RefundPurchaseAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/users/{userId:guid}/subscription-summary", GetUserSubscriptionSummaryAsync);
        group.MapPut("/users/{userId:guid}/premium/revoke", AdminRevokePremiumSubscriptionAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/subscriptions", GetSubscriptionsAsync);
        group.MapGet("/packs", ListPacksAsync);
        group.MapGet("/subscription-plans", ListSubscriptionPlansAsync);
        group.MapGet("/payment-provider-configs", ListPaymentProviderConfigurationsAsync);
        group.MapGet("/subscription-events", GetSubscriptionEventsAsync);
        group.MapPost("/payment-provider-configs", CreatePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/{configurationId:guid}/clone", ClonePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/payment-provider-configs/{configurationId:guid}", DeletePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/test-match", TestPaymentProviderConfigurationMatchAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/packs/{packId:guid}", UpdatePackAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/subscription-plans/{planId}", UpdateSubscriptionPlanAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/payment-provider-configs/{configurationId:guid}", UpdatePaymentProviderConfigurationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/redeem-codes/metrics", GetRedeemCodeMetricsAsync);
        group.MapGet("/redeem-codes", ListRedeemCodesAsync);
        group.MapGet("/redeem-codes/{redeemCodeId:guid}/activations", ListRedeemCodeActivationsAsync);
        group.MapPost("/redeem-codes", CreateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/redeem-codes/{redeemCodeId:guid}", UpdateRedeemCodeAsync)
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }
}
