using System.Text.Encodings.Web;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private static async Task<Results<Ok<PublicGalleryShareResponse>, ProblemHttpResult>> GetSharedGenerationAsync(
        HttpContext context,
        string token,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var result = await generationService.GetPublicShareAsync(token, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<ContentHttpResult, ProblemHttpResult>> GetSharedGenerationPageAsync(
        HttpContext context,
        string token,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var result = await generationService.GetPublicShareAsync(token, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplySharedGenerationPageSecurityHeaders(context);
        return TypedResults.Content(
            BuildSharedGenerationHtml(result.Value),
            "text/html; charset=utf-8");
    }

    private static void ApplySharedGenerationPageSecurityHeaders(HttpContext context)
    {
        context.Response.Headers.CacheControl = "no-store";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers["Referrer-Policy"] = "no-referrer";
        context.Response.Headers.XContentTypeOptions = "nosniff";
        context.Response.Headers["Content-Security-Policy"] =
            "default-src 'none'; script-src 'none'; connect-src 'none'; form-action 'none'; object-src 'none'; frame-src 'none'; img-src 'self' https: data:; media-src 'self' https:; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'";
    }

    private static void ApplyPrivateMediaJsonHeaders(HttpContext context)
    {
        context.Response.Headers.CacheControl = "no-store";
        context.Response.Headers.Pragma = "no-cache";
        context.Response.Headers.XContentTypeOptions = "nosniff";
    }

    private static string BuildSharedGenerationHtml(PublicGalleryShareResponse share)
    {
        var title = HtmlEncoder.Default.Encode(
            string.IsNullOrWhiteSpace(share.TemplateTitle)
                ? "PetMagic generation"
                : share.TemplateTitle);
        var state = HtmlEncoder.Default.Encode(share.MediaState);
        var message = share.MediaState == GalleryMediaState.resultReady.ToString()
            ? "Shared PetMagic result"
            : "This shared result is not available right now.";
        var encodedMessage = HtmlEncoder.Default.Encode(message);
        var mediaUrl = HtmlEncoder.Default.Encode(share.SignedMediaUrl ?? string.Empty);
        var mediaMarkup = share.MediaState != GalleryMediaState.resultReady.ToString()
            ? $"<p>{encodedMessage}</p><p>State: {state}</p>"
            : share.MediaType.Equals("video", StringComparison.OrdinalIgnoreCase)
                ? $"<video controls playsinline src=\"{mediaUrl}\"></video>"
                : $"<img src=\"{mediaUrl}\" alt=\"{title}\" />";

        return $$"""
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>{{title}}</title>
              <style>
                body { margin: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #101214; color: #f8fafc; }
                main { min-height: 100vh; display: grid; place-items: center; padding: 24px; box-sizing: border-box; }
                section { width: min(720px, 100%); }
                img, video { display: block; width: 100%; height: auto; border-radius: 8px; background: #181b1f; }
                h1 { margin: 0 0 16px; font-size: 24px; line-height: 1.2; font-weight: 700; }
                p { color: #cbd5e1; font-size: 16px; line-height: 1.5; }
              </style>
            </head>
            <body>
              <main>
                <section>
                  <h1>{{title}}</h1>
                  {{mediaMarkup}}
                </section>
              </main>
            </body>
            </html>
            """;
    }

    private static async Task<Results<Ok<TemplateGenerationResponse>, ProblemHttpResult>> GetGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var isPremium = await HasPremiumEntitlementAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<RemoveGenerationWatermarkResponse>, ProblemHttpResult>> RemoveWatermarkAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] RemoveWatermarkRequest? request,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var isPremium = await HasPremiumEntitlementAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.RemoveWatermarkAsync(
            new RemoveGenerationWatermarkCommand(
                userId.Value,
                generationId,
                request?.PaymentMethod ?? "credit",
                isPremium),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<GalleryDownloadResponse>, ProblemHttpResult>> DownloadGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var isPremium = await HasPremiumEntitlementAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetDownloadAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<GalleryShareResponse>, ProblemHttpResult>> ShareGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var isPremium = await HasPremiumEntitlementAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.GetShareAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<GalleryPageResponse>, ProblemHttpResult>> ListGenerationsAsync(
        HttpContext context,
        [FromQuery] string? status,
        [FromQuery] int? skip,
        [FromQuery] int? take,
        [FromQuery] string? cursor,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var filterProblem = ValidateGenerationFilters(status);
        if (filterProblem is not null)
        {
            return filterProblem;
        }

        var isPremium = await HasPremiumEntitlementAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.ListPageAsync(
            userId!.Value,
            new TemplateGenerationHistoryQuery(status, skip, take, cursor),
            isPremium,
            cancellationToken);

        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        ApplyPrivateMediaJsonHeaders(context);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<TemplateGenerationUnreadCountResponse>, ProblemHttpResult>> GetUnreadCountAsync(
        HttpContext context,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await generationService.GetUnreadCountAsync(userId!.Value, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> MarkReadAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var isPremium = await HasPremiumTemplateAccessAsync(context, userId!.Value, cancellationToken);
        var result = await generationService.MarkReadAsync(userId.Value, generationId, isPremium, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<Ok<CancelQueuedGenerationResponse>, ProblemHttpResult>> CancelQueuedGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await generationService.CancelQueuedAsync(userId!.Value, generationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static ProblemHttpResult? ValidateGenerationFilters(string? status)
    {
        if (string.IsNullOrWhiteSpace(status))
        {
            return null;
        }

        var normalized = status.Trim();
        if (string.Equals(normalized, "all", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return IsOneOf(
                normalized,
                "active",
                "pending",
                "running",
                "completed",
                "failed",
                "cancelled",
                "retrying",
                "preprocessing",
                "generating",
                "finalizing")
            ? null
            : InvalidGenerationFilterProblem();
    }

    private static ProblemHttpResult InvalidGenerationFilterProblem()
    {
        return TypedResults.Problem(
            title: "templates.invalid_status",
            statusCode: StatusCodes.Status400BadRequest,
            extensions: BuildClientGenerationProblemExtensions("templates.invalid_status"));
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> DeleteGenerationAsync(
        HttpContext context,
        Guid generationId,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await generationService.DeleteAsync(userId!.Value, generationId, cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RecordFeedbackAsync(
        HttpContext context,
        Guid generationId,
        [FromBody] RecordTemplateGenerationFeedbackRequest request,
        [FromServices] ITemplateGenerationService generationService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await generationService.RecordFeedbackAsync(
            new RecordTemplateGenerationFeedbackCommand(
                userId!.Value,
                generationId,
                request.Rating,
                request.SelectedReasons ?? [],
                request.Comment,
                request.InputPhotoQualityScore),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.NoContent();
    }

    private sealed record RecordTemplateGenerationFeedbackRequest(int Rating, string[]? SelectedReasons, string? Comment, double? InputPhotoQualityScore);

    private sealed record RemoveWatermarkRequest(string? PaymentMethod);
}
