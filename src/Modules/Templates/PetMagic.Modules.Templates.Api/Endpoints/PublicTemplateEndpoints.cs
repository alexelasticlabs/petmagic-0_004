using System.Security.Claims;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class PublicTemplateEndpoints
{
    public static IEndpointRouteBuilder MapPublicTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Templates")
            .RequireRateLimiting("templates");

        group.MapGet("/", ListAsync).AllowAnonymous();
        group.MapGet("/{templateId:guid}", GetAsync).AllowAnonymous();
        group.MapPost("/{templateId:guid}/analytics/events", RecordAnalyticsEventAsync).AllowAnonymous();

        return endpoints;
    }

    private static async Task<Ok<IReadOnlyList<PublicTemplateListItemResponse>>> ListAsync(
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] string[]? tags,
        [FromQuery] bool? premiumOnly,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        TemplateType? templateType = Enum.TryParse<TemplateType>(type, true, out var parsedType)
            ? parsedType
            : null;
        var result = await service.ListPublicAsync(templateType, category, tags, premiumOnly, cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplateResponse>, ProblemHttpResult>> GetAsync(
        Guid templateId,
        [FromQuery] string? source,
        HttpContext httpContext,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPublicAsync(templateId, cancellationToken);
        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                "view",
                source,
                DetectDeviceClass(httpContext),
                ResolveCountryCode(httpContext),
                ResolveUserId(httpContext),
                null,
                null),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<NoContent, ProblemHttpResult>> RecordAnalyticsEventAsync(
        Guid templateId,
        [FromBody] RecordTemplateAnalyticsEventRequest request,
        HttpContext httpContext,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                ResolveEventType(request.EventType),
                request.Source,
                string.IsNullOrWhiteSpace(request.DeviceClass) ? DetectDeviceClass(httpContext) : request.DeviceClass,
                string.IsNullOrWhiteSpace(request.CountryCode) ? ResolveCountryCode(httpContext) : request.CountryCode,
                ResolveUserId(httpContext),
                request.GenerationId,
                request.FeedbackMessage),
            cancellationToken);

        if (result.IsFailure)
        {
            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);
        }

        return TypedResults.NoContent();
    }

    private static string ResolveEventType(string? eventType)
    {
        return eventType?.Trim().ToLowerInvariant() switch
        {
            "video_view" => "video_view",
            "complaint" => "complaint",
            "feedback" => "feedback",
            _ => "view"
        };
    }

    private static string DetectDeviceClass(HttpContext httpContext)
    {
        var userAgent = httpContext.Request.Headers.UserAgent.ToString().ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(userAgent))
        {
            return "unknown";
        }

        if (userAgent.Contains("iphone") || userAgent.Contains("ipad") || userAgent.Contains("ios"))
        {
            return "ios";
        }

        if (userAgent.Contains("android"))
        {
            return "android";
        }

        if (userAgent.Contains("bot") || userAgent.Contains("crawler") || userAgent.Contains("spider"))
        {
            return "bot";
        }

        return "web";
    }

    private static string ResolveCountryCode(HttpContext httpContext)
    {
        var value = FirstHeaderValue(httpContext, "CF-IPCountry")
            ?? FirstHeaderValue(httpContext, "X-Vercel-IP-Country")
            ?? FirstHeaderValue(httpContext, "X-Country-Code");

        return string.IsNullOrWhiteSpace(value) ? "unknown" : value;
    }

    private static string? FirstHeaderValue(HttpContext httpContext, string headerName)
    {
        return httpContext.Request.Headers.TryGetValue(headerName, out var values) ? values.FirstOrDefault() : null;
    }

    private static Guid? ResolveUserId(HttpContext httpContext)
    {
        var raw = httpContext.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? httpContext.User.FindFirstValue("sub");

        return Guid.TryParse(raw, out var userId) ? userId : null;
    }

    private sealed record RecordTemplateAnalyticsEventRequest(string? EventType, string? Source, string? DeviceClass, string? CountryCode, Guid? GenerationId, string? FeedbackMessage);
}
