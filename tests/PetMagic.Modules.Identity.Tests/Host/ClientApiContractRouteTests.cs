using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.RateLimiting;

using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http.Metadata;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

using PetMagic.Modules.Economy.Api;
using PetMagic.Modules.Economy.Application.Abstractions;
using PetMagic.Modules.Identity.Api;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.SupportChat.Api;
using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Application.Abstractions;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class ClientApiContractRouteTests
{
    public static TheoryData<string, string, string> MobileClientRoutes => new()
    {
        { "POST", "/api/auth/register", "mobile profile registration" },
        { "POST", "/api/auth/login", "mobile login" },
        { "POST", "/api/auth/refresh", "mobile session refresh" },
        { "POST", "/api/auth/logout", "mobile logout" },
        { "GET", "/api/auth/me", "mobile current user" },
        { "PUT", "/api/auth/me/profile", "mobile profile update" },
        { "PUT", "/api/auth/me/avatar", "mobile avatar update" },
        { "DELETE", "/api/auth/me/avatar", "mobile avatar removal" },
        { "GET", "/api/auth/me/linked-accounts", "mobile linked accounts" },
        { "POST", "/api/auth/me/linked-accounts/{provider}/prepare", "mobile account link prepare" },
        { "DELETE", "/api/auth/me/linked-accounts/{provider}", "mobile account unlink" },
        { "POST", "/api/auth/request-password-reset", "mobile password reset request" },
        { "POST", "/api/auth/reset-password", "mobile password reset" },
        { "POST", "/api/auth/resend-email-verification-code", "mobile email verification resend" },
        { "POST", "/api/auth/verify-email-code", "mobile email verification" },
        { "GET", "/api/auth/external/google/mobile-config", "mobile google config" },
        { "POST", "/api/auth/external/google/native", "mobile native google auth" },
        { "POST", "/api/auth/apple", "mobile apple auth" },
        { "GET", "/api/legal/current", "mobile current legal documents" },
        { "POST", "/api/legal/accept", "mobile legal acceptance" },
        { "GET", "/api/templates", "mobile public catalog" },
        { "GET", "/api/templates/feed", "mobile template feed" },
        { "GET", "/api/templates/random", "mobile random template" },
        { "GET", "/api/templates/categories", "mobile template categories" },
        { "GET", "/api/templates/template-of-the-day", "mobile template of the day" },
        { "GET", "/api/templates/catalog-version", "mobile catalog version" },
        { "GET", "/api/templates/changes", "mobile catalog delta sync" },
        { "GET", "/api/templates/{templateId:guid}", "mobile template detail" },
        { "POST", "/api/templates/{templateId:guid}/generations", "mobile start generation" },
        { "GET", "/api/templates/generations", "mobile generation history" },
        { "GET", "/api/templates/generations/unread-count", "mobile unread generation count" },
        { "GET", "/api/templates/generations/{generationId:guid}", "mobile generation detail" },
        { "DELETE", "/api/templates/generations/{generationId:guid}", "mobile delete generation" },
        { "POST", "/api/templates/generations/{generationId:guid}/feedback", "mobile generation feedback" },
        { "POST", "/api/templates/generations/{generationId:guid}/mark-read", "mobile mark generation read" },
        { "POST", "/api/templates/generations/{generationId:guid}/remove-watermark", "mobile remove watermark" },
        { "GET", "/api/templates/generations/{generationId:guid}/download", "mobile generation download" },
        { "POST", "/api/templates/generations/{generationId:guid}/share", "mobile generation share" },
        { "PUT", "/api/templates/notifications/push-token", "mobile template push token register" },
        { "DELETE", "/api/templates/notifications/push-token", "mobile template push token unregister" },
        { "GET", "/api/templates/generation-results/{resultId:guid}/compatible-templates", "mobile compatible templates" },
        { "POST", "/api/templates/generations/from-pet", "mobile generation from pet" },
        { "POST", "/api/templates/generations/from-result", "mobile generation from result" },
        { "POST", "/api/templates/generations/{generationId:guid}/generate-similar", "mobile similar generation" },
        { "GET", "/api/pets", "mobile pet list" },
        { "POST", "/api/pets", "mobile create pet" },
        { "PUT", "/api/pets/{petId:guid}", "mobile update pet" },
        { "DELETE", "/api/pets/{petId:guid}", "mobile delete pet" },
        { "POST", "/api/pets/{petId:guid}/photos", "mobile upload pet photo" },
        { "GET", "/api/pets/{petId:guid}/photos", "mobile pet photos" },
        { "POST", "/api/pets/{petId:guid}/photos/{photoId:guid}/set-avatar", "mobile pet avatar" },
        { "POST", "/api/pets/{petId:guid}/photos/{photoId:guid}/favorite", "mobile pet photo favorite" },
        { "DELETE", "/api/pets/{petId:guid}/photos/{photoId:guid}", "mobile delete pet photo" },
        { "GET", "/api/pets/{petId:guid}/generations", "mobile pet generations" },
        { "POST", "/api/feedback", "mobile feedback" },
        { "GET", "/api/economy/wallet", "mobile wallet" },
        { "GET", "/api/economy/wallet/ledger", "mobile wallet ledger" },
        { "GET", "/api/economy/rewards", "mobile rewards" },
        { "GET", "/api/economy/packs", "mobile token packs" },
        { "GET", "/api/economy/wallet/checkout-config", "mobile checkout config" },
        { "POST", "/api/economy/wallet/claim-ad", "mobile ad reward" },
        { "POST", "/api/economy/wallet/redeem", "mobile redeem code" },
        { "POST", "/api/economy/referrals/activate", "mobile referral activation" },
        { "GET", "/api/economy/purchases", "mobile purchases" },
        { "POST", "/api/economy/purchases/create", "mobile create purchase" },
        { "GET", "/api/economy/purchases/{orderId:guid}", "mobile purchase detail" },
        { "POST", "/api/economy/purchases/{orderId:guid}/verify-store", "mobile store purchase verify" },
        { "POST", "/api/economy/purchases/{orderId:guid}/verify-stripe", "mobile stripe purchase verify" },
        { "GET", "/api/economy/premium/plans", "mobile premium plans" },
        { "GET", "/api/economy/subscriptions/paywall-config", "mobile paywall config" },
        { "GET", "/api/economy/me/subscription", "mobile current subscription" },
        { "POST", "/api/economy/premium/checkout", "mobile premium checkout" },
        { "POST", "/api/economy/premium/manage", "mobile billing portal" },
        { "POST", "/api/economy/premium/cancel", "mobile premium cancel" },
        { "POST", "/api/economy/premium/store/verify", "mobile premium store verify" },
        { "POST", "/api/economy/premium/verify-stripe", "mobile premium stripe verify" },
        { "PUT", "/api/economy/notifications/push-token", "mobile economy push token register" },
        { "DELETE", "/api/economy/notifications/push-token", "mobile economy push token unregister" },
        { "POST", "/api/support/conversation/open", "mobile support open conversation" },
        { "GET", "/api/support/conversation", "mobile support conversation" },
        { "POST", "/api/support/conversation/{conversationId:guid}/messages", "mobile support message" },
        { "POST", "/api/support/conversation/{conversationId:guid}/attachments", "mobile support attachment" },
        { "POST", "/api/support/conversation/{conversationId:guid}/messages/attachments", "mobile support attachments" },
        { "POST", "/api/support/conversation/{conversationId:guid}/messages/{messageId:guid}/attachment/retry", "mobile support attachment retry" },
        { "POST", "/api/support/conversation/{conversationId:guid}/read", "mobile support mark read" },
        { "POST", "/api/support/conversation/{conversationId:guid}/resolve", "mobile support resolve" },
        { "POST", "/api/support/conversation/{conversationId:guid}/reopen", "mobile support reopen" },
        { "POST", "/api/support/conversation/{conversationId:guid}/close", "mobile support close" },
        { "POST", "/api/support/conversation/{conversationId:guid}/feedback", "mobile support feedback" },
        { "PUT", "/api/support/notifications/push-token", "mobile support push token register" },
        { "DELETE", "/api/support/notifications/push-token", "mobile support push token unregister" },
    };

    public static TheoryData<string, string, string> AdminClientRoutes => new()
    {
        { "POST", "/api/auth/login", "admin login" },
        { "POST", "/api/auth/refresh", "admin session refresh" },
        { "POST", "/api/auth/logout", "admin logout" },
        { "GET", "/api/legal/current", "admin legal current" },
        { "POST", "/api/legal/accept", "admin legal accept" },
        { "GET", "/api/admin/users", "admin users list" },
        { "GET", "/api/admin/users/dashboard/metrics", "admin users metrics" },
        { "GET", "/api/admin/users/{userId:guid}", "admin user detail" },
        { "GET", "/api/admin/users/{userId:guid}/analytics", "admin user analytics" },
        { "POST", "/api/admin/users/{userId:guid}/wallet", "admin wallet adjustment" },
        { "PUT", "/api/admin/users/{userId:guid}/role", "admin role assign" },
        { "DELETE", "/api/admin/users/{userId:guid}/role", "admin role revoke" },
        { "PUT", "/api/admin/users/{userId:guid}/premium", "admin premium status" },
        { "PUT", "/api/admin/users/{userId:guid}/active", "admin active status" },
        { "DELETE", "/api/admin/users/{userId:guid}", "admin delete user" },
        { "GET", "/api/admin/users/{userId:guid}/pets", "admin user pets" },
        { "GET", "/api/admin/users/{userId:guid}/pets/{petId:guid}/photos", "admin user pet photos" },
        { "GET", "/api/admin/users/{userId:guid}/pets/{petId:guid}/generations", "admin user pet generations" },
        { "POST", "/api/admin/users/{userId:guid}/pets/{petId:guid}/status", "admin user pet status" },
        { "POST", "/api/admin/users/{userId:guid}/pets/{petId:guid}/photos/{photoId:guid}/status", "admin user pet photo status" },
        { "GET", "/api/admin/economy/dashboard/metrics", "admin economy metrics" },
        { "GET", "/api/admin/economy/ledger", "admin economy ledger" },
        { "GET", "/api/admin/economy/purchases", "admin economy purchases" },
        { "POST", "/api/admin/economy/purchases/{orderId:guid}/refund", "admin economy refund" },
        { "GET", "/api/admin/economy/subscriptions", "admin economy subscriptions" },
        { "GET", "/api/admin/economy/subscription-events", "admin economy subscription events" },
        { "GET", "/api/admin/economy/packs", "admin economy packs" },
        { "PUT", "/api/admin/economy/packs/{packId:guid}", "admin economy pack update" },
        { "GET", "/api/admin/economy/subscription-plans", "admin economy subscription plans" },
        { "PUT", "/api/admin/economy/subscription-plans/{planId}", "admin economy plan update" },
        { "GET", "/api/admin/economy/payment-provider-configs", "admin payment configs" },
        { "POST", "/api/admin/economy/payment-provider-configs", "admin payment config create" },
        { "PUT", "/api/admin/economy/payment-provider-configs/{configurationId:guid}", "admin payment config update" },
        { "DELETE", "/api/admin/economy/payment-provider-configs/{configurationId:guid}", "admin payment config delete" },
        { "POST", "/api/admin/economy/payment-provider-configs/{configurationId:guid}/clone", "admin payment config clone" },
        { "POST", "/api/admin/economy/payment-provider-configs/test-match", "admin payment config test" },
        { "GET", "/api/admin/economy/users/{userId:guid}/subscription-summary", "admin economy user subscription summary" },
        { "PUT", "/api/admin/economy/users/{userId:guid}/premium/revoke", "admin revoke premium" },
        { "GET", "/api/admin/economy/redeem-codes/metrics", "admin promo metrics" },
        { "GET", "/api/admin/economy/redeem-codes", "admin promo list" },
        { "GET", "/api/admin/economy/redeem-codes/{redeemCodeId:guid}/activations", "admin promo activations" },
        { "POST", "/api/admin/economy/redeem-codes", "admin promo create" },
        { "PUT", "/api/admin/economy/redeem-codes/{redeemCodeId:guid}", "admin promo update" },
        { "GET", "/api/admin/templates", "admin templates list" },
        { "GET", "/api/admin/templates/analytics", "admin templates analytics" },
        { "GET", "/api/admin/templates/categories", "admin template categories" },
        { "POST", "/api/admin/templates/categories", "admin template category create" },
        { "PUT", "/api/admin/templates/categories/{categoryId:guid}", "admin template category update" },
        { "PUT", "/api/admin/templates/categories/{categoryId:guid}/archive", "admin template category archive" },
        { "DELETE", "/api/admin/templates/categories/{categoryId:guid}", "admin template category delete" },
        { "GET", "/api/admin/templates/generations", "admin template generations" },
        { "GET", "/api/admin/templates/generations/metrics", "admin generation metrics" },
        { "POST", "/api/admin/templates/generations/{generationId:guid}/grant-clean-download", "admin grant clean download" },
        { "GET", "/api/admin/templates/moderation", "admin moderation queue" },
        { "POST", "/api/admin/templates/moderation/{eventId:guid}/decision", "admin moderation decision" },
        { "GET", "/api/admin/templates/monetization/watermark", "admin watermark settings" },
        { "PUT", "/api/admin/templates/monetization/watermark", "admin watermark update" },
        { "GET", "/api/admin/templates/{templateId:guid}", "admin template detail" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics", "admin template statistics" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics/trends", "admin template trends" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics/recent", "admin template recent generations" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics/failures", "admin template failures" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics/events", "admin template events" },
        { "GET", "/api/admin/templates/{templateId:guid}/statistics/feedback", "admin template feedback" },
        { "GET", "/api/admin/templates/{templateId:guid}/tests", "admin template test history" },
        { "POST", "/api/admin/templates/{templateId:guid}/test", "admin template test start" },
        { "GET", "/api/admin/templates/tests/{generationId:guid}", "admin template test detail" },
        { "POST", "/api/admin/templates/image", "admin image template create" },
        { "PUT", "/api/admin/templates/image/{templateId:guid}", "admin image template update" },
        { "POST", "/api/admin/templates/video", "admin video template create" },
        { "PUT", "/api/admin/templates/video/{templateId:guid}", "admin video template update" },
        { "PUT", "/api/admin/templates/{templateId:guid}/status", "admin template status" },
        { "DELETE", "/api/admin/templates/{templateId:guid}", "admin template delete" },
        { "POST", "/api/admin/templates/media/upload", "admin template media upload" },
        { "GET", "/api/admin/templates/{templateId:guid}/feedback-summary", "admin template feedback summary" },
        { "GET", "/api/admin/template-of-the-day", "admin template of the day list" },
        { "POST", "/api/admin/template-of-the-day", "admin template of the day create" },
        { "GET", "/api/admin/template-of-the-day/current", "admin template of the day current" },
        { "GET", "/api/admin/template-of-the-day/schedule", "admin template of the day schedule" },
        { "GET", "/api/admin/template-of-the-day/settings", "admin template of the day settings" },
        { "PUT", "/api/admin/template-of-the-day/settings", "admin template of the day settings update" },
        { "PUT", "/api/admin/template-of-the-day/{id:guid}", "admin template of the day update" },
        { "DELETE", "/api/admin/template-of-the-day/{id:guid}", "admin template of the day delete" },
        { "POST", "/api/admin/template-of-the-day/auto-pick", "admin template of the day auto pick" },
        { "GET", "/api/admin/feedback", "admin feedback list" },
        { "GET", "/api/admin/feedback/{feedbackId:guid}", "admin feedback detail" },
        { "PUT", "/api/admin/feedback/{feedbackId:guid}", "admin feedback update" },
        { "POST", "/api/admin/feedback/{feedbackId:guid}/refund", "admin feedback refund" },
        { "GET", "/api/admin/support/tickets", "admin support inbox" },
        { "GET", "/api/admin/support/tickets/metrics", "admin support metrics" },
        { "GET", "/api/admin/support/tickets/{conversationId:guid}", "admin support ticket detail" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/messages", "admin support message" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/attachments", "admin support attachment" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/messages/attachments", "admin support attachments" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/read", "admin support read" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/assign-to-me", "admin support assign to me" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/unassign", "admin support unassign" },
        { "PUT", "/api/admin/support/tickets/{conversationId:guid}/metadata", "admin support metadata" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/close", "admin support close" },
        { "POST", "/api/admin/support/tickets/{conversationId:guid}/reopen", "admin support reopen" },
        { "GET", "/api/admin/support/templates", "admin support templates" },
        { "POST", "/api/admin/support/templates", "admin support template create" },
        { "PUT", "/api/admin/support/templates/{templateId:guid}", "admin support template update" },
        { "DELETE", "/api/admin/support/templates/{templateId:guid}", "admin support template delete" },
    };

    [Fact]
    public async Task MobileClientRoutes_ShouldExistInBackendApi()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        var missingRoutes = MobileClientRoutes
            .Cast<object[]>()
            .Select(route => new
            {
                Method = (string)route[0],
                RoutePattern = (string)route[1],
                Scenario = (string)route[2],
            })
            .Where(route => !app.HasRoute(route.Method, route.RoutePattern))
            .Select(route => $"{route.Method} {route.RoutePattern} ({route.Scenario})")
            .ToArray();

        Assert.Empty(missingRoutes);
    }

    [Fact]
    public async Task AdminClientRoutes_ShouldExistInBackendApi()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        var missingRoutes = AdminClientRoutes
            .Cast<object[]>()
            .Select(route => new
            {
                Method = (string)route[0],
                RoutePattern = (string)route[1],
                Scenario = (string)route[2],
            })
            .Where(route => !app.HasRoute(route.Method, route.RoutePattern))
            .Select(route => $"{route.Method} {route.RoutePattern} ({route.Scenario})")
            .ToArray();

        Assert.Empty(missingRoutes);
    }

    [Fact]
    public async Task AdminClientRoutes_ShouldRequireAuthorization()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        var unprotectedRoutes = AdminClientRoutes
            .Cast<object[]>()
            .Select(route => new
            {
                Method = (string)route[0],
                RoutePattern = (string)route[1],
                Scenario = (string)route[2],
            })
            .Where(route => route.RoutePattern.StartsWith("/api/admin/", StringComparison.Ordinal))
            .Select(route => new
            {
                Route = route,
                Endpoint = app.GetRouteEndpoint(route.Method, route.RoutePattern),
            })
            .Where(route => route.Endpoint is null
                || route.Endpoint.Metadata.GetMetadata<IAllowAnonymous>() is not null
                || route.Endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>().Count == 0)
            .Select(route => $"{route.Route.Method} {route.Route.RoutePattern} ({route.Route.Scenario})")
            .ToArray();

        Assert.Empty(unprotectedRoutes);
    }

    [Fact]
    public async Task ApiRoutes_ShouldDeclareExplicitAccessPolicy()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutAccessPolicy());
    }

    [Fact]
    public async Task ApiRoutes_ShouldDeclareRateLimitPolicy()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        Assert.Empty(app.GetApiRoutesWithoutRateLimitPolicy());
    }

    [Fact]
    public async Task AdminApiRoutes_ShouldRequireAdminOrModeratorPolicy()
    {
        await using var app = await ClientApiContractTestApplication.CreateAsync();

        Assert.Empty(app.GetAdminRoutesWithoutRolePolicy());
    }

    private sealed class ClientApiContractTestApplication : IAsyncDisposable
    {
        private readonly WebApplication app;

        private ClientApiContractTestApplication(WebApplication app)
        {
            this.app = app;
        }

        public static async Task<ClientApiContractTestApplication> CreateAsync()
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                EnvironmentName = Environments.Development,
                ApplicationName = typeof(ClientApiContractRouteTests).Assembly.FullName,
            });

            builder.WebHost.UseTestServer();
            builder.Services.AddProblemDetails();
            builder.Services.AddMemoryCache();
            builder.Services.AddRateLimiter(options =>
            {
                options.AddPolicy("auth", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-register", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-password-reset", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("auth-external", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("economy", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("templates", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("generation-create", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("generation-status", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("support-chat", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("admin", _ => RateLimitPartition.GetNoLimiter("tests"));
                options.AddPolicy("webhooks", _ => RateLimitPartition.GetNoLimiter("tests"));
            });

            builder.Services.AddAuthentication(TestAuthHandler.SchemeName)
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("ModeratorOrAdmin", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin", "Moderator");
                });
                options.AddPolicy("AdminOnly", policy =>
                {
                    policy.RequireAuthenticatedUser();
                    policy.RequireRole("Admin");
                });
            });

            builder.Services.AddScoped<IIdentityService>(_ =>
                throw new NotSupportedException("IIdentityService should not be resolved during route contract tests."));
            builder.Services.AddScoped<IGoogleIdentityTokenVerifier>(_ =>
                throw new NotSupportedException("IGoogleIdentityTokenVerifier should not be resolved during route contract tests."));
            builder.Services.AddScoped<ILegalDocumentsCatalog>(_ =>
                throw new NotSupportedException("ILegalDocumentsCatalog should not be resolved during route contract tests."));
            builder.Services.AddScoped<IEconomyService>(_ =>
                throw new NotSupportedException("IEconomyService should not be resolved during route contract tests."));
            builder.Services.AddScoped<IStoreWebhookSecurityValidator>(_ =>
                throw new NotSupportedException("IStoreWebhookSecurityValidator should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplatesService>(_ =>
                throw new NotSupportedException("ITemplatesService should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplateFeedRealtimeService>(_ =>
                throw new NotSupportedException("ITemplateFeedRealtimeService should not be resolved during route contract tests."));
            builder.Services.AddScoped<IMediaStorage>(_ =>
                throw new NotSupportedException("IMediaStorage should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplateMediaUploadPolicy>(_ =>
                throw new NotSupportedException("ITemplateMediaUploadPolicy should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplateGenerationService>(_ =>
                throw new NotSupportedException("ITemplateGenerationService should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplatePushTokenService>(_ =>
                throw new NotSupportedException("ITemplatePushTokenService should not be resolved during route contract tests."));
            builder.Services.AddScoped<ITemplateMediaLifecycleService>(_ =>
                throw new NotSupportedException("ITemplateMediaLifecycleService should not be resolved during route contract tests."));
            builder.Services.AddScoped<IMediaMetadataReader>(_ =>
                throw new NotSupportedException("IMediaMetadataReader should not be resolved during route contract tests."));
            builder.Services.AddScoped<ISupportChatService>(_ =>
                throw new NotSupportedException("ISupportChatService should not be resolved during route contract tests."));
            builder.Services.AddScoped<ISupportAttachmentStorage>(_ =>
                throw new NotSupportedException("ISupportAttachmentStorage should not be resolved during route contract tests."));
            builder.Services.AddScoped<ISupportReplyTemplateCatalogService>(_ =>
                throw new NotSupportedException("ISupportReplyTemplateCatalogService should not be resolved during route contract tests."));

            builder.Services
                .AddIdentityApiModule()
                .AddEconomyApiModule()
                .AddTemplatesApiModule()
                .AddSupportChatApiModule();

            var app = builder.Build();
            app.UseRateLimiter();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapIdentityApiModule();
            app.MapEconomyApiModule();
            app.MapTemplatesApiModule();
            app.MapSupportChatApiModule();

            await app.StartAsync();
            return new ClientApiContractTestApplication(app);
        }

        public bool HasRoute(string method, string routePattern)
        {
            return GetRouteEndpoint(method, routePattern) is not null;
        }

        public RouteEndpoint? GetRouteEndpoint(string method, string routePattern)
        {
            var normalizedRoutePattern = NormalizeRoutePattern(routePattern);

            return app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .FirstOrDefault(endpoint =>
                    string.Equals(
                        NormalizeRoutePattern(endpoint.RoutePattern.RawText),
                        normalizedRoutePattern,
                        StringComparison.Ordinal)
                    && endpoint.Metadata
                        .GetRequiredMetadata<IHttpMethodMetadata>()
                        .HttpMethods
                        .Contains(method, StringComparer.OrdinalIgnoreCase));
        }

        public string[] GetApiRoutesWithoutAccessPolicy()
        {
            return ApiRouteEndpoints()
                .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null)
                .Where(endpoint => endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>().Count == 0)
                .Select(FormatEndpoint)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }

        public string[] GetApiRoutesWithoutRateLimitPolicy()
        {
            return ApiRouteEndpoints()
                .Where(endpoint => endpoint.Metadata.GetMetadata<EnableRateLimitingAttribute>() is null)
                .Select(FormatEndpoint)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }

        public string[] GetAdminRoutesWithoutRolePolicy()
        {
            return ApiRouteEndpoints()
                .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/admin/", StringComparison.Ordinal) == true)
                .Where(endpoint => endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null)
                .Where(endpoint => !endpoint.Metadata
                    .GetOrderedMetadata<IAuthorizeData>()
                    .Any(metadata => metadata.Policy is "AdminOnly" or "ModeratorOrAdmin"))
                .Select(FormatEndpoint)
                .Order(StringComparer.Ordinal)
                .ToArray();
        }

        private IEnumerable<RouteEndpoint> ApiRouteEndpoints()
        {
            return app.Services
                .GetRequiredService<EndpointDataSource>()
                .Endpoints
                .OfType<RouteEndpoint>()
                .Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/api/", StringComparison.Ordinal) == true);
        }

        private static string FormatEndpoint(RouteEndpoint endpoint)
        {
            var methods = endpoint.Metadata
                .GetMetadata<IHttpMethodMetadata>()
                ?.HttpMethods
                .Order(StringComparer.OrdinalIgnoreCase)
                .ToArray() ?? [];

            return $"{string.Join(",", methods)} {endpoint.RoutePattern.RawText}";
        }

        private static string NormalizeRoutePattern(string? routePattern)
        {
            if (string.IsNullOrWhiteSpace(routePattern) || routePattern == "/")
            {
                return routePattern ?? string.Empty;
            }

            return routePattern.TrimEnd('/');
        }

        public async ValueTask DisposeAsync()
        {
            await app.StopAsync();
            await app.DisposeAsync();
        }
    }

    private sealed class TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public const string SchemeName = "Test";

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var claims = new[]
            {
                new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
                new Claim(ClaimTypes.Role, "Admin")
            };

            var identity = new ClaimsIdentity(claims, SchemeName);
            var principal = new ClaimsPrincipal(identity);
            var ticket = new AuthenticationTicket(principal, SchemeName);

            return Task.FromResult(AuthenticateResult.Success(ticket));
        }
    }
}
