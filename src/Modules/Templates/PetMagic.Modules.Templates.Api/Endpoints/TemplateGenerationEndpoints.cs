using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = "Authentication failed.";
    private const string PremiumRequiredCode = "templates.premium_required";
    private const string PremiumRequiredMessage = "Premium subscription is required for this template.";
    private const int FreeActiveGenerationLimit = 1;
    private const int PremiumActiveGenerationLimit = 3;
    private const int PrivilegedActiveGenerationLimit = 10;
    private const int MaxIdempotencyKeyLength = 256;

    public static IEndpointRouteBuilder MapTemplateGenerationEndpoints(this IEndpointRouteBuilder endpoints)
    {
        endpoints.MapPost("/api/templates/provider/fal/webhook", HandleFalWebhookAsync)
            .AllowAnonymous()
            .RequireRateLimiting("templates")
            .DisableAntiforgery();

        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Template Generations")
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

        group.MapPost("/{templateId:guid}/generations", StartGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-create")
            .DisableAntiforgery();

        group.MapGet("/generation-results/{resultId:guid}/compatible-templates", GetCompatibleTemplatesAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/from-result", StartGenerationFromResultAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-create");

        group.MapPost("/generations/{generationId:guid}/generate-similar", GenerateSimilarAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-create");

        group.MapGet("/generations", ListGenerationsAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapGet("/generations/unread-count", GetUnreadCountAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapGet("/generations/{generationId:guid}", GetGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("generation-status");

        group.MapPost("/generations/{generationId:guid}/remove-watermark", RemoveWatermarkAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapGet("/generations/{generationId:guid}/download", DownloadGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/share", ShareGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/mark-read", MarkReadAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/cancel", CancelQueuedGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapDelete("/generations/{generationId:guid}", DeleteGenerationAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/generations/{generationId:guid}/feedback", RecordFeedbackAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapPost("/qa/generation-fixtures", CreateQaGenerationFixturesAsync)
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("templates");

        group.MapDelete("/qa/generation-fixtures", CleanupQaGenerationFixturesAsync)
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("templates");

        group.MapPut("/notifications/push-token", RegisterPushTokenAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        group.MapDelete("/notifications/push-token", UnregisterPushTokenAsync)
            .RequireAuthorization()
            .RequireRateLimiting("templates");

        return endpoints;
    }
}
