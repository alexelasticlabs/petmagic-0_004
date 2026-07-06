using System.Text.Json;

using Microsoft.AspNetCore.Http;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private const int MaxGenerationRealtimeEventTopicLength = 128;
    private const int MaxGenerationRealtimeEventDataLength = 8192;
    private static readonly JsonSerializerOptions GenerationRealtimeJsonOptions = new(JsonSerializerDefaults.Web);

    private static async Task StreamGenerationEventsAsync(
        HttpContext httpContext,
        ITemplateFeedRealtimeService realtimeService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(httpContext);
        if (subjectError is not null)
        {
            httpContext.Response.StatusCode = StatusCodes.Status401Unauthorized;
            return;
        }

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
                    if (!TryCreateUserGenerationRealtimeEvent(realtimeEvent, userId!.Value, out var userEvent))
                    {
                        continue;
                    }

                    await WriteGenerationRealtimeEventAsync(httpContext, userEvent, cancellationToken);
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

    private static bool TryCreateUserGenerationRealtimeEvent(
        TemplateFeedRealtimeEvent realtimeEvent,
        Guid userId,
        out TemplateFeedRealtimeEvent userEvent)
    {
        userEvent = default!;
        if (!string.Equals(realtimeEvent.Topic, TemplateFeedRealtimeTopics.GenerationStatusChanged, StringComparison.Ordinal))
        {
            return false;
        }

        if (!IsSafeGenerationRealtimeData(realtimeEvent.Data))
        {
            return false;
        }

        GenerationRealtimeSourcePayload? sourcePayload;
        try
        {
            sourcePayload = JsonSerializer.Deserialize<GenerationRealtimeSourcePayload>(
                realtimeEvent.Data,
                GenerationRealtimeJsonOptions);
        }
        catch (JsonException)
        {
            return false;
        }

        if (sourcePayload is null
            || sourcePayload.UserId != userId
            || sourcePayload.GenerationId == Guid.Empty
            || string.IsNullOrWhiteSpace(sourcePayload.Status))
        {
            return false;
        }

        var payload = new GenerationRealtimeUpdatePayload(
            "generation.status_changed",
            sourcePayload.GenerationId,
            sourcePayload.Status,
            sourcePayload.UpdatedAtUtc,
            RequiresRefetch: true);

        userEvent = new TemplateFeedRealtimeEvent(
            TemplateFeedRealtimeTopics.GenerationStatusChanged,
            JsonSerializer.Serialize(payload, GenerationRealtimeJsonOptions));
        return true;
    }

    private static async Task WriteGenerationRealtimeEventAsync(
        HttpContext httpContext,
        TemplateFeedRealtimeEvent realtimeEvent,
        CancellationToken cancellationToken)
    {
        if (!IsSafeGenerationRealtimeTopic(realtimeEvent.Topic) || !IsSafeGenerationRealtimeData(realtimeEvent.Data))
        {
            return;
        }

        await httpContext.Response.WriteAsync($"event: {realtimeEvent.Topic}\n", cancellationToken);
        await WriteGenerationRealtimeDataAsync(httpContext, realtimeEvent.Data, cancellationToken);
        await httpContext.Response.WriteAsync("\n", cancellationToken);
        await httpContext.Response.Body.FlushAsync(cancellationToken);
    }

    private static bool IsSafeGenerationRealtimeTopic(string topic)
    {
        return !string.IsNullOrWhiteSpace(topic)
            && topic.Length <= MaxGenerationRealtimeEventTopicLength
            && !topic.Contains('\n')
            && !topic.Contains('\r');
    }

    private static bool IsSafeGenerationRealtimeData(string data)
    {
        return data.Length <= MaxGenerationRealtimeEventDataLength;
    }

    private static async Task WriteGenerationRealtimeDataAsync(
        HttpContext httpContext,
        string data,
        CancellationToken cancellationToken)
    {
        using var reader = new StringReader(data);
        string? line;
        while ((line = await reader.ReadLineAsync(cancellationToken)) is not null)
        {
            await httpContext.Response.WriteAsync($"data: {line}\n", cancellationToken);
        }
    }

    private sealed record GenerationRealtimeUpdatePayload(
        string EventType,
        Guid GenerationId,
        string Status,
        DateTime OccurredAtUtc,
        bool RequiresRefetch);

    private sealed record GenerationRealtimeSourcePayload(
        Guid UserId,
        Guid GenerationId,
        string Status,
        DateTime UpdatedAtUtc);
}
