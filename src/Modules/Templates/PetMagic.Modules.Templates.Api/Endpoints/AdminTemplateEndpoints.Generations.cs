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

    private static async Task<Ok<AdminTemplateGenerationDashboardMetricsResponse>> GetGenerationDashboardMetricsAsync(

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminGenerationDashboardMetricsAsync(cancellationToken);

        return TypedResults.Ok(result.Value);

    }


    private static async Task<Ok<AdminModerationQueuePageResponse>> GetModerationQueueAsync(

        [FromQuery] string? status,

        [FromQuery] string? search,

        [FromQuery] int? skip,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminModerationQueueAsync(

            new AdminModerationQueueQuery(status, search, skip, take),

            cancellationToken);


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminModerationQueueItemResponse>, ProblemHttpResult>> DecideModerationItemAsync(

        Guid eventId,

        [FromBody] AdminModerationDecisionRequest? request,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.DecideAdminModerationItemAsync(

            new AdminModerationDecisionCommand(eventId, request?.Action ?? string.Empty, request?.Reason ?? string.Empty),

            cancellationToken);


        if (result.IsFailure)

        {

            var statusCode = string.Equals(result.Error.Code, "templates.not_found", StringComparison.Ordinal)

                ? StatusCodes.Status404NotFound

                : StatusCodes.Status400BadRequest;

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: statusCode);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminTemplateGenerationListPageResponse>, ProblemHttpResult>> ListGenerationsAsync(

        [FromQuery] string? status,

        [FromQuery] string? provider,

        [FromQuery] string? user,

        [FromQuery] string? search,

        [FromQuery] int? skip,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var filterProblem = ValidateGenerationFilters(status);

        if (filterProblem is not null)

        {

            return filterProblem;

        }


        var result = await service.ListAdminGenerationsAsync(

            new AdminTemplateGenerationsQuery(status, provider, user, search, skip, take),

            cancellationToken);


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Ok<AdminWatermarkSettingsResponse>> GetWatermarkSettingsAsync(

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminWatermarkSettingsAsync(cancellationToken);

        return TypedResults.Ok(result.Value);

    }


    private static async Task<Ok<AdminWatermarkSettingsResponse>> UpdateWatermarkSettingsAsync(

        [FromBody] WatermarkSettingsRequest request,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.UpdateAdminWatermarkSettingsAsync(

            new UpdateAdminWatermarkSettingsCommand(

                request.Enabled,

                request.Text,

                request.LogoUrl,

                request.Opacity,

                request.Position,

                request.Size,

                request.CostCredits,

                request.ApplyToImages,

                request.ApplyToVideos),

            cancellationToken);


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<RemoveGenerationWatermarkResponse>, ProblemHttpResult>> GrantCleanDownloadAsync(

        HttpContext context,

        Guid generationId,

        [FromServices] ITemplateGenerationService generationService,

        CancellationToken cancellationToken)

    {

        var result = await generationService.GrantAdminCleanDownloadAsync(

            ResolveAdminUserId(context) ?? Guid.Empty,

            generationId,

            cancellationToken);


        if (result.IsFailure)

        {

            return TypedResults.Problem(

                title: result.Error.Code,

                detail: result.Error.Message,

                statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminTemplateResponse>, ProblemHttpResult>> GetAsync(

        Guid templateId,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminAsync(templateId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminTemplateStatisticsResponse>, ProblemHttpResult>> GetStatisticsAsync(

        Guid templateId,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminStatisticsAsync(templateId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateTrendPointResponse>>, ProblemHttpResult>> GetTrendAsync(

        Guid templateId,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminTrendAsync(templateId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateRecentGenerationResponse>>, ProblemHttpResult>> GetRecentAsync(

        Guid templateId,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var size = take.HasValue ? Math.Clamp(take.Value, 1, RecentGenerationsMaxTake) : RecentGenerationsDefaultTake;

        var result = await service.GetAdminRecentGenerationsAsync(templateId, size, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<IReadOnlyList<TemplateGenerationResponse>>, ProblemHttpResult>> GetTestHistoryAsync(

        Guid templateId,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var size = take.HasValue ? Math.Clamp(take.Value, 1, 50) : 12;

        var result = await service.GetAdminTestHistoryAsync(templateId, size, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateFailureBreakdownItemResponse>>, ProblemHttpResult>> GetFailureBreakdownAsync(

        Guid templateId,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminFailureBreakdownAsync(templateId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<AdminTemplateEventAnalyticsResponse>, ProblemHttpResult>> GetEventAnalyticsAsync(

        Guid templateId,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminEventAnalyticsAsync(templateId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Ok<IReadOnlyList<AdminTemplateFeedbackItemResponse>>, ProblemHttpResult>> GetFeedbackAsync(

        Guid templateId,

        [FromQuery] string? type,

        [FromQuery] string? search,

        [FromQuery] int? take,

        [FromServices] ITemplatesService service,

        CancellationToken cancellationToken)

    {

        var result = await service.GetAdminFeedbackAsync(

            templateId,

            new AdminTemplateFeedbackQuery(type, search, take),

            cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }


    private static async Task<Results<Accepted<TemplateGenerationResponse>, ProblemHttpResult, ValidationProblem>> StartAdminTestAsync(

        Guid templateId,

        [FromForm] IFormFile? sourceImage,

        [FromServices] IMediaStorage mediaStorage,

        [FromServices] ITemplateMediaUploadPolicy uploadPolicy,

        [FromServices] ITemplateGenerationService generationService,

        CancellationToken cancellationToken)

    {

        var uploadValidation = await ValidateSourceImageAsync(

            sourceImage,

            uploadPolicy.GetMaxFileSizeBytes(TemplateAssetKind.Preview),

            cancellationToken);

        if (uploadValidation.Count > 0)

        {

            return TypedResults.ValidationProblem(uploadValidation);

        }


        var detectedContentType = (await TemplateUploadSniffer.DetectContentTypeAsync(sourceImage!, cancellationToken))!;

        await using var stream = sourceImage!.OpenReadStream();

        var storeResult = await mediaStorage.StoreAsync(

            new MediaUploadCommand(

                Path.GetFileName(sourceImage.FileName),

                detectedContentType,

                stream,

                sourceImage.Length),

            cancellationToken);


        if (storeResult.IsFailure)

        {

            return TypedResults.Problem(title: storeResult.Error.Code, detail: storeResult.Error.Message, statusCode: StatusCodes.Status400BadRequest);

        }


        var stored = storeResult.Value;

        var result = await generationService.StartAdminTestAsync(

            templateId,

            new TemplateAssetCommand(stored.Url, stored.FileName, stored.ContentType, stored.FileSizeBytes, null),

            cancellationToken);


        if (result.IsFailure)

        {

            await mediaStorage.DeleteAsync(stored.Url, CancellationToken.None);

            return TypedResults.Problem(

                title: result.Error.Code,

                detail: result.Error.Message,

                statusCode: ResolveGenerationFailureStatusCode(result.Error));

        }


        return TypedResults.Accepted($"/api/admin/templates/tests/{result.Value.GenerationId}", result.Value);

    }


    private static async Task<Results<Ok<TemplateGenerationResponse>, ProblemHttpResult>> GetAdminTestAsync(

        Guid generationId,

        [FromServices] ITemplateGenerationService generationService,

        CancellationToken cancellationToken)

    {

        var result = await generationService.GetAdminAsync(generationId, cancellationToken);

        if (result.IsFailure)

        {

            return TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: StatusCodes.Status404NotFound);

        }


        return TypedResults.Ok(result.Value);

    }

    public sealed record WatermarkSettingsRequest(
        bool Enabled,
        string Text,
        string? LogoUrl,
        double Opacity,
        string Position,
        string Size,
        int CostCredits,
        bool ApplyToImages,
        bool ApplyToVideos);
}
