using System.Globalization;
using System.Security.Claims;

using FluentValidation;

using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private const double PreviewMinDurationSeconds = 0.5;
    private const double PreviewMaxDurationSeconds = 18.0;
    private const int RecentGenerationsDefaultTake = 25;
    private const int RecentGenerationsMaxTake = 250;
    private const int MaxAdminTemplateSmallJsonRequestBodyBytes = 16 * 1024;
    private const int MaxAdminTemplateDefinitionRequestBodyBytes = 128 * 1024;
    private const long MaxAdminGenerationTestUploadRequestBodyBytes = 26L * 1024 * 1024;
    private const long MaxAdminTemplateMediaUploadRequestBodyBytes = 110L * 1024 * 1024;

    public static IEndpointRouteBuilder MapAdminTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/templates")
            .WithTags("Admin.Templates")
            .AddEndpointFilter(ApplyPrivateAdminTemplateResponseHeadersAsync)
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        group.MapGet("/", ListAsync);
        group.MapGet("/analytics", GetAnalyticsOverviewAsync);
        group.MapGet("/moderation", GetModerationQueueAsync);
        group.MapPost("/moderation/{eventId:guid}/claim", ClaimModerationItemAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        group.MapPost("/moderation/{eventId:guid}/release", ReleaseModerationItemAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        group.MapPost("/moderation/{eventId:guid}/handoff", HandoffModerationItemAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/moderation/{eventId:guid}/decision", DecideModerationItemAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        group.MapGet("/generations/metrics", GetGenerationDashboardMetricsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/generation-control", GetGenerationControlAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/generation-control", UpdateGenerationControlAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generation-control/provider/refresh", RefreshGenerationProviderAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generation-control/alerts/{alertId:guid}/acknowledge", AcknowledgeGenerationAlertAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generation-control/render/scale", RequestGenerationWorkerScaleAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/generation-control/render/operations/{operationId:guid}", GetGenerationWorkerScaleOperationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generation-control/render/operations/{operationId:guid}/cancel", CancelGenerationWorkerScaleOperationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/generations", ListGenerationsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/generations/{generationId:guid}", GetGenerationAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/monetization/watermark", GetWatermarkSettingsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/monetization/watermark", UpdateWatermarkSettingsAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/grant-clean-download", GrantCleanDownloadAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/cancel", CancelGenerationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/retry", RetryGenerationAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/retry-refund", RetryGenerationRefundAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/resolve-legacy-gamification", ResolveLegacyGamificationDeliveryAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapGet("/{templateId:guid}", GetAsync);
        group.MapGet("/{templateId:guid}/statistics", GetStatisticsAsync);
        group.MapGet("/{templateId:guid}/statistics/trends", GetTrendAsync);
        group.MapGet("/{templateId:guid}/statistics/recent", GetRecentAsync);
        group.MapGet("/{templateId:guid}/tests", GetTestHistoryAsync);
        group.MapGet("/{templateId:guid}/statistics/failures", GetFailureBreakdownAsync);
        group.MapGet("/{templateId:guid}/statistics/events", GetEventAnalyticsAsync);
        group.MapGet("/{templateId:guid}/statistics/feedback", GetFeedbackAsync);
        group.MapPost("/{templateId:guid}/test", StartAdminTestAsync)
            .RequireAuthorization("AdminOnly")
            .DisableAntiforgery()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminGenerationTestUploadRequestBodyBytes));
        group.MapGet("/tests/{generationId:guid}", GetAdminTestAsync);
        group.MapPost("/image", CreateImageAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateDefinitionRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/image/{templateId:guid}", UpdateImageAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateDefinitionRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/video", CreateVideoAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateDefinitionRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/video/{templateId:guid}", UpdateVideoAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateDefinitionRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPut("/{templateId:guid}/status", ChangeStatusAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/{templateId:guid}", DeleteAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes))
            .RequireAuthorization("AdminOnly");
        group.MapPost("/media/upload", UploadMediaAsync)
            .RequireAuthorization("AdminOnly")
            .DisableAntiforgery()
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateMediaUploadRequestBodyBytes));

        var templateOfTheDayGroup = endpoints.MapGroup("/api/admin/template-of-the-day")
            .WithTags("Admin.TemplateOfTheDay")
            .AddEndpointFilter(ApplyPrivateAdminTemplateResponseHeadersAsync)
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin");

        endpoints.MapGet("/api/admin/template-of-the-day", ListTemplateOfTheDayScheduleAsync)
            .WithTags("Admin.TemplateOfTheDay")
            .AddEndpointFilter(ApplyPrivateAdminTemplateResponseHeadersAsync)
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin");
        endpoints.MapPost("/api/admin/template-of-the-day", CreateTemplateOfTheDayAsync)
            .WithTags("Admin.TemplateOfTheDay")
            .AddEndpointFilter(ApplyPrivateAdminTemplateResponseHeadersAsync)
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin")
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        templateOfTheDayGroup.MapGet("/current", GetCurrentTemplateOfTheDayAsync);
        templateOfTheDayGroup.MapGet("/schedule", ListTemplateOfTheDayScheduleAsync);
        templateOfTheDayGroup.MapGet("/settings", GetTemplateOfTheDaySettingsAsync);
        templateOfTheDayGroup.MapPut("/settings", UpdateTemplateOfTheDaySettingsAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        templateOfTheDayGroup.MapPut("/{id:guid}", UpdateTemplateOfTheDayAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        templateOfTheDayGroup.MapDelete("/{id:guid}", DeleteTemplateOfTheDayAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        templateOfTheDayGroup.MapPost("/auto-pick", AutoPickTemplateOfTheDayAsync)
            .WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));

        return endpoints;
    }

    private static async ValueTask<object?> ApplyPrivateAdminTemplateResponseHeadersAsync(
        EndpointFilterInvocationContext context,
        EndpointFilterDelegate next)
    {
        context.HttpContext.Response.Headers.CacheControl = "no-store";
        context.HttpContext.Response.Headers.Pragma = "no-cache";
        context.HttpContext.Response.Headers.XContentTypeOptions = "nosniff";

        return await next(context);
    }
}
