using System.Globalization;
using System.Security.Claims;
using System.Text.Json;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static class PublicTemplateEndpoints
{
    private const string PublicCatalogCacheControl = "public, max-age=10";
    private const string PublicCategoriesCacheControl = "public, max-age=60";
    private const int MaxAnalyticsRequestBodyBytes = 16 * 1024;
    private const int MaxAnalyticsSourceLength = 64;
    private const int MaxAnalyticsFeedbackMessageLength = 2000;
    private const int MaxAnalyticsMetadataEntries = 12;
    private const int MaxAnalyticsMetadataKeyLength = 64;
    private const int MaxAnalyticsMetadataValueLength = 160;
    private static readonly JsonSerializerOptions PublicJsonOptions = new(JsonSerializerDefaults.Web);
    // Do not add templates.generation.status_changed to this anonymous public
    // SSE allowlist. Generation status events carry user-specific generation
    // and media data; gallery realtime needs an authenticated per-user stream
    // or a payload that contains no user media data.
    private static readonly HashSet<string> AllowedPublicRealtimeTopics =
    [
        TemplateFeedRealtimeTopics.TemplatesFeedInvalidated
    ];
    private static readonly HashSet<string> AllowedPublicAnalyticsEventTypes =
    [
        TemplateAnalyticsEventTypes.View,
        TemplateAnalyticsEventTypes.VideoView,
        TemplateAnalyticsEventTypes.Complaint,
        TemplateAnalyticsEventTypes.Feedback,
        TemplateAnalyticsEventTypes.FeedbackPromptViewed,
        TemplateAnalyticsEventTypes.FeedbackRatingSelected,
        TemplateAnalyticsEventTypes.FeedbackSubmitFailed,
        TemplateAnalyticsEventTypes.FeedbackReportClicked,
        TemplateAnalyticsEventTypes.UseAsInputClicked,
        TemplateAnalyticsEventTypes.TemplateOfTheDayViewed,
        TemplateAnalyticsEventTypes.TemplateOfTheDayClicked,
        TemplateAnalyticsEventTypes.TemplateOfTheDayOpened,
        TemplateAnalyticsEventTypes.TemplateSelected,
        TemplateAnalyticsEventTypes.GenerationStarted,
        TemplateAnalyticsEventTypes.GenerationCompleted,
        TemplateAnalyticsEventTypes.GenerationFailed,
        TemplateAnalyticsEventTypes.RemoveClicked,
        TemplateAnalyticsEventTypes.PaywallViewed,
        TemplateAnalyticsEventTypes.CreateVideoClicked,
        TemplateAnalyticsEventTypes.CompareClicked,
        TemplateAnalyticsEventTypes.CompareViewed,
        TemplateAnalyticsEventTypes.CompareSliderMoved,
        TemplateAnalyticsEventTypes.CompareShareClicked,
        TemplateAnalyticsEventTypes.CompareClosed,
        TemplateAnalyticsEventTypes.GenerateSimilarClicked,
        TemplateAnalyticsEventTypes.GenerateSimilarConfirmed
    ];

    public static IEndpointRouteBuilder MapPublicTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/templates")
            .WithTags("Templates")
            .RequireRateLimiting("templates");

        group.MapGet("", ListAsync).AllowAnonymous();
        group.MapGet("/catalog-version", GetCatalogVersionAsync).AllowAnonymous();
        group.MapGet("/changes", GetCatalogChangesAsync).AllowAnonymous();
        group.MapGet("/categories", ListCategoriesAsync).AllowAnonymous();
        group.MapGet("/feed", ListFeedAsync).AllowAnonymous();
        group.MapGet("/random", GetRandomTemplateAsync).AllowAnonymous();
        group.MapGet("/template-of-the-day", GetTemplateOfTheDayAsync).AllowAnonymous();
        group.MapGet("/{templateId:guid}", GetAsync).AllowAnonymous();

        endpoints.MapGet("/api/templates/events", StreamEventsAsync)
            .WithTags("Templates")
            .AllowAnonymous()
            .RequireRateLimiting("templates-events");

        endpoints.MapPost("/api/templates/{templateId:guid}/analytics/events", RecordAnalyticsEventAsync)
            .WithTags("Templates")
            .AllowAnonymous()
            .RequireRateLimiting("templates-analytics")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAnalyticsRequestBodyBytes));

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
        [FromQuery] bool? includeQa,
        [FromQuery] string? locale,
        [FromServices] IHostEnvironment environment,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        if (!TryParseOptionalTemplateType(type, out var templateType))
        {
            return InvalidTemplateTypeProblem();
        }

        var result = await service.ListPublicCatalogAsync(
            new PublicTemplatesCatalogQuery(
                page,
                pageSize,
                templateType,
                category,
                ResolveLocalePreference(httpContext, locale),
                tags,
                premiumOnly,
                CanIncludeQaTemplates(httpContext, environment, includeQa)),
            cancellationToken);
        SetPublicCatalogCacheHeaders(httpContext);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplatesCatalogVersionResponse>, ProblemHttpResult>> GetCatalogVersionAsync(
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        SetPublicCatalogCacheHeaders(httpContext);

        var result = await service.GetPublicCatalogVersionAsync(cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

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
            return ToPublicValidationProblem("templates.invalid_since_version");
        }

        SetPublicCatalogCacheHeaders(httpContext);

        var result = await service.GetPublicCatalogChangesAsync(sinceVersion.Value, ResolveLocalePreference(httpContext, locale), cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task StreamEventsAsync(
        HttpContext httpContext,
        ITemplateFeedRealtimeService realtimeService,
        CancellationToken cancellationToken)
    {
        try
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

            var waitToReadTask = subscription.WaitToReadAsync(cancellationToken).AsTask();
            while (!cancellationToken.IsCancellationRequested)
            {
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
                    if (!IsPublicRealtimeTopic(realtimeEvent.Topic))
                    {
                        continue;
                    }

                    await WriteEventAsync(httpContext, realtimeEvent, cancellationToken);
                }

                waitToReadTask = subscription.WaitToReadAsync(cancellationToken).AsTask();
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested || httpContext.RequestAborted.IsCancellationRequested)
        {
        }
        catch (System.IO.IOException) when (cancellationToken.IsCancellationRequested || httpContext.RequestAborted.IsCancellationRequested)
        {
        }
    }

    private static async Task<Results<Ok<IReadOnlyList<PublicTemplateCategoryResponse>>, ProblemHttpResult>> ListCategoriesAsync(
        HttpContext httpContext,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.ListPublicCategoriesAsync(cancellationToken);
        httpContext.Response.Headers.CacheControl = PublicCategoriesCacheControl;
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

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
        [FromQuery] bool? includeQa,
        [FromQuery] string? locale,
        [FromServices] IHostEnvironment environment,
        [FromServices] ITemplatesService service,
        [FromServices] ILoggerFactory loggerFactory,
        CancellationToken cancellationToken)
    {
        if (!TryParseOptionalTemplateType(type, out var templateType))
        {
            return ToPublicValidationProblem("templates.invalid_type");
        }

        if (IsInvalidPublicFeedCursor(cursor))
        {
            return ToPublicValidationProblem("templates.invalid_cursor");
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
                ResolveLocalePreference(httpContext, locale),
                CanIncludeQaTemplates(httpContext, environment, includeQa)),
            cancellationToken);

        SetPublicCatalogCacheHeaders(httpContext);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

        var payloadBytes = JsonSerializer.SerializeToUtf8Bytes(result.Value, PublicJsonOptions).LongLength;
        loggerFactory
            .CreateLogger("PetMagic.Templates.PublicFeed")
            .LogInformation(
                "Public template feed payload generated. Bytes={PayloadBytes} Items={ItemCount} HasMore={HasMore}",
                payloadBytes,
                result.Value.Items.Count,
                result.Value.HasMore);

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicTemplateOfTheDayResponse>, ProblemHttpResult>> GetTemplateOfTheDayAsync(
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

        SetPublicCatalogCacheHeaders(httpContext);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<PublicRandomTemplateResponse>, ProblemHttpResult>> GetRandomTemplateAsync(
        HttpContext httpContext,
        [FromQuery] string? type,
        [FromQuery] string? category,
        [FromQuery] bool? includePremium,
        [FromQuery] string? access,
        [FromQuery] Guid? excludeTemplateId,
        [FromQuery] bool? includeQa,
        [FromQuery] string? locale,
        [FromServices] IHostEnvironment environment,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        if (!TryParseOptionalTemplateType(type, out var templateType))
        {
            return InvalidTemplateTypeProblem();
        }

        if (!TryParseOptionalRandomAccess(access, out var normalizedAccess))
        {
            return ToPublicValidationProblem("templates.invalid_access");
        }

        var result = await service.GetPublicRandomTemplateAsync(
            new PublicRandomTemplateQuery(
                templateType,
                category,
                includePremium ?? true,
                ResolveLocalePreference(httpContext, locale),
                normalizedAccess,
                excludeTemplateId,
                CanIncludeQaTemplates(httpContext, environment, includeQa)),
            cancellationToken);

        SetPublicCatalogCacheHeaders(httpContext);
        if (result.IsFailure)
        {
            return ToPublicCatalogProblem(result.Error.Code);
        }

        return TypedResults.Ok(result.Value);
    }

    private static bool IsInvalidPublicFeedCursor(string? rawCursor)
    {
        if (string.IsNullOrWhiteSpace(rawCursor))
        {
            return false;
        }

        var parts = rawCursor.Trim().Split(':', 3, StringSplitOptions.TrimEntries);
        if (parts.Length is not (2 or 3)
            || !long.TryParse(parts[0], NumberStyles.Integer, CultureInfo.InvariantCulture, out var ticks)
            || ticks < DateTime.MinValue.Ticks
            || ticks > DateTime.MaxValue.Ticks
            || !Guid.TryParseExact(parts[^1], "N", out _))
        {
            return true;
        }

        return parts.Length == 3
            && (!long.TryParse(parts[1], NumberStyles.Integer, CultureInfo.InvariantCulture, out var version)
                || version < 0);
    }

    private static bool CanIncludeQaTemplates(HttpContext httpContext, IHostEnvironment environment, bool? includeQa)
    {
        return includeQa == true
            && !environment.IsProduction()
            && (httpContext.User.IsInRole("Admin") || httpContext.User.IsInRole("Moderator"));
    }

    private static void SetPublicCatalogCacheHeaders(HttpContext httpContext)
    {
        httpContext.Response.Headers.CacheControl = PublicCatalogCacheControl;
    }

    private static bool TryParseOptionalTemplateType(string? rawType, out TemplateType? templateType)
    {
        templateType = null;
        if (string.IsNullOrWhiteSpace(rawType))
        {
            return true;
        }

        var normalizedType = rawType.Trim();
        if (string.Equals(normalizedType, "all", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        if (!Enum.GetNames<TemplateType>().Any(name =>
                string.Equals(name, normalizedType, StringComparison.OrdinalIgnoreCase)))
        {
            return false;
        }

        templateType = Enum.Parse<TemplateType>(normalizedType, ignoreCase: true);
        return true;
    }

    private static bool TryParseOptionalRandomAccess(string? rawAccess, out string? access)
    {
        access = null;
        if (string.IsNullOrWhiteSpace(rawAccess))
        {
            return true;
        }

        var normalizedAccess = rawAccess.Trim().ToLowerInvariant();
        if (normalizedAccess is "all" or "free" or "premium")
        {
            access = normalizedAccess;
            return true;
        }

        return false;
    }

    private static ProblemHttpResult InvalidTemplateTypeProblem()
    {
        return ToPublicValidationProblem("templates.invalid_type");
    }

    private static async Task<Results<Ok<TemplateDetailDto>, ProblemHttpResult>> GetAsync(
        Guid templateId,
        [FromQuery] string? source,
        [FromQuery] bool? includeQa,
        [FromQuery] string? locale,
        HttpContext httpContext,
        [FromServices] IHostEnvironment environment,
        [FromServices] ITemplatesService service,
        CancellationToken cancellationToken)
    {
        var result = await service.GetPublicAsync(
            templateId,
            ResolveLocalePreference(httpContext, locale),
            CanIncludeQaTemplates(httpContext, environment, includeQa),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToPublicTemplateProblem(result.Error.Code, StatusCodes.Status404NotFound);
        }

        await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                TemplateAnalyticsEventTypes.View,
                NormalizeAnalyticsText(source, MaxAnalyticsSourceLength),
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
        if (!TryResolvePublicEventType(request.EventType, out var eventType))
        {
            return ToPublicValidationProblem("templates.invalid_event_type");
        }

        var result = await service.RecordAnalyticsEventAsync(
            new RecordTemplateAnalyticsEventCommand(
                templateId,
                eventType,
                NormalizeAnalyticsText(request.Source, MaxAnalyticsSourceLength),
                ResolveAnalyticsDeviceClass(request.DeviceClass, httpContext),
                ResolveAnalyticsCountryCode(request.CountryCode, httpContext),
                ResolveUserId(httpContext),
                request.GenerationId,
                NormalizeAnalyticsText(request.FeedbackMessage, MaxAnalyticsFeedbackMessageLength),
                SerializeMetadata(request.Metadata)),
            cancellationToken);

        if (result.IsFailure)
        {
            return ToPublicTemplateProblem(result.Error.Code, StatusCodes.Status404NotFound);
        }

        return TypedResults.NoContent();
    }

    private static ProblemHttpResult ToPublicTemplateProblem(string errorCode, int statusCode)
    {
        return TypedResults.Problem(
            title: errorCode,
            detail: GetPublicTemplateProblemDetail(statusCode),
            statusCode: statusCode);
    }

    private static ProblemHttpResult ToPublicValidationProblem(string errorCode)
    {
        return TypedResults.Problem(
            title: errorCode,
            detail: GetPublicValidationProblemDetail(errorCode),
            statusCode: StatusCodes.Status400BadRequest);
    }

    private static ProblemHttpResult ToPublicCatalogProblem(string errorCode)
    {
        var statusCode = errorCode switch
        {
            "templates.not_found" => StatusCodes.Status404NotFound,
            "templates.category_not_found" => StatusCodes.Status404NotFound,
            "templates.template_of_the_day_template_unavailable" => StatusCodes.Status404NotFound,
            "templates.ai_provider_unavailable" => StatusCodes.Status503ServiceUnavailable,
            "templates.ai_provider_timed_out" => StatusCodes.Status503ServiceUnavailable,
            "templates.ai_provider_failed" => StatusCodes.Status503ServiceUnavailable,
            _ => StatusCodes.Status503ServiceUnavailable,
        };

        var detail = statusCode == StatusCodes.Status404NotFound
            ? "Template content was not found."
            : "Template catalog is temporarily unavailable.";

        return TypedResults.Problem(title: errorCode, detail: detail, statusCode: statusCode);
    }

    private static string GetPublicValidationProblemDetail(string errorCode)
    {
        return errorCode switch
        {
            "templates.invalid_since_version" => "Query parameter sinceVersion must be a non-negative integer.",
            "templates.invalid_type" => "Query parameter type must be Image, Video, or all.",
            "templates.invalid_cursor" => "Query parameter cursor must be the nextCursor value returned by a previous feed response.",
            "templates.invalid_access" => "Query parameter access must be all, free, or premium.",
            "templates.invalid_event_type" => "Request field eventType must be a supported analytics event name.",
            _ => "Template request is invalid.",
        };
    }

    private static string GetPublicTemplateProblemDetail(int statusCode)
    {
        return statusCode == StatusCodes.Status404NotFound
            ? "Template was not found."
            : "Template request could not be completed.";
    }

    private static bool TryResolvePublicEventType(string? eventType, out string normalizedEventType)
    {
        normalizedEventType = string.Empty;
        if (string.IsNullOrWhiteSpace(eventType))
        {
            return false;
        }

        var candidate = eventType.Trim().ToLowerInvariant();
        if (!AllowedPublicAnalyticsEventTypes.Contains(candidate))
        {
            return false;
        }

        normalizedEventType = candidate;
        return true;
    }

    private static string? NormalizeAnalyticsText(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= maxLength
            ? normalized
            : normalized[..maxLength];
    }

    private static string? SerializeMetadata(IReadOnlyDictionary<string, JsonElement>? metadata)
    {
        if (metadata is not { Count: > 0 })
        {
            return null;
        }

        var sanitized = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var (rawKey, rawValue) in metadata)
        {
            if (sanitized.Count >= MaxAnalyticsMetadataEntries)
            {
                break;
            }

            var key = NormalizeMetadataKey(rawKey);
            var value = NormalizeMetadataValue(rawValue);
            if (key is null || value is null)
            {
                continue;
            }

            sanitized[key] = value;
        }

        return sanitized.Count == 0 ? null : JsonSerializer.Serialize(sanitized);
    }

    private static string? NormalizeMetadataKey(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= MaxAnalyticsMetadataKeyLength
            ? normalized
            : normalized[..MaxAnalyticsMetadataKeyLength];
    }

    private static string? NormalizeMetadataValue(JsonElement value)
    {
        return value.ValueKind switch
        {
            JsonValueKind.Null => null,
            JsonValueKind.Undefined => null,
            JsonValueKind.String => NormalizeMetadataText(value.GetString()),
            JsonValueKind.True => "true",
            JsonValueKind.False => "false",
            JsonValueKind.Number => NormalizeMetadataText(value.GetRawText()),
            JsonValueKind.Array => NormalizeMetadataText(value.GetRawText()),
            JsonValueKind.Object => NormalizeMetadataText(value.GetRawText()),
            _ => NormalizeMetadataText(value.GetRawText())
        };
    }

    private static string? NormalizeMetadataText(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim();
        return normalized.Length <= MaxAnalyticsMetadataValueLength
            ? normalized
            : normalized[..MaxAnalyticsMetadataValueLength];
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

    private static string ResolveAnalyticsDeviceClass(string? requestedDeviceClass, HttpContext httpContext)
    {
        return NormalizeAnalyticsDeviceClass(requestedDeviceClass)
            ?? DetectDeviceClass(httpContext);
    }

    private static string? NormalizeAnalyticsDeviceClass(string? requestedDeviceClass)
    {
        if (string.IsNullOrWhiteSpace(requestedDeviceClass))
        {
            return null;
        }

        var normalized = requestedDeviceClass.Trim().ToLowerInvariant();
        if (normalized is "iphone" or "ipad" or "ios")
        {
            return "ios";
        }

        if (normalized.Contains("android", StringComparison.Ordinal))
        {
            return "android";
        }

        if (normalized is "web" or "browser" or "desktop")
        {
            return "web";
        }

        if (normalized.Contains("bot", StringComparison.Ordinal)
            || normalized.Contains("crawler", StringComparison.Ordinal)
            || normalized.Contains("spider", StringComparison.Ordinal))
        {
            return "bot";
        }

        if (normalized == "unknown")
        {
            return "unknown";
        }

        return null;
    }

    private static string ResolveCountryCode(HttpContext httpContext)
    {
        var value = FirstHeaderValue(httpContext, "CF-IPCountry")
            ?? FirstHeaderValue(httpContext, "X-Vercel-IP-Country")
            ?? FirstHeaderValue(httpContext, "X-Country-Code");

        return NormalizeAnalyticsCountryCode(value) ?? "unknown";
    }

    private static string ResolveAnalyticsCountryCode(string? requestedCountryCode, HttpContext httpContext)
    {
        return NormalizeAnalyticsCountryCode(requestedCountryCode)
            ?? ResolveCountryCode(httpContext);
    }

    private static string? NormalizeAnalyticsCountryCode(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var normalized = value.Trim().ToUpperInvariant();
        if (normalized == "UNKNOWN")
        {
            return "unknown";
        }

        return normalized.Length == 2 && normalized.All(char.IsLetterOrDigit)
            ? normalized
            : null;
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

    private static bool IsPublicRealtimeTopic(string topic)
    {
        return AllowedPublicRealtimeTopics.Contains(topic);
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
