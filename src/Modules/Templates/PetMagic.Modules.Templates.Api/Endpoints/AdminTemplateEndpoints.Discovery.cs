using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Routing;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private static void MapDiscoveryEndpoints(RouteGroupBuilder group)
    {
        var discovery = group.MapGroup("/discovery");
        discovery.AddEndpointFilter(async (context, next) =>
        {
            var result = await next(context);
            context.HttpContext.Response.Headers.CacheControl = "private, no-store";
            return result;
        });
        discovery.MapGet("/", async ([FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
            TypedResults.Ok(await service.GetAsync(ct)));
        discovery.MapGet("/revisions", async (int? skip, int? take, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
            TypedResults.Ok(await service.HistoryAsync(skip ?? 0, take ?? 20, ct)));
        discovery.MapGet("/drafts/{revisionId:guid}/preview", async (Guid revisionId, string? locale, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
            DiscoveryResult(await service.PreviewAsync(revisionId, locale, ct)));
        discovery.MapPost("/drafts/{revisionId:guid}/validate", async (Guid revisionId, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
            DiscoveryResult(await service.ValidateAsync(revisionId, ct)));
        discovery.MapPost("/drafts", async (HttpContext context, CreateDiscoveryDraftRequest request, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
        {
            var (actorId, error) = TryGetAdminUserId(context);
            return error is null ? DiscoveryResult(await service.CreateDraftAsync(actorId, request, ct)) : ToAdminTemplateProblem(error);
        }).RequireAuthorization("AdminOnly").WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        discovery.MapPut("/drafts/{revisionId:guid}", async (HttpContext context, Guid revisionId, SaveDiscoveryDraftRequest request, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
        {
            var (actorId, error) = TryGetAdminUserId(context);
            return error is null ? DiscoveryResult(await service.SaveDraftAsync(actorId, revisionId, request, ct)) : ToAdminTemplateProblem(error);
        }).RequireAuthorization("AdminOnly").WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateDefinitionRequestBodyBytes));
        discovery.MapPost("/drafts/{revisionId:guid}/publish", async (HttpContext context, Guid revisionId, PublishDiscoveryRequest request, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
        {
            var (actorId, error) = TryGetAdminUserId(context);
            return error is null ? DiscoveryResult(await service.PublishAsync(actorId, revisionId,
                context.Request.Headers["Idempotency-Key"].FirstOrDefault() ?? "", request, ct)) : ToAdminTemplateProblem(error);
        }).RequireAuthorization("AdminOnly").WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
        discovery.MapPost("/drafts/{revisionId:guid}/discard", async (HttpContext context, Guid revisionId, DiscardDiscoveryDraftRequest request, [FromServices] ITemplateDiscoveryAdminService service, CancellationToken ct) =>
        {
            var (actorId, error) = TryGetAdminUserId(context);
            return error is null ? DiscoveryResult(await service.DiscardAsync(actorId, revisionId, request, ct)) : ToAdminTemplateProblem(error);
        }).RequireAuthorization("AdminOnly").WithMetadata(new RequestSizeLimitAttribute(MaxAdminTemplateSmallJsonRequestBodyBytes));
    }

    private static IResult DiscoveryResult<T>(Result<T> result)
    {
        if (result.IsSuccess) return TypedResults.Ok(result.Value);
        var status = result.Error.Code switch
        {
            "discovery.conflict" => StatusCodes.Status409Conflict,
            "discovery.not_found" => StatusCodes.Status404NotFound,
            _ => StatusCodes.Status400BadRequest
        };
        var extensions = result.Error.Metadata?.ToDictionary(pair => pair.Key, pair => pair.Value) ?? [];
        extensions["code"] = result.Error.Code;
        return TypedResults.Problem(statusCode: status, title: result.Error.Code, detail: result.Error.Message, extensions: extensions);
    }
}
