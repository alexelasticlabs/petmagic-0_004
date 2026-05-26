using System.Security.Claims;
using System.Threading.Channels;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
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
        group.MapGet("/categories", ListCategoriesAsync).AllowAnonymous();
        group.MapGet("/feed", ListFeedAsync).AllowAnonymous();
        group.MapGet("/events", StreamEventsAsync).AllowAnonymous();
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

    private static async Task StreamEventsAsync(
        HttpContext httpContext,
        ITemplateFeedRealtimeService realtimeService,
        CancellationToken cancellationToken)
    {
        httpContext.Response.StatusCode = StatusCodes.Status200OK;
        httpContext.Response.ContentType = "text/event-stream";
        httpContext.Response.Headers.CacheControl = "no-cache, no-store";
        httpContext.Response.Headers.Connection = "keep-alive";
        httpContext.Response.Headers.Append("X-Accel-Buffering", "no");

        var subscription = realtimeService.Subscribe(cancellationToken);

        await httpContext.Response.StartAsync(cancellationToken);
        await httpContext.Response.WriteAsync(": connected\n\n", cancellationToken);
        await httpContext.Response.Body.FlushAsync(cancellationToken);

        while (!cancellationToken.IsCancellationRequested)
        {
            var waitToReadTask = subscription.WaitToReadAsync(cancellationToken).AsTask();
            var keepAliveTask = Task.Delay(TimeSpan.FromSeconds(15), cancellationToken);
            var completedTask = await Task.WhenAny(waitToReadTask, keepAliveTask);

            if (completedTask == keepAliveTask)
            {
                await httpContext.Response.WriteAsync(": keepalive\n\n", cancellationToken);
                await httpContext.Response.Body.FlushAsync(cancellationToken);
                continue;
            }

            if (!await waitToReadTask)
            {
                break;
            }

            while (subscription.TryRead(out var realtimeEvent))
            {
                await WriteEventAsync(httpContext, realtimeEvent, cancellationToken);
            }
        }
    }

    private static async Task<Ok<IReadOnlyList<PublicTemplateCategoryResponse>>> ListCategoriesAsync(
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPublicCategoriesAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<PublicTemplatesFeedResponse>> ListFeedAsync(
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] string[]? tags,
        [FromQuery] bool? premiumOnly,
        [FromQuery] string? search,
        [FromQuery] int? take,
        [FromQuery] string? cursor,
        ITemplatesService service,
        CancellationToken cancellationToken)
    {
        TemplateType? templateType = Enum.TryParse<TemplateType>(type, true, out var parsedType)
            ? parsedType
            : null;

        var result = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(
                templateType,
                category,
                tags ?? [],
                premiumOnly,
                search,
                take,
                cursor),
            cancellationToken);

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
                TemplateAnalyticsEventTypes.View,
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
            TemplateAnalyticsEventTypes.VideoView => TemplateAnalyticsEventTypes.VideoView,
            TemplateAnalyticsEventTypes.Complaint => TemplateAnalyticsEventTypes.Complaint,
            TemplateAnalyticsEventTypes.Feedback => TemplateAnalyticsEventTypes.Feedback,
            _ => TemplateAnalyticsEventTypes.View
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

    private static async Task WriteEventAsync(
        HttpContext httpContext,
        TemplateFeedRealtimeEvent realtimeEvent,
        CancellationToken cancellationToken)
    {
        await httpContext.Response.WriteAsync($"event: {realtimeEvent.Topic}\n", cancellationToken);
        await httpContext.Response.WriteAsync($"data: {realtimeEvent.Data}\n\n", cancellationToken);
        await httpContext.Response.Body.FlushAsync(cancellationToken);
    }

    private sealed record RecordTemplateAnalyticsEventRequest(string? EventType, string? Source, string? DeviceClass, string? CountryCode, Guid? GenerationId, string? FeedbackMessage);
}
