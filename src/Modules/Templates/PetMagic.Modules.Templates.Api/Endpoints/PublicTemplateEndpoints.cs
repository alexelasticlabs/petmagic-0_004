using System.Globalization;
using System.Security.Claims;
using System.Text.Json;

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
        group.MapGet("/catalog-version", GetCatalogVersionAsync).AllowAnonymous();
        group.MapGet("/changes", GetCatalogChangesAsync).AllowAnonymous();
        group.MapGet("/categories", ListCategoriesAsync).AllowAnonymous();
        group.MapGet("/feed", ListFeedAsync).AllowAnonymous();
        group.MapGet("/template-of-the-day", GetTemplateOfTheDayAsync).AllowAnonymous();
        group.MapGet("/events", StreamEventsAsync).AllowAnonymous();
        group.MapGet("/{templateId:guid}", GetAsync).AllowAnonymous();
        group.MapPost("/{templateId:guid}/analytics/events", RecordAnalyticsEventAsync).AllowAnonymous();

        return endpoints;
    }

    private static async Task<IResult> ListAsync(
        HttpContext httpContext,
        [FromQuery] int? page,
        [FromQuery] int? pageSize,
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] string[]? tags,
        [FromQuery] bool? premiumOnly,
        [FromQuery] string? locale,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        if (!TryParseOptionalTemplateType(type, out var templateType))
        {
            return InvalidTemplateTypeProblem();
        }

        if (page.HasValue || pageSize.HasValue)
        {
            var pagedResult = await service.ListPublicCatalogAsync(
                new PublicTemplatesCatalogQuery(
                    page,
                    pageSize,
                    templateType,
                    category,
                    ResolveLocalePreference(httpContext, locale),
                    tags,
                    premiumOnly),
                cancellationToken);
            return TypedResults.Ok(pagedResult.Value);
        }

        var result = await service.ListPublicAsync(templateType, category, tags, premiumOnly, ResolveLocalePreference(httpContext, locale), cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<PublicTemplatesCatalogVersionResponse>> GetCatalogVersionAsync(
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        httpContext.Response.Headers.CacheControl = "public, max-age=10";

        var result = await service.GetPublicCatalogVersionAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplatesCatalogChangesResponse>, ProblemHttpResult>> GetCatalogChangesAsync(
        [FromQuery] long? sinceVersion,
        [FromQuery] string? locale,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        if (!sinceVersion.HasValue || sinceVersion.Value < 0)
        {
            return TypedResults.Problem(
                title: "templates.invalid_since_version",
                detail: "Query parameter sinceVersion must be a non-negative integer.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        httpContext.Response.Headers.CacheControl = "public, max-age=10";

        var result = await service.GetPublicCatalogChangesAsync(sinceVersion.Value, ResolveLocalePreference(httpContext, locale), cancellationToken);
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
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPublicCategoriesAsync(cancellationToken);
        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplatesFeedResponse>, ProblemHttpResult>> ListFeedAsync(
        HttpContext httpContext,
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] string[]? tags,
        [FromQuery] bool? premiumOnly,
        [FromQuery] string? search,
        [FromQuery] int? take,
        [FromQuery] string? cursor,
        [FromQuery] string? locale,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        if (!TryParseOptionalTemplateType(type, out var templateType))
        {
            return TypedResults.Problem(
                title: "templates.invalid_type",
                detail: "Query parameter type must be Image or Video.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        if (IsInvalidPublicFeedCursor(cursor))
        {
            return TypedResults.Problem(
                title: "templates.invalid_cursor",
                detail: "Query parameter cursor must be the nextCursor value returned by a previous feed response.",
                statusCode: StatusCodes.Status400BadRequest);
        }

        var result = await service.ListPublicFeedAsync(
            new PublicTemplatesFeedQuery(
                templateType,
                category,
                tags ?? [],
                premiumOnly,
                search,
                take,
                cursor,
                ResolveLocalePreference(httpContext, locale)),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Ok<PublicTemplateOfTheDayResponse>> GetTemplateOfTheDayAsync(
        HttpContext httpContext,
        [FromQuery] DateOnly? date,
        [FromQuery] string? locale,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPublicTemplateOfTheDayAsync(
            date,
            ResolveLocalePreference(httpContext, locale),
            cancellationToken);

        return TypedResults.Ok(result.Value);
    }

    private static bool IsInvalidPublicFeedCursor(string? rawCursor)
    {
        if (string.IsNullOrWhiteSpace(rawCursor))
        {
            return false;
        }

        var parts = rawCursor.Trim().Split(':', 2, StringSplitOptions.TrimEntries);
        return parts.Length != 2
            || !long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks)
            || ticks < DateTime.MinValue.Ticks
            || ticks > DateTime.MaxValue.Ticks
            || !Guid.TryParseExact(parts[1], "N", out _);
    }

    private static bool TryParseOptionalTemplateType(string? rawType, out TemplateType? templateType)
    {
        templateType = null;
        if (string.IsNullOrWhiteSpace(rawType))
        {
            return true;
        }

        var normalizedType = rawType.Trim();
        if (!Enum.GetNames<TemplateType>().Any(name =>
                string.Equals(name, normalizedType, StringComparison.OrdinalIgnoreCase)))
        {
            return false;
        }

        templateType = Enum.Parse<TemplateType>(normalizedType, ignoreCase: true);
        return true;
    }

    private static ProblemHttpResult InvalidTemplateTypeProblem()
    {
        return TypedResults.Problem(
            title: "templates.invalid_type",
            detail: "Query parameter type must be Image or Video.",
            statusCode: StatusCodes.Status400BadRequest);
    }

    private static async Task<Results<Ok<PublicTemplateResponse>, ProblemHttpResult>> GetAsync(
        Guid templateId,
        [FromQuery] string? source,
        [FromQuery] string? locale,
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPublicAsync(templateId, ResolveLocalePreference(httpContext, locale), cancellationToken);
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
        [FromServices] ITemplatesService service,
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
                request.FeedbackMessage,
                SerializeMetadata(request.Metadata)),
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
            TemplateAnalyticsEventTypes.UseAsInputClicked => TemplateAnalyticsEventTypes.UseAsInputClicked,
            TemplateAnalyticsEventTypes.TemplateOfTheDayViewed => TemplateAnalyticsEventTypes.TemplateOfTheDayViewed,
            TemplateAnalyticsEventTypes.TemplateOfTheDayClicked => TemplateAnalyticsEventTypes.TemplateOfTheDayClicked,
            TemplateAnalyticsEventTypes.TemplateOfTheDayOpened => TemplateAnalyticsEventTypes.TemplateOfTheDayOpened,
            TemplateAnalyticsEventTypes.TemplateSelected => TemplateAnalyticsEventTypes.TemplateSelected,
            TemplateAnalyticsEventTypes.GenerationStarted => TemplateAnalyticsEventTypes.GenerationStarted,
            TemplateAnalyticsEventTypes.GenerationCompleted => TemplateAnalyticsEventTypes.GenerationCompleted,
            TemplateAnalyticsEventTypes.GenerationFailed => TemplateAnalyticsEventTypes.GenerationFailed,
            TemplateAnalyticsEventTypes.RemoveClicked => TemplateAnalyticsEventTypes.RemoveClicked,
            TemplateAnalyticsEventTypes.PaywallViewed => TemplateAnalyticsEventTypes.PaywallViewed,
            TemplateAnalyticsEventTypes.CreateVideoClicked => TemplateAnalyticsEventTypes.CreateVideoClicked,
            TemplateAnalyticsEventTypes.CompareClicked => TemplateAnalyticsEventTypes.CompareClicked,
            TemplateAnalyticsEventTypes.CompareViewed => TemplateAnalyticsEventTypes.CompareViewed,
            TemplateAnalyticsEventTypes.CompareSliderMoved => TemplateAnalyticsEventTypes.CompareSliderMoved,
            TemplateAnalyticsEventTypes.CompareShareClicked => TemplateAnalyticsEventTypes.CompareShareClicked,
            TemplateAnalyticsEventTypes.CompareClosed => TemplateAnalyticsEventTypes.CompareClosed,
            _ => TemplateAnalyticsEventTypes.View
        };
    }

    private static string? SerializeMetadata(IReadOnlyDictionary<string, JsonElement>? metadata)
    {
        return metadata is { Count: > 0 } ? JsonSerializer.Serialize(metadata) : null;
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

    private static string? ResolveLocalePreference(HttpContext httpContext, string? explicitLocale)
    {
        if (!string.IsNullOrWhiteSpace(explicitLocale))
        {
            return NormalizeLocale(explicitLocale);
        }

        var acceptLanguage = httpContext.Request.Headers.AcceptLanguage.ToString();
        if (string.IsNullOrWhiteSpace(acceptLanguage))
        {
            return null;
        }

        var first = acceptLanguage.Split(',', 2, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).FirstOrDefault();
        return NormalizeLocale(first);
    }

    private static string? NormalizeLocale(string? locale)
    {
        if (string.IsNullOrWhiteSpace(locale))
        {
            return null;
        }

        var normalized = locale.Trim().ToLowerInvariant();
        var separatorIndex = normalized.IndexOf('-');
        if (separatorIndex > 0)
        {
            normalized = normalized[..separatorIndex];
        }

        return normalized.Length == 2 ? normalized : null;
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

    private sealed record RecordTemplateAnalyticsEventRequest(
        string? EventType,
        string? Source,
        string? DeviceClass,
        string? CountryCode,
        Guid? GenerationId,
        string? FeedbackMessage,
        IReadOnlyDictionary<string, JsonElement>? Metadata);
}
