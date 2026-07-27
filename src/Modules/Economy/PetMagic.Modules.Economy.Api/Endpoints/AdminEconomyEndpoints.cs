using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

namespace PetMagic.Modules.Economy.Api.Endpoints;

public static partial class AdminEconomyEndpoints
{
    private const int MaxAdminEconomyMutationRequestBodyBytes = 32 * 1024;
    private const int MaxAdminEconomyProviderConfigurationRequestBodyBytes = 64 * 1024;

    private static readonly string[] PurchaseStatusFilters =
    [
        "pending",
        "succeeded",
        "failed",
        "refund_pending",
        "refund_review",
        "refunded"
    ];

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

    private static readonly string[] IncidentStatusFilters =
    [
        "open",
        "resolved",
        "suppressed"
    ];

    private static readonly string[] IncidentCategoryFilters =
    [
        "pending",
        "failed",
        "disputed",
        "refund_pending",
        "settlement_failed",
        "webhook_failed",
        "reconciliation_required",
        "manual_review_required",
        "resolved"
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
            .AddEndpointFilter(ApplyPrivateAdminEconomyResponseHeadersAsync)
            .RequireRateLimiting("admin")
            .RequireAuthorization("AdminOnly");

        group.MapGet("/ledger", GetWalletLedgerAsync);
        group.MapGet("/dashboard/metrics", GetDashboardMetricsAsync);
        group.MapGet("/purchases", GetPurchasesAsync);
        group.MapGet("/purchases/{orderId:guid}", GetPurchaseAsync);
        group.MapPost("/purchases/{orderId:guid}/refund", RefundPurchaseAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/users/{userId:guid}/subscription-summary", GetUserSubscriptionSummaryAsync);
        group.MapPut("/users/{userId:guid}/premium/revoke", AdminRevokePremiumSubscriptionAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/subscriptions", GetSubscriptionsAsync);
        group.MapGet("/packs", ListPacksAsync);
        group.MapGet("/subscription-plans", ListSubscriptionPlansAsync);
        group.MapGet("/payment-provider-configs", ListPaymentProviderConfigurationsAsync);
        group.MapGet("/subscription-events", GetSubscriptionEventsAsync);
        group.MapGet("/incidents", GetIncidentsAsync);
        group.MapGet("/incidents/{incidentId:guid}", GetIncidentAsync);
        group.MapPost("/reconciliation/run", RunReconciliationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/incidents/{incidentId:guid}/resolve", ResolveIncidentAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/incidents/{incidentId:guid}/reopen", ReopenIncidentAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/incidents/{incidentId:guid}/actions", ApplyIncidentActionAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs", CreatePaymentProviderConfigurationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyProviderConfigurationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/{configurationId:guid}/clone", ClonePaymentProviderConfigurationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyProviderConfigurationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/payment-provider-configs/{configurationId:guid}", DeletePaymentProviderConfigurationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/payment-provider-configs/test-match", TestPaymentProviderConfigurationMatchAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyProviderConfigurationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/packs/{packId:guid}", UpdatePackAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/subscription-plans/{planId}", UpdateSubscriptionPlanAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/payment-provider-configs/{configurationId:guid}", UpdatePaymentProviderConfigurationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyProviderConfigurationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/redeem-codes/metrics", GetRedeemCodeMetricsAsync);
        group.MapGet("/redeem-codes", ListRedeemCodesAsync);
        group.MapGet("/redeem-codes/{redeemCodeId:guid}/activations", ListRedeemCodeActivationsAsync);
        group.MapPost("/redeem-codes", CreateRedeemCodeAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/redeem-codes/{redeemCodeId:guid}", UpdateRedeemCodeAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))
            .RequireAuthorization("AdminOnly");

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateAdminEconomyResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }
}
