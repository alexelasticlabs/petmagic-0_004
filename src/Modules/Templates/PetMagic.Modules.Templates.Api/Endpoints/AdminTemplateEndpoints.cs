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

    public static IEndpointRouteBuilder MapAdminTemplateEndpoints(this IEndpointRouteBuilder endpoints)
    {
        var group = endpoints.MapGroup("/api/admin/templates")
            .WithTags("Admin.Templates")
            .RequireAuthorization("ModeratorOrAdmin")
            .RequireRateLimiting("admin");

        group.MapGet("/", ListAsync);
        group.MapGet("/analytics", GetAnalyticsOverviewAsync);
        group.MapGet("/moderation", GetModerationQueueAsync);
        group.MapPost("/moderation/{eventId:guid}/decision", DecideModerationItemAsync);
        group.MapGet("/generations/metrics", GetGenerationDashboardMetricsAsync);
        group.MapGet("/generations", ListGenerationsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapGet("/monetization/watermark", GetWatermarkSettingsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/monetization/watermark", UpdateWatermarkSettingsAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/generations/{generationId:guid}/grant-clean-download", GrantCleanDownloadAsync)
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
            .DisableAntiforgery();
        group.MapGet("/tests/{generationId:guid}", GetAdminTestAsync);
        group.MapPost("/image", CreateImageAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/image/{templateId:guid}", UpdateImageAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/video", CreateVideoAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/video/{templateId:guid}", UpdateVideoAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPut("/{templateId:guid}/status", ChangeStatusAsync)
            .RequireAuthorization("AdminOnly");
        group.MapDelete("/{templateId:guid}", DeleteAsync)
            .RequireAuthorization("AdminOnly");
        group.MapPost("/media/upload", UploadMediaAsync)
            .RequireAuthorization("AdminOnly")
            .DisableAntiforgery();

        var templateOfTheDayGroup = endpoints.MapGroup("/api/admin/template-of-the-day")
            .WithTags("Admin.TemplateOfTheDay")
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin");

        endpoints.MapGet("/api/admin/template-of-the-day", ListTemplateOfTheDayScheduleAsync)
            .WithTags("Admin.TemplateOfTheDay")
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin");
        endpoints.MapPost("/api/admin/template-of-the-day", CreateTemplateOfTheDayAsync)
            .WithTags("Admin.TemplateOfTheDay")
            .RequireAuthorization("AdminOnly")
            .RequireRateLimiting("admin");
        templateOfTheDayGroup.MapGet("/current", GetCurrentTemplateOfTheDayAsync);
        templateOfTheDayGroup.MapGet("/schedule", ListTemplateOfTheDayScheduleAsync);
        templateOfTheDayGroup.MapGet("/settings", GetTemplateOfTheDaySettingsAsync);
        templateOfTheDayGroup.MapPut("/settings", UpdateTemplateOfTheDaySettingsAsync);
        templateOfTheDayGroup.MapPut("/{id:guid}", UpdateTemplateOfTheDayAsync);
        templateOfTheDayGroup.MapDelete("/{id:guid}", DeleteTemplateOfTheDayAsync);
        templateOfTheDayGroup.MapPost("/auto-pick", AutoPickTemplateOfTheDayAsync);

        return endpoints;
    }
}
