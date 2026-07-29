using System.Text.Json;
using System.Text.Json.Serialization;

using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Templates.Api;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private const int FalWebhookBodyMaxBytes = 48 * 1024;
    private static readonly JsonSerializerOptions FalWebhookJsonOptions = new(JsonSerializerDefaults.Web);

    private static async Task<Results<Ok<FalProviderWebhookResponse>, BadRequest<FalWebhookErrorResponse>, UnauthorizedHttpResult, ProblemHttpResult>> HandleFalWebhookAsync(
        HttpContext context,
        [FromServices] IFalWebhookSignatureVerifier signatureVerifier,
        [FromServices] ITemplateGenerationProviderCallbackService callbackService,
        CancellationToken cancellationToken)
    {
        var body = await ReadRequestBodyAsync(context.Request, cancellationToken);
        if (body is null)
        {
            TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure("payload_too_large");
            return TypedResults.BadRequest(new FalWebhookErrorResponse("payload_too_large"));
        }

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
            TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure("invalid_json");
            return TypedResults.BadRequest(new FalWebhookErrorResponse("invalid_json"));
        }

        if (request is null
            || string.IsNullOrWhiteSpace(request.RequestId)
            || string.IsNullOrWhiteSpace(request.Status))
        {
            TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure("invalid_payload");
            return TypedResults.BadRequest(new FalWebhookErrorResponse("invalid_payload"));
        }

        var headerRequestId = context.Request.Headers["X-Fal-Webhook-Request-Id"].FirstOrDefault();
        if (!string.Equals(headerRequestId, request.RequestId, StringComparison.Ordinal))
        {
            TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure("request_id_mismatch");
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
                DateTime.UtcNow,
                context.Request.Query["attempt_token"].FirstOrDefault()),
            cancellationToken);
        if (result.IsFailure)
        {
            TemplateGenerationApiMetrics.RecordWebhookDeliveryFailure(result.Error.Code);
            return ToClientGenerationProblem(result.Error);
        }

        return TypedResults.Ok(result.Value);
    }

    private static async Task<byte[]?> ReadRequestBodyAsync(HttpRequest request, CancellationToken cancellationToken)
    {
        if (request.ContentLength > FalWebhookBodyMaxBytes)
        {
            return null;
        }

        request.EnableBuffering();
        using var memory = new MemoryStream();
        var buffer = new byte[8 * 1024];
        while (true)
        {
            var read = await request.Body.ReadAsync(buffer, cancellationToken);
            if (read == 0)
            {
                break;
            }

            if (memory.Length + read > FalWebhookBodyMaxBytes)
            {
                request.Body.Position = 0;
                return null;
            }

            await memory.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
        }

        request.Body.Position = 0;
        return memory.ToArray();
    }

    private sealed record FalWebhookRequest(
        [property: JsonPropertyName("request_id")] string? RequestId,
        [property: JsonPropertyName("status")] string? Status,
        [property: JsonPropertyName("payload")] JsonElement Payload,
        [property: JsonPropertyName("error")] string? Error);

    private sealed record FalWebhookErrorResponse(string Code);
}
