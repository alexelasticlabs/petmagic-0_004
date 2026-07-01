using System.Text.Json;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Api;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private static readonly JsonSerializerOptions FalWebhookJsonOptions = new(JsonSerializerDefaults.Web);

    private static async Task<Results<Ok<FalProviderWebhookResponse>, BadRequest<FalWebhookErrorResponse>, UnauthorizedHttpResult, ProblemHttpResult>> HandleFalWebhookAsync(
        HttpContext context,
        [FromServices] IFalWebhookSignatureVerifier signatureVerifier,
        [FromServices] ITemplateGenerationProviderCallbackService callbackService,
        CancellationToken cancellationToken)
    {
        var body = await ReadRequestBodyAsync(context.Request, cancellationToken);
        if (!await signatureVerifier.VerifyAsync(context.Request.Headers, body, cancellationToken))
        {
            return TypedResults.Unauthorized();
        }

        FalWebhookRequest? request;
        try
        {
            request = JsonSerializer.Deserialize<FalWebhookRequest>(body, FalWebhookJsonOptions);
        }
        catch (JsonException)
        {
            return TypedResults.BadRequest(new FalWebhookErrorResponse("invalid_json"));
        }

        if (request is null
            || string.IsNullOrWhiteSpace(request.RequestId)
            || string.IsNullOrWhiteSpace(request.Status))
        {
            return TypedResults.BadRequest(new FalWebhookErrorResponse("invalid_payload"));
        }

        var headerRequestId = context.Request.Headers["X-Fal-Webhook-Request-Id"].FirstOrDefault();
        if (!string.Equals(headerRequestId, request.RequestId, StringComparison.Ordinal))
        {
            return TypedResults.BadRequest(new FalWebhookErrorResponse("request_id_mismatch"));
        }

        using var emptyPayload = request.Payload.ValueKind == JsonValueKind.Undefined
            ? JsonDocument.Parse("{}")
            : null;
        var payload = emptyPayload is null
            ? request.Payload.Clone()
            : emptyPayload.RootElement.Clone();
        var result = await callbackService.ProcessFalWebhookAsync(
            new FalProviderWebhookCommand(
                request.RequestId.Trim(),
                request.Status.Trim(),
                payload,
                request.Error,
                DateTime.UtcNow),
            cancellationToken);
        if (result.IsFailure)
        {
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<byte[]> ReadRequestBodyAsync(HttpRequest request, CancellationToken cancellationToken)
    {
        request.EnableBuffering();
        using var memory = new MemoryStream();
        await request.Body.CopyToAsync(memory, cancellationToken);
        request.Body.Position = 0;
        return memory.ToArray();
    }

    private sealed record FalWebhookRequest(
        string? RequestId,
        string? Status,
        JsonElement Payload,
        string? Error);

    private sealed record FalWebhookErrorResponse(string Code);
}
